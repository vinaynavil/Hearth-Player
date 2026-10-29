#include "flutter_window.h"

#include <optional>

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
  single_instance_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "hearth/single_instance",
          &flutter::StandardMethodCodec::GetInstance());






  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });


  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (single_instance_channel_) {
    single_instance_channel_ = nullptr;
  }

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
    case WM_COPYDATA: {
      auto* cds = reinterpret_cast<COPYDATASTRUCT*>(lparam);
      if (cds && cds->dwData == 0x48525448 && cds->lpData && cds->cbData > 1 &&
          single_instance_channel_) {
        std::string file_path(static_cast<const char*>(cds->lpData),
                              cds->cbData - 1);
        single_instance_channel_->InvokeMethod(
            "openFile",
            std::make_unique<flutter::EncodableValue>(file_path));
        return TRUE;
      }
      break;
    }
    case WM_APPCOMMAND: {
      if (single_instance_channel_) {
        const int cmd = GET_APPCOMMAND_LPARAM(lparam);
        const char* action = nullptr;
        switch (cmd) {
          case APPCOMMAND_MEDIA_PLAY_PAUSE:
            action = "play_pause";
            break;
          case APPCOMMAND_MEDIA_PLAY:
            action = "play";
            break;
          case APPCOMMAND_MEDIA_PAUSE:
            action = "pause";
            break;
          case APPCOMMAND_MEDIA_STOP:
            action = "stop";
            break;
          case APPCOMMAND_MEDIA_NEXTTRACK:
            action = "next";
            break;
          case APPCOMMAND_MEDIA_PREVIOUSTRACK:
            action = "previous";
            break;
        }
        if (action != nullptr) {
          single_instance_channel_->InvokeMethod(
              "mediaCommand",
              std::make_unique<flutter::EncodableValue>(std::string(action)));
          return TRUE;
        }
      }
      break;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
