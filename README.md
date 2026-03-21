![FrameExtractor Banner](https://github.com/user-attachments/assets/35a4f382-1940-4fb8-99f8-fe04eb20934e?raw=true)

<div align="center">

**A modern, cross-platform video frame extractor with a clean UI - powered by ffmpeg & yt-dlp.**

[![Release](https://img.shields.io/github/v/release/nokarin-dev/frameextractor?style=flat-square&color=4F8EF7)](https://github.com/nokarin-dev/frameextractor/releases/latest)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=flat-square)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.22-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS%20%7C%20Android%20%7C%20iOS-02569B?style=flat-square)](#download)
[![Total Downloads](https://img.shields.io/github/downloads/nokarin-dev/frameextractor/total?style=flat-square&logoColor=%3D&color=3471eb
)](/releases)
[![Latest Downloads](https://img.shields.io/github/downloads/nokarin-dev/frameextractor/latest/total?style=flat-square&color=3d47d4
)](/releases/latest)
[![Test Status](https://img.shields.io/github/actions/workflow/status/nokarin-dev/frameextractor/build-test.yml?style=flat-square&label=test%20build&color=22316e
)](https://github.com/nokarin-dev/FrameExtractor/actions/workflows/build-test.yml)
[![Release Status](https://img.shields.io/github/actions/workflow/status/nokarin-dev/frameextractor/build.yml?style=flat-square&label=release%20build&color=22316e
)](https://github.com/nokarin-dev/FrameExtractor/actions/workflows/build.yml)

</div>

---

## Features

- 🎬 **Extract frames** from any local video file with precise start/end timestamps
- 📺 **YouTube support** - paste a URL, pick quality, extract directly (yt-dlp powered)
- ⚡ **Adjustable FPS** - from 1 to 60 frames per second
- 🖼️ **Multiple formats** - PNG, JPG, WebP, BMP
- 🎚️ **Quality & scale control** - fine-tune output image quality and resolution
- 📁 **Custom filename prefix** - name your frames however you like
- 🗂️ **Auto open folder** when extraction completes
- 📋 **Live process log** - view ffmpeg/yt-dlp output in real time, copy to clipboard
- 🔋 **Batteries included** - ffmpeg & yt-dlp bundled, no manual installation needed
- 🖥️ **Cross-platform** - Windows, Linux, macOS, Android, iOS

---

## Download

Head to the [**Releases**](https://github.com/nokarin-dev/frameextractor/releases/latest) page and grab the build for your platform.

| Platform            | File                                    | Notes                                                                                              |
|---------------------|-----------------------------------------|----------------------------------------------------------------------------------------------------|
| 🪟 Windows          | `FrameExtractor-windows-installer.zip`  | Extract & run `.exe`                                                                               |
| 🪟 Windows Portable | `FrameExtractor-windows-portable.zip`   | No installation needed                                                                             |
| 🐧 Linux            | `FrameExtractor-linux-installer.tar.gz` | Extract & run                                                                                      |
| 🐧 Linux Portable   | `FrameExtractor-linux-portable.tar.gz`  | Self-contained folder                                                                              |
| 🍎 macOS            | `FrameExtractor-macos-installer.dmg`    | Open & drag to Applications                                                                        |
| 🍎 macOS Portable   | `FrameExtractor-macos-portable.zip`     | Extract & run anywhere                                                                             |
| 🤖 Android          | `FrameExtractor-android.apk`            | Enable "Install unknown apps" in settings                                                          |
| 📱 iOS              | `FrameExtractor-ios-unsigned.ipa`       | Sideload via [AltStore](https://altstore.io) or [TrollStore](https://github.com/opa334/TrollStore) |

> **Note (iOS):** Due to Apple sandbox restrictions, yt-dlp cannot run as a binary on iOS. The YouTube feature uses an API fallback instead.

---

## Building from source

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
flutter build macos --release
flutter build apk --release # Android
flutter build ipa --release # iOS (requires Apple signing)
```

### Installer vs Portable (Windows & Linux)

|                      | Installer                                                              | Portable                  |
|----------------------|------------------------------------------------------------------------|---------------------------|
| Binary location      | `AppData/Local/FrameExtractor/bin/` (Win) or `~/.local/share/` (Linux) | Same folder as executable |
| Pass `--dart-define` | `PORTABLE=false`                                                       | `PORTABLE=true`           |

---

## Platform status
| Platform | Tested |
|----------|--------|
| Windows  | ✅      |
| Linux    | ✅      |
| Android  | ✅      |
| iOS      | ❌      |
| macOS    | ❌      |

## License

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
