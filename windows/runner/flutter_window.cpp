#include "flutter_window.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <cstdlib>
#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // 启动期主题（T0_START_THEME=dark|light）先同步一次原生标题栏，
  // 之后由 Dart 侧的 t0/theme channel 跟着用户切换走。
  // /WX：getenv 会报 C4996，这里用 _dupenv_s
  std::string start_theme;
  {
    char* buffer = nullptr;
    size_t size = 0;
    if (_dupenv_s(&buffer, &size, "T0_START_THEME") == 0 && buffer != nullptr) {
      start_theme.assign(buffer);
      free(buffer);
    }
  }
  const bool start_dark = start_theme == "dark";
  ApplyDarkTitleBar(start_dark);

  theme_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "t0/theme",
      &flutter::StandardMethodCodec::GetInstance());
  theme_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "setDark") {
          const bool* dark = std::get_if<bool>(call.arguments());
          ApplyDarkTitleBar(dark != nullptr && *dark);
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::ApplyDarkTitleBar(bool dark) {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }
  // 20 = DWMWA_USE_IMMERSIVE_DARK_MODE：让系统按深色画标题栏 / 边框
  BOOL use_dark = dark ? TRUE : FALSE;
  DwmSetWindowAttribute(hwnd, 20, &use_dark, sizeof(use_dark));
  // 35 = DWMWA_CAPTION_COLOR, 36 = DWMWA_TEXT_COLOR（Win11 22H2+，老系统失败就算了）
  if (dark) {
    const COLORREF caption = RGB(0x2E, 0x25, 0x36);  // T0Palette.dark.bg
    const COLORREF text = RGB(0xF3, 0xEE, 0xF7);     // T0Palette.dark.ink
    DwmSetWindowAttribute(hwnd, 35, &caption, sizeof(caption));
    DwmSetWindowAttribute(hwnd, 36, &text, sizeof(text));
  } else {
    const COLORREF default_color = 0xFFFFFFFF;  // DWMWA_COLOR_DEFAULT
    DwmSetWindowAttribute(hwnd, 35, &default_color, sizeof(default_color));
    DwmSetWindowAttribute(hwnd, 36, &default_color, sizeof(default_color));
  }
  // 让非客户区重画
  SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
               SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER);
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
