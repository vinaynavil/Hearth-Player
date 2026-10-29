# Hearth Player

<p align="center">
  <strong>A sleek, modern, and high-performance desktop video player for Windows.</strong>
</p>

<p align="center">
  <a href="https://github.com/vinaynavil/Hearth-Player/releases/latest"><img src="https://img.shields.io/github/v/release/vinaynavil/Hearth-Player?style=flat-square&color=crimson" alt="Latest Release"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter" alt="Flutter"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/vinaynavil/Hearth-Player?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/Platform-Windows-0078D6?style=flat-square&logo=windows" alt="Platform">
</p>

---

<p align="center">
  <a href="https://github.com/vinaynavil/Hearth-Player/releases/download/v1.0.6/Hearth_Setup_1.0.6.exe">
    <img src="https://img.shields.io/badge/Download-Hearth%20Setup%20(v1.0.6)-blue?style=for-the-badge&logo=windows&logoColor=white" alt="Download Hearth Player">
  </a>
</p>

---

## ✨ Features

- **High-Performance Playback**: GPU-accelerated video rendering powered by MediaKit and D3D11VA for smooth, stutter-free playback.
- **Cinema-Grade Subtitles**: Modern, borderless text rendering with soft cinema shadows for optimal readability without distracting backgrounds.
- **Audio & Subtitle Track Switching**: Quick on-the-fly toggling of embedded and external subtitle streams and multi-language audio tracks.
- **Library & Smart Resume**: Automatically tracks playback positions, master progress, and recent watches.
- **Custom Modern UI**: Borderless window controls, responsive layouts, and smooth micro-interactions tailored for desktop.
- **Hardware Controls**: Full integration with Windows media keys and customizable keyboard shortcuts.

---

## 🚀 Download & Installation

1. Head over to the [Releases](https://github.com/vinaynavil/Hearth-Player/releases/latest) page.
2. Download **`Hearth_Setup_1.0.6.exe`**.
3. Run the installer and launch Hearth.

---

## 🛠️ Building from Source

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) (3.13+)
- [Visual Studio 2022](https://visualstudio.microsoft.com/) with "Desktop development with C++" workload
- Git

### Quick Start

```powershell
# Clone the repository
git clone https://github.com/vinaynavil/Hearth-Player.git
cd Hearth-Player

# Install Flutter dependencies
flutter pub get

# Run in debug mode
flutter run -d windows

# Build optimized release executable
flutter build windows --release
```

The compiled release output will be located in `build/windows/x64/runner/Release/`.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
