#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <mmsystem.h>
#include <shellapi.h>
#include <shlobj.h>

#include <fstream>
#include <optional>
#include <sstream>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {

// The smallest window, in logical pixels, matching the macOS window: narrow
// enough to reach the stacked (portrait) layout.
constexpr int kMinWidth = 380;
constexpr int kMinHeight = 520;

std::wstring Widen(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  int length = ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                     static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring wide(length, L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                        wide.data(), length);
  return wide;
}

// The folder holding Flights.exe, which the bundled assets sit beside.
std::wstring ExeDirectory() {
  wchar_t path[MAX_PATH];
  DWORD length = ::GetModuleFileNameW(nullptr, path, MAX_PATH);
  std::wstring full(path, length);
  return full.substr(0, full.find_last_of(L"\\/"));
}

// %APPDATA%\Flights\saves.json, creating the folder if needed. The install
// folder (Program Files) isn't writable, so the save lives in the profile.
std::wstring SavePath() {
  PWSTR app_data = nullptr;
  if (FAILED(::SHGetKnownFolderPath(FOLDERID_RoamingAppData, 0, nullptr,
                                    &app_data))) {
    return std::wstring();
  }
  std::wstring folder = std::wstring(app_data) + L"\\Flights";
  ::CoTaskMemFree(app_data);
  ::CreateDirectoryW(folder.c_str(), nullptr);
  return folder + L"\\saves.json";
}

const std::string* StringArgument(const flutter::EncodableValue* arguments,
                                  const char* key) {
  const auto* map = std::get_if<flutter::EncodableMap>(arguments);
  if (!map) return nullptr;
  auto it = map->find(flutter::EncodableValue(key));
  if (it == map->end()) return nullptr;
  return std::get_if<std::string>(&it->second);
}

}  // namespace

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

  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "me.guslipkin.flights/platform",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([](const auto& call, auto result) {
    const std::string& method = call.method_name();
    if (method == "playSound") {
      const std::string* name = StringArgument(call.arguments(), "name");
      std::wstring file = ExeDirectory() +
                          L"\\data\\flutter_assets\\assets\\audio\\" +
                          Widen(name ? *name : "jet_hop") + L".wav";
      // Asynchronous, so a hop never waits on its sound; a new sound cuts
      // off one still playing, which suits these short effects.
      ::PlaySoundW(file.c_str(), nullptr,
                   SND_FILENAME | SND_ASYNC | SND_NODEFAULT);
      result->Success();
    } else if (method == "readSave") {
      std::ifstream in(SavePath(), std::ios::binary);
      if (!in) {
        result->Success();
        return;
      }
      std::ostringstream text;
      text << in.rdbuf();
      result->Success(flutter::EncodableValue(text.str()));
    } else if (method == "writeSave") {
      const std::string* content = StringArgument(call.arguments(), "content");
      std::wstring path = SavePath();
      if (!content || path.empty()) {
        result->Success(flutter::EncodableValue(false));
        return;
      }
      // Write beside it, then swap in, so a crash mid-write can't leave a
      // half-written save.
      std::wstring temp = path + L".tmp";
      {
        std::ofstream out(temp, std::ios::binary | std::ios::trunc);
        out << *content;
        if (!out) {
          result->Success(flutter::EncodableValue(false));
          return;
        }
      }
      bool ok = ::MoveFileExW(temp.c_str(), path.c_str(),
                              MOVEFILE_REPLACE_EXISTING) != 0;
      result->Success(flutter::EncodableValue(ok));
    } else if (method == "appVersion") {
      result->Success(flutter::EncodableValue(std::string(FLUTTER_VERSION)));
    } else if (method == "openUrl") {
      const std::string* url = StringArgument(call.arguments(), "url");
      // Only web links: ShellExecute would also run programs and files.
      if (url && (url->rfind("https://", 0) == 0 ||
                  url->rfind("http://", 0) == 0)) {
        ::ShellExecuteW(nullptr, L"open", Widen(*url).c_str(), nullptr,
                        nullptr, SW_SHOWNORMAL);
      }
      result->Success();
    } else {
      // Includes shareText: the Dart side falls back to the clipboard.
      result->NotImplemented();
    }
  });
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
  // The channel talks through the engine, so it goes first.
  channel_ = nullptr;
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
    case WM_GETMINMAXINFO: {
      // The minimum is for the content, scaled for the display, plus the
      // window's frame and title bar.
      UINT dpi = ::GetDpiForWindow(hwnd);
      RECT frame = {0, 0, MulDiv(kMinWidth, dpi, 96),
                    MulDiv(kMinHeight, dpi, 96)};
      ::AdjustWindowRectExForDpi(
          &frame, static_cast<DWORD>(::GetWindowLongPtr(hwnd, GWL_STYLE)),
          FALSE, static_cast<DWORD>(::GetWindowLongPtr(hwnd, GWL_EXSTYLE)),
          dpi);
      auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
      info->ptMinTrackSize.x = frame.right - frame.left;
      info->ptMinTrackSize.y = frame.bottom - frame.top;
      return 0;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
