#ifndef RUNNER_BLOCKER_PROCESS_GUARD_H_
#define RUNNER_BLOCKER_PROCESS_GUARD_H_

#include <atomic>
#include <condition_variable>
#include <mutex>
#include <set>
#include <string>
#include <thread>

// Cierra cada ~500 ms los procesos de la lista de bloqueo mientras dura una
// sesion. Corre en su propio hilo para no tocar el hilo de la interfaz.
class ProcessGuard {
 public:
  ProcessGuard() = default;
  ~ProcessGuard();

  // Empieza (o actualiza la lista si ya estaba en marcha). Los nombres se
  // comparan en minusculas, p. ej. "whatsapp.exe".
  void Start(std::set<std::wstring> executables);
  void Stop();

 private:
  void Loop();
  void KillListed();

  std::thread thread_;
  std::atomic<bool> running_{false};
  std::mutex mutex_;
  std::condition_variable wake_;
  std::set<std::wstring> executables_;
};

#endif  // RUNNER_BLOCKER_PROCESS_GUARD_H_
