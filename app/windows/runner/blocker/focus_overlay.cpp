#include "blocker/focus_overlay.h"

#include <dwmapi.h>

#include <cwchar>

namespace {

constexpr wchar_t kClassName[] = L"BlockFocusOverlay";
constexpr UINT_PTR kTimerId = 1;
constexpr UINT kTickMs = 150;
constexpr int kBannerWidth = 640;
constexpr int kBannerHeight = 56;
constexpr COLORREF kBackground = RGB(0x0E, 0x0F, 0x12);
constexpr COLORREF kText = RGB(0x8B, 0x8F, 0x98);
constexpr COLORREF kAccent = RGB(0xE9, 0xC4, 0x6A);

// Ventanas del propio Windows que no tienen sentido como "ventana de estudio".
const wchar_t* const kShellClasses[] = {
    L"Shell_TrayWnd",          L"Shell_SecondaryTrayWnd", L"Progman",
    L"WorkerW",                L"Windows.UI.Core.CoreWindow",
    L"NotifyIconOverflowWindow", L"XamlExplorerHostIslandWindow",
    L"TopLevelWindowForOverflowXamlIsland",
};

DWORD WindowPid(HWND hwnd) {
  DWORD pid = 0;
  GetWindowThreadProcessId(hwnd, &pid);
  return pid;
}

bool IsCloaked(HWND hwnd) {
  DWORD cloaked = 0;
  DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, &cloaked, sizeof(cloaked));
  return cloaked != 0;
}

bool IsShellWindow(HWND hwnd) {
  wchar_t cls[128];
  if (!GetClassNameW(hwnd, cls, 128)) return false;
  for (const auto* shell : kShellClasses) {
    if (wcscmp(cls, shell) == 0) return true;
  }
  return false;
}

RECT FrameBounds(HWND hwnd) {
  RECT rect{};
  if (FAILED(DwmGetWindowAttribute(hwnd, DWMWA_EXTENDED_FRAME_BOUNDS, &rect, sizeof(rect)))) {
    GetWindowRect(hwnd, &rect);
  }
  return rect;
}

bool SameRects(const std::vector<RECT>& a, const std::vector<RECT>& b) {
  if (a.size() != b.size()) return false;
  for (size_t i = 0; i < a.size(); ++i) {
    if (!EqualRect(&a[i], &b[i])) return false;
  }
  return true;
}

// Windows solo deja cambiar el foco a quien recibio la ultima entrada; una
// pulsacion sintetica de Alt nos da ese derecho.
void BringToFront(HWND hwnd) {
  if (IsIconic(hwnd)) ShowWindow(hwnd, SW_RESTORE);
  keybd_event(VK_MENU, 0, 0, 0);
  SetForegroundWindow(hwnd);
  keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
}

}  // namespace

FocusOverlay* FocusOverlay::instance_ = nullptr;

FocusOverlay::FocusOverlay(HWND app_window) : app_window_(app_window) {
  WNDCLASSW wc{};
  wc.lpfnWndProc = WndProc;
  wc.hInstance = GetModuleHandle(nullptr);
  wc.lpszClassName = kClassName;
  wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
  RegisterClassW(&wc);
}

FocusOverlay::~FocusOverlay() { Stop(); }

bool FocusOverlay::IsCandidate(HWND hwnd) const {
  return hwnd && hwnd != overlay_ && IsWindowVisible(hwnd) && !IsCloaked(hwnd) &&
         GetAncestor(hwnd, GA_ROOTOWNER) != app_window_ &&
         WindowPid(hwnd) != GetCurrentProcessId() && !IsShellWindow(hwnd);
}

void FocusOverlay::Start(HWND allowed) {
  if (overlay_) return;
  instance_ = this;
  bounds_ = {GetSystemMetrics(SM_XVIRTUALSCREEN), GetSystemMetrics(SM_YVIRTUALSCREEN), 0, 0};
  bounds_.right = bounds_.left + GetSystemMetrics(SM_CXVIRTUALSCREEN);
  bounds_.bottom = bounds_.top + GetSystemMetrics(SM_CYVIRTUALSCREEN);

  overlay_ = CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_LAYERED | WS_EX_NOACTIVATE | WS_EX_TRANSPARENT,
      kClassName, L"Block", WS_POPUP, 0, 0, kBannerWidth, kBannerHeight, nullptr, nullptr,
      GetModuleHandle(nullptr), nullptr);
  if (!overlay_) return;
  SetLayeredWindowAttributes(overlay_, 0, 242, LWA_ALPHA);
  SetTimer(overlay_, kTimerId, kTickMs, nullptr);

  if (IsWindow(allowed) && IsCandidate(allowed)) {
    Lock(allowed);
  } else {
    EnterPicking();
  }
}

// Aviso arriba en el centro, que deja pasar los clics, y un hook de raton que
// recoge la primera ventana en la que se hace clic.
void FocusOverlay::EnterPicking() {
  picking_ = true;
  picked_ = nullptr;
  MONITORINFO mi{sizeof(mi)};
  GetMonitorInfo(MonitorFromWindow(app_window_, MONITOR_DEFAULTTOPRIMARY), &mi);
  const int x = (mi.rcWork.left + mi.rcWork.right - kBannerWidth) / 2;
  SetWindowPos(overlay_, HWND_TOPMOST, x, mi.rcWork.top + 16, kBannerWidth, kBannerHeight,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);
  mouse_hook_ = SetWindowsHookExW(WH_MOUSE_LL, MouseProc, GetModuleHandle(nullptr), 0);
}

void FocusOverlay::Lock(HWND allowed) {
  picking_ = false;
  if (mouse_hook_) {
    UnhookWindowsHookEx(mouse_hook_);
    mouse_hook_ = nullptr;
  }
  allowed_ = allowed;
  allowed_pid_ = WindowPid(allowed);
  LONG_PTR ex = GetWindowLongPtrW(overlay_, GWL_EXSTYLE);
  SetWindowLongPtrW(overlay_, GWL_EXSTYLE, ex & ~WS_EX_TRANSPARENT);
  SetWindowPos(overlay_, HWND_TOPMOST, bounds_.left, bounds_.top, bounds_.right - bounds_.left,
               bounds_.bottom - bounds_.top, SWP_NOACTIVATE | SWP_SHOWWINDOW | SWP_FRAMECHANGED);
  last_holes_.clear();
  UpdateRegion();
  InvalidateRect(overlay_, nullptr, TRUE);
  if (!keyboard_hook_) {
    keyboard_hook_ = SetWindowsHookExW(WH_KEYBOARD_LL, KeyboardProc, GetModuleHandle(nullptr), 0);
  }
  BringToFront(allowed_);
}

void FocusOverlay::Stop() {
  if (keyboard_hook_) {
    UnhookWindowsHookEx(keyboard_hook_);
    keyboard_hook_ = nullptr;
  }
  if (mouse_hook_) {
    UnhookWindowsHookEx(mouse_hook_);
    mouse_hook_ = nullptr;
  }
  if (overlay_) {
    KillTimer(overlay_, kTimerId);
    DestroyWindow(overlay_);
    overlay_ = nullptr;
  }
  allowed_ = nullptr;
  allowed_pid_ = 0;
  picking_ = false;
  picked_ = nullptr;
  if (instance_ == this) instance_ = nullptr;
}

void FocusOverlay::Tick() {
  if (picking_) {
    if (picked_ && IsWindow(picked_)) Lock(picked_);
    else SetWindowPos(overlay_, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    return;
  }
  if (allowed_ && !IsWindow(allowed_)) {
    // Se cerro la ventana elegida: se vuelve a pedir que elijas otra.
    allowed_ = nullptr;
    allowed_pid_ = 0;
    LONG_PTR ex = GetWindowLongPtrW(overlay_, GWL_EXSTYLE);
    SetWindowLongPtrW(overlay_, GWL_EXSTYLE, ex | WS_EX_TRANSPARENT);
    SetWindowRgn(overlay_, nullptr, TRUE);
    EnterPicking();
    InvalidateRect(overlay_, nullptr, TRUE);
    return;
  }
  UpdateRegion();
  SetWindowPos(overlay_, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  EnforceForeground();
}

// Agujeros: todas las ventanas visibles de la app permitida (incluidos sus
// dialogos) y la ventana de Block si esta abierta.
std::vector<RECT> FocusOverlay::VisibleHoles() const {
  struct Context {
    const FocusOverlay* self;
    std::vector<RECT> holes;
  } ctx{this, {}};
  EnumWindows(
      [](HWND hwnd, LPARAM lparam) -> BOOL {
        auto* c = reinterpret_cast<Context*>(lparam);
        if (hwnd == c->self->overlay_ || !IsWindowVisible(hwnd) || IsIconic(hwnd) || IsCloaked(hwnd)) {
          return TRUE;
        }
        const bool is_app = hwnd == c->self->app_window_;
        const bool is_allowed = c->self->allowed_pid_ != 0 && WindowPid(hwnd) == c->self->allowed_pid_;
        if (is_app || is_allowed) c->holes.push_back(FrameBounds(hwnd));
        return TRUE;
      },
      reinterpret_cast<LPARAM>(&ctx));
  return ctx.holes;
}

void FocusOverlay::UpdateRegion() {
  auto holes = VisibleHoles();
  if (SameRects(holes, last_holes_)) return;
  last_holes_ = holes;
  HRGN region = CreateRectRgn(0, 0, bounds_.right - bounds_.left, bounds_.bottom - bounds_.top);
  for (const auto& r : holes) {
    HRGN hole = CreateRectRgn(r.left - bounds_.left, r.top - bounds_.top, r.right - bounds_.left,
                              r.bottom - bounds_.top);
    CombineRgn(region, region, hole, RGN_DIFF);
    DeleteObject(hole);
  }
  SetWindowRgn(overlay_, region, TRUE);  // El sistema se queda con la region.
}

bool FocusOverlay::IsAllowed(HWND hwnd) const {
  if (hwnd == overlay_ || GetAncestor(hwnd, GA_ROOTOWNER) == app_window_) return true;
  const DWORD pid = WindowPid(hwnd);
  return pid == GetCurrentProcessId() || (allowed_pid_ != 0 && pid == allowed_pid_);
}

void FocusOverlay::EnforceForeground() {
  HWND foreground = GetForegroundWindow();
  if (!foreground || IsAllowed(foreground)) return;
  BringToFront(allowed_ ? allowed_ : app_window_);
}

void FocusOverlay::Paint(HWND hwnd) {
  PAINTSTRUCT ps;
  HDC dc = BeginPaint(hwnd, &ps);
  RECT client;
  GetClientRect(hwnd, &client);
  HBRUSH brush = CreateSolidBrush(kBackground);
  FillRect(dc, &client, brush);
  DeleteObject(brush);
  SetBkMode(dc, TRANSPARENT);
  if (picking_) {
    SetTextColor(dc, kAccent);
    DrawTextW(dc, L"Block · haz clic en la ventana donde vas a estudiar", -1, &client,
              DT_CENTER | DT_SINGLELINE | DT_VCENTER);
  } else {
    SetTextColor(dc, kText);
    RECT text = {client.left, client.top + 24, client.right, client.top + 64};
    DrawTextW(dc, L"Block · modo una sola ventana · Ctrl+Shift+B abre Block", -1, &text,
              DT_CENTER | DT_SINGLELINE | DT_VCENTER);
  }
  EndPaint(hwnd, &ps);
}

LRESULT CALLBACK FocusOverlay::WndProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  switch (message) {
    case WM_TIMER:
      if (instance_ && wparam == kTimerId) instance_->Tick();
      return 0;
    case WM_PAINT:
      if (instance_) instance_->Paint(hwnd);
      return 0;
    case WM_ERASEBKGND:
      return 1;
    case WM_MOUSEACTIVATE:
      return MA_NOACTIVATE;
  }
  return DefWindowProcW(hwnd, message, wparam, lparam);
}

LRESULT CALLBACK FocusOverlay::MouseProc(int code, WPARAM wparam, LPARAM lparam) {
  if (code == HC_ACTION && instance_ && instance_->picking_ && wparam == WM_LBUTTONDOWN) {
    const auto* ms = reinterpret_cast<const MSLLHOOKSTRUCT*>(lparam);
    HWND root = GetAncestor(WindowFromPoint(ms->pt), GA_ROOT);
    if (instance_->IsCandidate(root)) instance_->picked_ = root;
  }
  return CallNextHookEx(nullptr, code, wparam, lparam);
}

LRESULT CALLBACK FocusOverlay::KeyboardProc(int code, WPARAM wparam, LPARAM lparam) {
  if (code == HC_ACTION && instance_ && !instance_->picking_) {
    const auto* kb = reinterpret_cast<const KBDLLHOOKSTRUCT*>(lparam);
    if ((kb->flags & LLKHF_INJECTED) == 0) {
      const bool alt = (kb->flags & LLKHF_ALTDOWN) != 0;
      const bool ctrl = (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;
      const bool shift = (GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0;
      const bool down = wparam == WM_KEYDOWN || wparam == WM_SYSKEYDOWN;
      switch (kb->vkCode) {
        case VK_LWIN:
        case VK_RWIN:
          return 1;
        case VK_TAB:
          if (alt) return 1;
          break;
        case VK_ESCAPE:
          if (alt || ctrl) return 1;
          break;
        case 'B':
          if (ctrl && shift) {
            if (down) PostMessage(instance_->app_window_, kShowAppMessage, 0, 0);
            return 1;
          }
          break;
      }
    }
  }
  return CallNextHookEx(nullptr, code, wparam, lparam);
}
