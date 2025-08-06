# FrameExtractor

<div align="center">
  <a href="https://github.strivo.xyz/nekoui-download/releases">
    <img src="https://img.shields.io/github/downloads/nokarin-dev/frameextractor/total?logo=github&labelColor=gray&color=black" alt="Total Downloads" />
  </a>
  <img src="https://img.shields.io/github/v/release/nokarin-dev/FrameExtractor?style=flat-square" />
  <a href="https://github.com/nokarin-dev/FrameExtractor/actions/workflows/build.yml">
    <img src="https://github.com/nokarin-dev/FrameExtractor/actions/workflows/build.yml/badge.svg" alt="Build Status" />
  </a>
</div>

**FrameExtractor** is a modern, cross-platform video frame extractor with a beautiful GUI built using [Avalonia UI](https://avaloniaui.net/) and [FFmpeg](https://ffmpeg.org/).  
It lets you extract frames from any video file with precise control over time range, FPS, output format, and naming.

> [!NOTE]
> This is a new rewrite of FrameExtractor using C#/Avalonia, and the features still not stable yet.

---

## Features

- Extract frames between specific timestamps (e.g. `00:00:05` to `00:00:15`)
- Adjustable frame rate (FPS)
- Supports PNG, JPG, and JPEG output formats
- Customizable output filename prefix
- Choose output directory with modern file/folder picker
- Cross-platform: Windows, Linux, macOS
- Lightweight, standalone executable with automatic FFmpeg detection

---

## Getting Started

### 1. Download

Head to the [Releases page](https://github.com/nokarin-dev/FrameExtractor/releases) and download the latest version for your platform:

- `FrameExtractor.exe` (Windows)
- `FrameExtractor.AppImage` (Linux)
-  macOS version (coming soon)

---

### 2. Usage

1. Launch the app.
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
Copyright © 2025 nokarin
```
Made with ❤️ using Avalonia & .NET

Built for creators and developers who need fast, precise frame extraction.