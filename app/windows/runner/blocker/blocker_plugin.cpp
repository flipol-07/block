#include "blocker/blocker_plugin.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>

#include <set>
#include <string>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

std::string ToUtf8(const std::wstring& wide) {
  if (wide.empty()) return {};
  int size = WideCharToMultiByte(CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()), nullptr,
                                 0, nullptr, nullptr);
  std::string out(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()), out.data(), size,
                      nullptr, nullptr);
  return out;
}

std::wstring ToWide(const std::string& utf8) {
  if (utf8.empty()) return {};
  int size = MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring out(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), out.data(), size);
  return out;
}

const EncodableValue* Find(const EncodableMap& map, const char* key) {
  auto it = map.find(EncodableValue(key));
  return it == map.end() ? nullptr : &it->second;
}

int64_t AsInt(const EncodableValue* value) {
  if (!value) return 0;
  if (auto v = std::get_if<int32_t>(value)) return *v;
  if (auto v = std::get_if<int64_t>(value)) return *v;
  return 0;
}

bool AsBool(const EncodableValue* value) {
  auto v = value ? std::get_if<bool>(value) : nullptr;
  return v && *v;
}

std::wstring ExeName(DWORD pid) {
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!process) return L"";
  wchar_t path[MAX_PATH];
  DWORD size = MAX_PATH;
  std::wstring name;
  if (QueryFullProcessImageNameW(process, 0, path, &size)) {
    name.assign(path, size);
    auto slash = name.find_last_of(L"\\/");
    if (slash != std::wstring::npos) name = name.substr(slash + 1);
  }
  CloseHandle(process);
  return name;
}

}  // namespace

BlockerPlugin::BlockerPlugin(flutter::BinaryMessenger* messenger, HWND app_window)
    : app_window_(app_window), overlay_(app_window) {
  channel_ = std::make_unique<flutter::MethodChannel<Value>>(
      messenger, "block/blocker", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) { Handle(call, std::move(result)); });
}

BlockerPlugin::~BlockerPlugin() {
  channel_->SetMethodCallHandler(nullptr);
  ClearSession();
}

void BlockerPlugin::Handle(const flutter::MethodCall<Value>& call, Result result) {
  const auto& method = call.method_name();
  if (method == "applySession") {
    const auto* args = std::get_if<EncodableMap>(call.arguments());
    if (!args) return result->Error("args", "applySession needs a map");
    ApplySession(*args);
    result->Success();
  } else if (method == "clearSession") {
    ClearSession();
    result->Success();
  } else if (method == "listWindows") {
    result->Success(ListWindows());
  } else if (method == "setAutostart") {
    SetAutostart(AsBool(call.arguments()));
    result->Success();
  } else {
    result->NotImplemented();
  }
}

void BlockerPlugin::ApplySession(const EncodableMap& args) {
  std::set<std::wstring> executables;
  if (const auto* list = std::get_if<EncodableList>(Find(args, "blockedApps"))) {
    for (const auto& item : *list) {
      if (const auto* s = std::get_if<std::string>(&item)) executables.insert(ToWide(*s));
    }
  }
  guard_.Start(std::move(executables));

  if (AsBool(Find(args, "singleWindow"))) {
    overlay_.Start(reinterpret_cast<HWND>(AsInt(Find(args, "allowedWindow"))));
  } else {
    overlay_.Stop();
  }
}

void BlockerPlugin::ClearSession() {
  guard_.Stop();
  overlay_.Stop();
}

EncodableValue BlockerPlugin::ListWindows() const {
  struct Context {
    HWND app;
    EncodableList windows;
  } ctx{app_window_, {}};
  EnumWindows(
      [](HWND hwnd, LPARAM lparam) -> BOOL {
        auto* c = reinterpret_cast<Context*>(lparam);
        DWORD cloaked = 0;
        DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, &cloaked, sizeof(cloaked));
        const bool tool = (GetWindowLongW(hwnd, GWL_EXSTYLE) & WS_EX_TOOLWINDOW) != 0;
        if (hwnd == c->app || !IsWindowVisible(hwnd) || cloaked || tool ||
            GetWindow(hwnd, GW_OWNER) != nullptr || GetWindowTextLengthW(hwnd) == 0) {
          return TRUE;
        }
        DWORD pid = 0;
        GetWindowThreadProcessId(hwnd, &pid);
        if (pid == GetCurrentProcessId()) return TRUE;
        wchar_t title[256];
        GetWindowTextW(hwnd, title, 256);
        c->windows.push_back(EncodableValue(EncodableMap{
            {EncodableValue("handle"), EncodableValue(reinterpret_cast<int64_t>(hwnd))},
            {EncodableValue("title"), EncodableValue(ToUtf8(title))},
            {EncodableValue("exe"), EncodableValue(ToUtf8(ExeName(pid)))},
        }));
        return TRUE;
      },
      reinterpret_cast<LPARAM>(&ctx));
  return EncodableValue(ctx.windows);
}

// Arranca con Windows (oculto en la bandeja) para que una sesion iniciada
// desde el movil tambien bloquee el PC.
void BlockerPlugin::SetAutostart(bool enabled) const {
  HKEY key;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\CurrentVersion\\Run", 0,
                    KEY_SET_VALUE, &key) != ERROR_SUCCESS) {
    return;
  }
  if (enabled) {
    wchar_t path[MAX_PATH];
    GetModuleFileNameW(nullptr, path, MAX_PATH);
    std::wstring command = L"\"" + std::wstring(path) + L"\" --minimized";
    RegSetValueExW(key, L"Block", 0, REG_SZ, reinterpret_cast<const BYTE*>(command.c_str()),
                   static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  } else {
    RegDeleteValueW(key, L"Block");
  }
  RegCloseKey(key);
}
