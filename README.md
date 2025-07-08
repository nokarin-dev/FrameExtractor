# FrameExtractor

<div align="center">
  <img src="https://img.shields.io/github/v/release/nokarin-dev/FrameExtractor?style=flat-square" />
  <a href="https://github.com/nokarin-dev/FrameExtractor/actions/workflows/build.yml">
    <img src="https://github.com/nokarin-dev/FrameExtractor/actions/workflows/build.yml/badge.svg" alt="Build Status" />
  </a>
</div>

**FrameExtractor** is a modern, cross-platform, GUI-based video frame extractor built using Qt 6 and FFmpeg. It allows you to extract specific frame ranges from any video file with customizable FPS, image format, and naming options.

---

# Features
- Extract frames from a specific time range (e.g. `00:00:05` to `00:00:10`)
- Adjustable frame rate (1–60 FPS)
- Choose between PNG, JPG, or JPEG output formats
- Customizable filename prefix (e.g. `my_frame001.png`)
- Cross-platform: Windows, Linux (AppImage), macOS

---

# Usage
### 1. Download the executable
Head to the [Releases page](https://github.com/nokarin-dev/FrameExtractor/releases) and download the latest version for your platform:
- `FrameExtractor.exe` (Windows)
- `FrameExtractor.AppImage` (Linux)
- (macOS version coming soon)

### 2. Extract frames:
- Load your video file
- Set start & end time (format HH:MM:SS)
- Choose FPS, file format, and output directory
- Select output folder and click Extract

---

# Build
## Dependencies
- Qt 6.2+ (tested with Qt 6.6)
- CMake (or qmake)
- C++17 or later
- FFmpeg in system PATH

## Linux/macOS
```bash
mkdir build && cd build
cmake ..
make
./FrameExtractor
```

## Windows (MSVC or MinGW)
**Use Qt Creator or**:
```bash
mkdir build && cd build
cmake .. -G "MinGW Makefiles"
mingw32-make
```
Or open the .pro / CMakeLists.txt in Qt Creator.

---

# License
```
FrameExtractor is under MIT License
```
Made with ❤️ by nokarin-dev
