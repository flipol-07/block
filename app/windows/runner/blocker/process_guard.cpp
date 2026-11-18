#include "blocker/process_guard.h"

#include <windows.h>
#include <tlhelp32.h>

#include <algorithm>
#include <chrono>
#include <cwctype>

namespace {

// Procesos que nunca se cierran aunque alguien los ponga en la lista: matarlos
// dejaria Windows inservible o cerraria el propio Block.
const std::set<std::wstring> kProtected = {
    L"system",       L"smss.exe",     L"csrss.exe",    L"wininit.exe",
    L"winlogon.exe", L"services.exe", L"lsass.exe",    L"svchost.exe",
    L"dwm.exe",      L"explorer.exe", L"block.exe",    L"taskmgr.exe",
};

std::wstring Lower(std::wstring value) {
  std::transform(value.begin(), value.end(), value.begin(),
                 [](wchar_t c) { return static_cast<wchar_t>(std::towlower(c)); });
  return value;
}

}  // namespace

ProcessGuard::~ProcessGuard() { Stop(); }

void ProcessGuard::Start(std::set<std::wstring> executables) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    executables_.clear();
    for (const auto& exe : executables) {
      auto name = Lower(exe);
      if (kProtected.count(name) == 0) executables_.insert(name);
    }
  }
  if (running_.exchange(true)) {
    wake_.notify_all();
    return;
  }
  thread_ = std::thread(&ProcessGuard::Loop, this);
}

void ProcessGuard::Stop() {
  if (!running_.exchange(false)) return;
  wake_.notify_all();
  if (thread_.joinable()) thread_.join();
}

void ProcessGuard::Loop() {
  std::unique_lock<std::mutex> lock(mutex_);
  while (running_) {
    lock.unlock();
    KillListed();
    lock.lock();
    wake_.wait_for(lock, std::chrono::milliseconds(500), [this] { return !running_; });
  }
}

void ProcessGuard::KillListed() {
  std::set<std::wstring> targets;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    targets = executables_;
  }
  if (targets.empty()) return;

  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) return;
  const DWORD self = GetCurrentProcessId();
  PROCESSENTRY32W entry{};
  entry.dwSize = sizeof(entry);
  for (BOOL ok = Process32FirstW(snapshot, &entry); ok; ok = Process32NextW(snapshot, &entry)) {
    if (entry.th32ProcessID == self || targets.count(Lower(entry.szExeFile)) == 0) continue;
    HANDLE process = OpenProcess(PROCESS_TERMINATE, FALSE, entry.th32ProcessID);
    if (process) {
      TerminateProcess(process, 1);
      CloseHandle(process);
    }
  }
  CloseHandle(snapshot);
}
