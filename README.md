![FrameExtractor Banner](https://github.com/user-attachments/assets/d458829a-c268-4590-911e-1e00fc964312)

<div align="center">

**A modern, cross-platform video frame extractor with a clean UI built with Flutter, powered by ffmpeg and yt-dlp. Supports local video files and direct YouTube URL extraction.**

[![Release](https://img.shields.io/github/v/release/nokarin-dev/frameextractor?style=for-the-badge&color=4F8EF7)](https://github.com/nokarin-dev/frameextractor/releases/latest)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=for-the-badge)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.22-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20Android-02569B?style=for-the-badge)](#download)

[![Total Downloads](https://img.shields.io/github/downloads/nokarin-dev/frameextractor/total?style=for-the-badge&logoColor=%3D&color=3471eb
)](https://github.com/nokarin-dev/FrameExtractor/releases)
[![Latest Downloads](https://img.shields.io/github/downloads/nokarin-dev/frameextractor/latest/total?style=for-the-badge&color=3d47d4
)](https://github.com/nokarin-dev/FrameExtractor/releases/latest)
[![Test Status](https://img.shields.io/github/actions/workflow/status/nokarin-dev/frameextractor/build-test.yml?style=for-the-badge&label=test%20build&color=22316e
)](https://github.com/nokarin-dev/FrameExtractor/actions/workflows/build-test.yml)

</div>

---

<img width="1536" height="100" alt="Features" src="https://github.com/user-attachments/assets/675712a8-29e3-4d60-a6cf-b6fee50516c9" />

- 🎬 **Extract frames** from any local video file with precise start/end timestamps
- 📺 **YouTube support** - paste a URL, pick quality, extract directly (yt-dlp powered)
- ⚡ **Adjustable FPS** - from 1 to 60 frames per second
- 🖼️ **Multiple formats** - PNG, JPG, WebP, BMP
- 🎚️ **Quality & scale control** - fine-tune output image quality and resolution
- 📁 **Custom filename prefix** - name your frames however you like
- 🗂️ **Auto open folder** when extraction completes
- 📋 **Live process log** - view ffmpeg/yt-dlp output in real time, copy to clipboard
- 🔋 **Batteries included** - ffmpeg & yt-dlp bundled, no manual installation needed
- 🖥️ **Cross-platform** - Windows, Linux, Android

---

<img width="1536" height="100" alt="Downloads" tag="download" src="https://github.com/user-attachments/assets/fdc58dff-3ba3-4b2a-98aa-d2992f02c1c0" />

Head to the [**Releases**](https://github.com/nokarin-dev/frameextractor/releases/latest) page and grab the build for your platform.

| Platform            | File                                    | Notes                                                       |
|---------------------|-----------------------------------------|-------------------------------------------------------------|
| 🪟 Windows          | `FrameExtractor-windows-installer.zip`  | Installation for windows                                    |
| 🪟 Windows Portable | `FrameExtractor-windows-portable.zip`   | No installation needed                                      |
| 🐧 Linux Debian     | `FrameExtractor-linux-installer.deb`    | Installation for debian (Ubuntu, Linux mint, etc)           |
| 🐧 Linux RPM        | `FrameExtractor-linux-installer.rpm`    | Installation for rpm (Fedora, RHEL, etc)                    |
| 🐧 Linux Portable   | `FrameExtractor-linux-portable.tar.gz`  | No installation needed                                      |
| 🐧 Linux            | `FrameExtractor-linux.AppImage`         | No installation needed                                      |
| 🤖 Android          | `FrameExtractor-android-arm32.apk`      | Enable "Install unknown apps" in settings (For older phone) |
| 🤖 Android          | `FrameExtractor-android-arm64.apk`      | Enable "Install unknown apps" in settings                   |
| 🤖 Android          | `FrameExtractor-android-x86_64.apk`     | Emulators / Chromebooks                                     |

---

<img width="1536" height="100" alt="Build from source" src="https://github.com/user-attachments/assets/0046c3b4-52c8-4aa2-8ece-b7f0ba9e39c9" />

### Prerequisites
- [Flutter 3.22+](https://docs.flutter.dev/get-started/install)
- Python 3.8+ (for the binary download script)
- Git

### 1. Clone & install dependencies
```bash
git clone https://github.com/nokarin-dev/frameextractor.git
cd frameextractor
flutter pub get
```

### 2. Download bundled binaries
The app bundles ffmpeg and yt-dlp. Run the script to download them for your target platform:

```bash
# Windows + Linux
python3 scripts/prepare_binaries.py --platform windows linux

# All platforms
python3 scripts/prepare_binaries.py --all
```

> Sources: [ffmpeg (BtbN builds)](https://github.com/BtbN/FFmpeg-Builds/releases) · [yt-dlp](https://github.com/yt-dlp/yt-dlp/releases)

### 3. Run / Build
```bash
# Debug run
flutter run -d linux # or windows / macos / android / ios

# Release builds
flutter build linux --release --dart-define=PORTABLE=false # installer
flutter build linux --release --dart-define=PORTABLE=true # portable
flutter build windows --release --dart-define=PORTABLE=false
flutter build windows --release --dart-define=PORTABLE=true
flutter build apk --release --split-per-abi # Android
```

---

<img width="1536" height="100" alt="Platform Status" src="https://github.com/user-attachments/assets/66a64334-f413-4096-8618-0896fbfe8f7d" />

| Platform |  Tested  |
|----------|----------|
| Windows  | ✅       |
| Linux    | ✅       |
| Android  | ✅       |

---

<img width="1536" height="100" alt="Preview" src="https://github.com/user-attachments/assets/51d91558-920f-4204-8512-fa0e965872f3" />

### Home Screen - Local
<img width="1920" height="1043" alt="Home Screen Local" src="https://github.com/user-attachments/assets/7f9eda10-56f2-48af-bba6-da76f0d9af1f" />

### Home Screen - YouTube
<img width="1920" height="1043" alt="Home Screen Youtube" src="https://github.com/user-attachments/assets/cec072af-d0e6-487b-9ca4-367fe1fb3ae3" />

### Settings Screen
<img width="1920" height="1043" alt="Settings Screen" src="https://github.com/user-attachments/assets/4e55668d-f5c5-440f-b28e-3b82bea546e7" />

### Log Screen
<img width="1920" height="1043" alt="Log Screen" src="https://github.com/user-attachments/assets/2bce129c-cfee-4b16-914a-95a7b29ee5dc" />

---

<img width="1536" height="100" alt="License" src="https://github.com/user-attachments/assets/2f42a033-c32f-47c1-8c93-27fa53d538b4" />

```
FrameExtractor
Copyright © 2025-2026 nokarin-dev

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
```
