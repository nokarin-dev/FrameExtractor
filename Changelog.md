# 📦 Changelog

All notable changes to this project will be documented in this file.

The format is based on [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) and this project adheres to [Semantic Versioning](https://semver.org/).


---

## [v1.0.4] - 13/07/2025
### Features
- Input video and output directory fields are now side-by-side with "Browse" buttons.
- Automatically detects video duration and sets the "End Time" using `ffprobe`.
- Added a progress dialog while extracting frames to improve user feedback.

### Fixes
- Time fields, directory fields, and settings are now horizontally aligned for better UX.
- FFmpeg error dialog no longer renders off-screen; now centered and resizable.

### Enhancements
- Auto-installs FFmpeg if not found, with confirmation dialog.
- Overall UX improvements for smoother navigation and frame extraction process.
- FFmpeg error logs are shown in a scrollable, modal dialog for better debugging.

---

## [v1.0.1] - 08/07/2025
### Changed
- Migrating to cpp from python (idk why)

### Added
- Basic GUI with Qt: load video, set time range, and output
- FFmpeg frame extraction using hardcoded options
- Support for PNG output format
- Basic layout and functional frame export
- Automatically creates output directory if it doesn’t exist
- Improved FFmpeg error reporting with `QPlainTextEdit`
- Switched to **Dark Mode** using custom Qt palette
- Organized layout using `QGroupBox` sections
- Redesigned buttons and UI for a modern feel
- Added hover effects for all buttons
- Fixed bug where long error logs would overflow the window
- Made window **frameless** with rounded corners using `QPainter`
- Added **custom close button**
- Added CMake build support for Linux/macOS/Windows
- Provided working **AppImage** export for Linux
- Verified FFmpeg installation automatically on startup
- Integrated build badge and GitHub Actions CI

## [v1.0.0] - 06/07/2025
### Features
- Add support for extracting frames from specific time ranges
- Allow user-defined frame output prefix and format
- Add auto-creation of output directory and ffmpeg detection
- Initial release of `FrameExtractor`
- Cross-platform CLI for extracting video frames using ffmpeg
- Supports png, jpg, jpeg output formats
- Prompted CLI with options for FPS, start time, end time, output folder

### Improvements
- Show progress bar during extraction
- Write ffmpeg log to file