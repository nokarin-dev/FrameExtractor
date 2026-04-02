# Changelog

All notable changes to Frame Extractor are documented here.

This project loosely follows Keep a Changelog and uses Semantic Versioning.

---

## [Unreleased]

No Changes Yet.

---
## [1.1.3] - 2026-04-02
### Added
#### Core
- Update checker
- Included application icon to windows & android library
- Added RPM Build

### Fixed
#### CI/CD
- AppImage failed to launch
- Application failed to start and crash on android platform

### Changed
#### User Interface
- FrameExtractor Application Icon
- TitleBar & Splash Screen default material icon to FrameExtractor Icon
- Log Body not expandable now on mobile

## [1.1.2] - 2026-03-26
### Fixed
#### CI/CD
- Fixed Linux AppImage launch error `Is a directory` - `$EXE_NAME` was set in CI shell but not expanded inside the AppRun heredoc (single-quoted heredoc prevents variable substitution). AppRun now detects the executable at runtime using `find`

### Added
#### Core
- Style Switcher
    - Classic Style (Default)
    - Liquid Glass Style (EXPERIMENTAL)
- Theme Switcher
    - Dark Theme
    - Light Theme
- Keyboard Shortcut
    - Space (Extract)
    - Esc (Cancel Extraction)
    - Ctrl+L (Open Log Panel)
    - Ctrl+S (Open Settings Panel)
- Application Icons

### Changed
#### Android
- Upgrade android plugins to latest version

#### User Interface
- Log & Settings now show as dialog in desktop
- Splash Screen now following current theme & style

## [1.1.1] - 2026-03-22
### Fixed
#### Android
- Frame extraction now works correctly - ffmpeg output is written to the app's writable directory (`Android/data/com.nokarin.frameextractor/files/`) instead of trying to write directly to `/storage/emulated/0/` which is blocked by Android 10+ Scoped Storage
- YouTube download now uses the app's cache directory, fixing `Operation not permitted` error when downloading to external storage
- SAF (Storage Access Framework) URI resolution improved with proper fallback to writable app directory

### Added
#### User Interface
- Mouse cursor changes to pointer on all interactive elements (buttons, chips, sliders, file rows, tabs)
- Text cursor shown on text input fields
- Hint bar below Extract button — explains what needs to be selected before extraction can start
- Clear button on video file and output folder rows for quick reset
- Hover effect on file/folder rows using `borderHi` color
- Hover effect on Extract and Cancel buttons (brighter fill on hover)
- Toast notifications now include an icon (check, error, cancel)
- Progress card background tinted by phase: blue for extraction, red for YouTube download
- Log panel: color-coded log lines — `[ERR]` red, `[WARN]` orange, `[INFO]`/`[Android]`/`[Copy]` blue
- Log line count badge in log panel header

#### Settings & UX
- All extraction settings (FPS, quality, format, time range) are disabled until video source and output folder are both selected
- Tooltip on disabled settings card explaining what needs to be selected
- Source tab switching and YouTube quality chips are disabled during active extraction
- Advanced options toggle is disabled when settings are not yet unlocked
- Default output format changed from PNG to JPG (smaller file size)
- Default quality changed from 100% to 90%
- "Open folder when done" toggle now has a subtitle description


### Changed
#### UI
- Progress card is now shown/hidden dynamically instead of always visible
- Progress card label shows `EXTRACTING` or `DOWNLOADING` depending on the current phase
- Comment style in source code simplified (no decorative separator lines)

## [1.1.0] - 2026-03-21
### Added
#### Core Features
- Extract frames from local video files with precise start/end time control
- Adjustable frame rate (1–60 FPS)
- Multiple output formats: PNG, JPG, WebP, BMP
- Image quality control (1–100%)
- Resolution scaling (10%–200%)
- Custom filename prefix for frames
- Option to automatically open the output folder after extraction (desktop)

#### YouTube Support
- Paste a YouTube link and extract frames directly
- Automatically fetch video metadata (title, uploader, duration)
- Select video quality: Best / 1080p / 720p / 480p / 360p / Audio only
- Desktop uses bundled yt-dlp (no setup required)
- Android & iOS use youtube_explode_dart (no external binaries needed)
- Temporary downloaded videos are cleaned up automatically after processing

#### Platform Support
- Windows (installer + portable)
- Linux (installer + portable)
- Android (split APK: arm64, arm32, x86_64)

#### Bundled Tools
- ffmpeg and yt-dlp are included by default — no manual installation needed
- Android uses ffmpeg_kit (JNI)
- iOS uses native Dart-based solutions due to sandbox restrictions
- Desktop extracts required binaries automatically on first launch

#### User Interface
- Dark industrial-themed UI with a custom color palette
- Custom frameless window (desktop) with drag support
- Built-in minimize and close buttons (desktop)
- Source selection tabs: Local File / YouTube
- Real-time log panel (with terminal-style output)
- Copy logs to clipboard in one click
- Live progress tracking (percentage, frame count, ETA)
- Animated indicator during processing
- Format selection using chip-style buttons
- Collapsible advanced settings (scale, prefix, auto-open folder)
- Fully responsive layout (works on smaller/mobile screens)
- Splash screen showing binary initialization status

#### CI / CD
- GitHub Actions builds for all platforms on version tag push
- Automatic test builds on every push / pull request
- Auto-generated GitHub Releases with platform download table
- Android split APK build pipeline
- Local binary preparation script (`scripts/prepare_binaries.py`)

---

## Release Notes

### Android
Due to Scoped Storage (Android 10+), extracted frames are saved in:
`Android/data/com.nokarin.frameextractor/files/`

You can access them via:
Files → Internal Storage → Android → data → com.nokarin.frameextractor → files

### Desktop (Windows / Linux)
ffmpeg and yt-dlp are bundled inside the app.

On first launch, required binaries are extracted to:
- Installer:
    - Windows: `%AppData%\FrameExtractor\bin\`
    - Linux: `~/.local/share/FrameExtractor/bin/`
- Portable:
    - `bin/` folder next to the executable

---

[Unreleased]: https://github.com/nokarin-dev/frameextractor/compare/v1.1.3...HEAD
[1.1.3]: https://github.com/nokarin-dev/frameextractor/releases/tag/v1.1.3
[1.1.2]: https://github.com/nokarin-dev/frameextractor/releases/tag/v1.1.2
[1.1.1]: https://github.com/nokarin-dev/frameextractor/releases/tag/v1.1.1
[1.1.0]: https://github.com/nokarin-dev/frameextractor/releases/tag/v1.1.0