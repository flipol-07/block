#ifndef RUNNER_BLOCKER_BLOCKER_PLUGIN_H_
#define RUNNER_BLOCKER_BLOCKER_PLUGIN_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>

#include "blocker/focus_overlay.h"
#include "blocker/process_guard.h"

// Canal "block/blocker" en Windows: Dart dice que bloquear y este codigo lo
// hace cumplir (procesos, ventana unica, arranque con Windows).
class BlockerPlugin {
 public:
  BlockerPlugin(flutter::BinaryMessenger* messenger, HWND app_window);
  ~BlockerPlugin();

 private:
  using Value = flutter::EncodableValue;
  using Result = std::unique_ptr<flutter::MethodResult<Value>>;

  void Handle(const flutter::MethodCall<Value>& call, Result result);
  void ApplySession(const flutter::EncodableMap& args);
  void ClearSession();
  Value ListWindows() const;
  void SetAutostart(bool enabled) const;

  HWND app_window_;
  ProcessGuard guard_;
  FocusOverlay overlay_;
  std::unique_ptr<flutter::MethodChannel<Value>> channel_;
};

#endif  // RUNNER_BLOCKER_BLOCKER_PLUGIN_H_
