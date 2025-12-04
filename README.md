![FrameExtractor Banner](https://github.com/user-attachments/assets/35a4f382-1940-4fb8-99f8-fe04eb20934e)

<div align="center">

[![Build Status](https://github.com/nokarin-dev/FrameExtractor/actions/workflows/build.yml/badge.svg)](https://github.com/nokarin-dev/FrameExtractor/actions/workflows/build.yml)
[![Latest Version](https://img.shields.io/github/v/release/nokarin-dev/FrameExtractor?style=flat-square)](https://github.com/nokarin-dev/FrameExtractor/releases)
[![Total Download](https://img.shields.io/github/downloads/nokarin-dev/frameextractor/total?logo=github&labelColor=gray&color=black)](https://github.strivo.xyz/nekoui-download/releases)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/abda5110f8f04f86ba2dd067dd837e3b)](https://app.codacy.com/gh/nokarin-dev/FrameExtractor/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![License](https://img.shields.io/github/license/nokarin-dev/frameextractor)](https://github.com/nokarin-dev/FrameExtractor/blob/main/LICENSE)
[![Watch](https://img.shields.io/github/watchers/nokarin-dev/frameextractor?style=flat)](https://github.com/nokarin-dev/FrameExtractor)
[![Stars](https://img.shields.io/github/stars/nokarin-dev/frameextractor)](https://github.com/nokarin-dev/FrameExtractor)

</div>

**FrameExtractor** is a modern, cross-platform video frame extractor with a beautiful GUI built using [Avalonia UI](https://avaloniaui.net/) and [FFmpeg](https://ffmpeg.org/).  
It lets you extract frames from any video file with precise control over time range, FPS, output format, and naming.

> [!NOTE]
> This is a new rewrite of FrameExtractor using C#/Avalonia, and the features still not stable yet.

---

## Features

- Extract frames between specific timestamps (e.g. `00:00:05` to `00:00:15`).
- Adjustable frame rate (FPS).
- Supports PNG, JPG, and JPEG output formats.
- Customizable output filename prefix.
- Choose output directory with modern file/folder picker.
- Automatic FFmpeg detection (installs when missing).
- Cross-platform: Windows, Linux, and other platfrom will be supported soon.
- Lightweight, standalone binaries.

---

## Getting Started

### 1. Download

Head to the [Releases page](https://github.com/nokarin-dev/FrameExtractor/releases) and download the latest version for your platform:

- `FrameExtractor.exe` (Windows)
- `FrameExtractor` (Linux)

---

### 2. Usage

1. Launch the applications.
2. Click **Browse** to select your video.
3. Set:
    - **Start Time / End Time** (in HH:MM:SS)
    - **FPS** (e.g. `10`)
    - **Format** (e.g. PNG)
    - **Output directory** and frame name prefix.
4. Click **Extract Frames**.
5. Wait for progress to complete — frames will be saved to your selected folder.

---

## Build Instructions

### Requirements

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [FFmpeg](https://ffmpeg.org/) installed or auto-installed on first use
- Avalonia UI is bundled via NuGet

---

### Windows / Linux / macOS:

```bash
git clone https://github.com/nokarin-dev/FrameExtractor.git
cd FrameExtractor
dotnet restore
dotnet build -c Release
dotnet run --project FrameExtractor
```

To publish as a standalone executable:

```
# Windows
dotnet publish -c Release -r win-x64 --self-contained true

# Linux
dotnet publish -c Release -r linux-x64 --self-contained true

# macOS
dotnet publish -c Release -r osx-x64 --self-contained true
```

The executable will appear in `bin/Release/net8.0/<platform>/publish/`.

## License

```
MIT License
Copyright © 2025 nokarin-dev
```
