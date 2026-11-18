#ifndef RUNNER_BLOCKER_FOCUS_OVERLAY_H_
#define RUNNER_BLOCKER_FOCUS_OVERLAY_H_

#include <windows.h>

#include <vector>

// Modo "una sola ventana": una capa oscura siempre encima que tapa todos los
// monitores menos la ventana elegida (y la de Block). Devuelve el foco a esa
// ventana si se cambia a otra y anula Win, Alt+Tab, Alt+Esc y Ctrl+Esc.
//
// Si no se eligio ventana antes de empezar, arranca en modo "elegir": un
// aviso arriba pide hacer clic en la ventana de estudio y la primera ventana
// en la que se hace clic queda como la permitida.
//
// Ctrl+Alt+Supr no se puede interceptar desde una app de usuario: es una
// limitacion de Windows, no de Block.
class FocusOverlay {
 public:
  // Mensaje que se envia a la ventana de Block al pulsar Ctrl+Shift+B.
  static constexpr UINT kShowAppMessage = WM_APP + 0x42;

  explicit FocusOverlay(HWND app_window);
  ~FocusOverlay();

  void Start(HWND allowed);
  void Stop();
  bool active() const { return overlay_ != nullptr; }

 private:
  static LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
  static LRESULT CALLBACK KeyboardProc(int code, WPARAM wparam, LPARAM lparam);
  static LRESULT CALLBACK MouseProc(int code, WPARAM wparam, LPARAM lparam);

  bool IsCandidate(HWND hwnd) const;
  void EnterPicking();
  void Lock(HWND allowed);
  void Tick();
  void UpdateRegion();
  void EnforceForeground();
  bool IsAllowed(HWND hwnd) const;
  std::vector<RECT> VisibleHoles() const;
  void Paint(HWND hwnd);

  HWND app_window_;
  HWND overlay_ = nullptr;
  HWND allowed_ = nullptr;
  DWORD allowed_pid_ = 0;
  bool picking_ = false;
  HWND picked_ = nullptr;
  HHOOK keyboard_hook_ = nullptr;
  HHOOK mouse_hook_ = nullptr;
  RECT bounds_{};
  std::vector<RECT> last_holes_;

  static FocusOverlay* instance_;
};

#endif  // RUNNER_BLOCKER_FOCUS_OVERLAY_H_
