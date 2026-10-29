#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shlobj.h>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

bool SetRegistryStringValue(HKEY root, const std::wstring& subkey,
                            const wchar_t* value_name,
                            const std::wstring& data) {
  HKEY hkey = nullptr;
  LSTATUS status = ::RegCreateKeyExW(
      root, subkey.c_str(), 0, nullptr, REG_OPTION_NON_VOLATILE, KEY_WRITE,
      nullptr, &hkey, nullptr);
  if (status != ERROR_SUCCESS || hkey == nullptr) {
    return false;
  }
  status = ::RegSetValueExW(
      hkey, value_name, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(data.c_str()),
      static_cast<DWORD>((data.size() + 1) * sizeof(wchar_t)));
  ::RegCloseKey(hkey);
  return status == ERROR_SUCCESS;
}

std::wstring GetRegistryStringValue(HKEY root, const std::wstring& subkey,
                                    const wchar_t* value_name) {
  wchar_t buffer[MAX_PATH * 2] = {0};
  DWORD buffer_size = sizeof(buffer);
  LSTATUS status = ::RegGetValueW(
      root, subkey.c_str(), value_name, RRF_RT_REG_SZ, nullptr, buffer,
      &buffer_size);
  if (status == ERROR_SUCCESS) {
    return std::wstring(buffer);
  }
  return std::wstring();
}

void RegisterFileExplorerIntegration() {
  wchar_t exe_path_buf[MAX_PATH];
  DWORD len = ::GetModuleFileNameW(nullptr, exe_path_buf, MAX_PATH);
  if (len == 0 || len >= MAX_PATH) {
    return;
  }

  std::wstring exe_path(exe_path_buf, len);
  std::wstring icon_value = L"\"" + exe_path + L"\",0";
  std::wstring open_command = L"\"" + exe_path + L"\" \"%1\"";

  size_t last_slash = exe_path.find_last_of(L"\\/");
  std::wstring exe_name = (last_slash != std::wstring::npos)
                              ? exe_path.substr(last_slash + 1)
                              : L"hearth.exe";

  // Fast check: if the open command already matches, skip registry writes entirely.
  std::wstring existing_command = GetRegistryStringValue(
      HKEY_CURRENT_USER,
      L"Software\\Classes\\Hearth.VideoFile\\shell\\open\\command", nullptr);
  if (existing_command == open_command) {
    return;
  }

  // 1. ProgID Registration: Software\Classes\Hearth.VideoFile
  const std::wstring prog_id = L"Software\\Classes\\Hearth.VideoFile";
  SetRegistryStringValue(HKEY_CURRENT_USER, prog_id, nullptr, L"Hearth Video File");
  SetRegistryStringValue(HKEY_CURRENT_USER, prog_id, L"FriendlyTypeName", L"Hearth Video File");
  SetRegistryStringValue(HKEY_CURRENT_USER, prog_id + L"\\DefaultIcon", nullptr, icon_value);
  SetRegistryStringValue(HKEY_CURRENT_USER, prog_id + L"\\shell\\open", nullptr, L"Open with Hearth");
  SetRegistryStringValue(HKEY_CURRENT_USER, prog_id + L"\\shell\\open", L"Icon", icon_value);
  SetRegistryStringValue(HKEY_CURRENT_USER, prog_id + L"\\shell\\open\\command", nullptr, open_command);

  // 2. Application Registration: Software\Classes\Applications\<exe_name>
  const std::wstring app_key = L"Software\\Classes\\Applications\\" + exe_name;
  SetRegistryStringValue(HKEY_CURRENT_USER, app_key, L"FriendlyAppName", L"Hearth");
  SetRegistryStringValue(HKEY_CURRENT_USER, app_key + L"\\DefaultIcon", nullptr, icon_value);
  SetRegistryStringValue(HKEY_CURRENT_USER, app_key + L"\\shell\\open\\command", nullptr, open_command);

  // 3. Supported Extensions & File Associations
  const std::wstring extensions[] = {
      L".mp4", L".mkv", L".avi", L".mov", L".webm",
      L".wmv", L".flv", L".m4v", L".ts",  L".m2ts",
  };

  for (const auto& ext : extensions) {
    SetRegistryStringValue(HKEY_CURRENT_USER,
                           app_key + L"\\SupportedTypes", ext.c_str(), L"");
    SetRegistryStringValue(HKEY_CURRENT_USER,
                           L"Software\\Classes\\" + ext + L"\\OpenWithProgids",
                           L"Hearth.VideoFile", L"");
    const std::wstring sys_assoc =
        L"Software\\Classes\\SystemFileAssociations\\" + ext + L"\\shell\\Hearth";
    SetRegistryStringValue(HKEY_CURRENT_USER, sys_assoc, nullptr, L"Open with Hearth");
    SetRegistryStringValue(HKEY_CURRENT_USER, sys_assoc, L"Icon", icon_value);
    SetRegistryStringValue(HKEY_CURRENT_USER, sys_assoc + L"\\command", nullptr, open_command);
  }

  ::SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);
}

bool IsWorkspaceBuild() {
#ifdef _DEBUG
  return true;
#else
  wchar_t exe_path_buf[MAX_PATH];
  DWORD len = ::GetModuleFileNameW(nullptr, exe_path_buf, MAX_PATH);
  if (len == 0 || len >= MAX_PATH) {
    return false;
  }
  std::wstring exe_path(exe_path_buf, len);
  for (wchar_t& ch : exe_path) {
    ch = static_cast<wchar_t>(::towlower(ch));
  }
  return exe_path.find(L"\\build\\windows\\") != std::wstring::npos;
#endif
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  const bool is_workspace = IsWorkspaceBuild();
  const wchar_t* kMutexName =
      is_workspace ? L"Local\\HearthMediaPlayerSingleInstanceMutex_Dev"
                   : L"Local\\HearthMediaPlayerSingleInstanceMutex";
  const wchar_t* kWindowTitle =
      is_workspace ? L"Hearth (Dev)" : L"Hearth";

  HANDLE single_instance_mutex = ::CreateMutexW(nullptr, TRUE, kMutexName);
  if (single_instance_mutex != nullptr &&
      ::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing_window =
        ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", kWindowTitle);
    if (!existing_window && !is_workspace) {
      existing_window =
          ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"hearth");
    }
    if (existing_window) {
      for (const std::string& arg : command_line_arguments) {
        if (!arg.empty() && arg[0] != '-') {
          COPYDATASTRUCT cds{};
          cds.dwData = 0x48525448; // 'HRTH'
          cds.cbData = static_cast<DWORD>(arg.size() + 1);
          cds.lpData = const_cast<char*>(arg.c_str());
          ::SendMessageW(existing_window, WM_COPYDATA,
                         reinterpret_cast<WPARAM>(nullptr),
                         reinterpret_cast<LPARAM>(&cds));
          break;
        }
      }
      if (::IsIconic(existing_window)) {
        ::ShowWindow(existing_window, SW_RESTORE);
      }
      ::SetForegroundWindow(existing_window);
    }
    ::CloseHandle(single_instance_mutex);
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  if (!is_workspace) {
    RegisterFileExplorerIntegration();
  }

  flutter::DartProject project(L"data");
  project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kWindowTitle, origin, size)) {
    if (single_instance_mutex != nullptr) {
      ::ReleaseMutex(single_instance_mutex);
      ::CloseHandle(single_instance_mutex);
    }
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (single_instance_mutex != nullptr) {
    ::ReleaseMutex(single_instance_mutex);
    ::CloseHandle(single_instance_mutex);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
