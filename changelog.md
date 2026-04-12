# Changelog

All notable changes to Frame Extractor are documented here.

This project loosely follows Keep a Changelog and uses Semantic Versioning.

---

## [Unreleased]

No Changes Yet.

---

## [1.2.0] - 2026-04-13

### Added
#### Core
- **Preset System** - Save, browse, and apply named extraction presets (FPS, format, quality, scale, time range, prefix). Built-in presets included: High Quality PNG, Fast Preview, Web Optimized, 4K Lossless
- **Settings Persistence** - All extraction settings (FPS, format, quality, scale, time range, prefix, "open folder on done") are now saved between sessions and automatically restored on next launch
- **Frame & Size Estimator** - Live frame count and estimated output size shown below settings when a source and output folder are selected
- **Keyboard shortcut Ctrl+P** - Opens the Presets panel
- **Close confirmation dialog** - Closing the window while extraction is in progress now shows a confirmation dialog ("Keep Running" / "Close Anyway") instead of immediately terminating the process
- **Batch extraction** - define multiple time ranges (each with its own frame prefix) and extract all of them in a single run. A new `StartBatchExtraction` event drives the `ExtractionBloc`, which reports per-job progress (e.g. "Job 2/5: extracting…") and saves a separate history record for every completed job.
- **Extraction history** - every successful extraction is automatically saved to `AppPrefs` (max 50 records). The new History screen (title bar button or `Ctrl+H`) shows video name, frame count, elapsed time, fps, format, and the output path, with one-click "Open folder" and "Copy path" actions.
- **Video metadata card** - after selecting a local video the app runs `ffmpeg` (desktop) or `FFprobeKit` (Android) to read duration, resolution, fps, and codec, then renders a thumbnail alongside these details below the source card. The thumbnail is cached in the system temp directory so subsequent opens are instant.
- **Frame preview screen** - tap the thumbnail (or the preview button) to open a full-screen scrubber that renders the frame at any timestamp before committing to a full extraction. Uses `ffmpeg -vframes 1` under the hood; the preview is cached per-path-and-timestamp.
- **Drag & drop video files** (desktop) - drag any supported video file directly onto the app window using the `desktop_drop` package. Unsupported extensions show a toast error.
- **Keyboard shortcut `Ctrl+H`** - shortcut for history panel, added to the Settings keyboard shortcuts list.
- **Long-press hint overlay** - a subtle dark pill in the bottom-right corner of the preview image reminds users that long-pressing copies the timestamp.
- **`Ctrl+B` keyboard shortcut** - shortcut for batch panel, listed in the Settings shortcuts panel.

#### Bloc / Events
- `StartBatchExtraction` event - list of `ExtractionParams`, each run in sequence; first failure aborts the batch.
- `SavePreset` and `DeletePreset` events now have working handlers in `ExtractionBloc` (previously defined in `extraction_event.dart` but silently ignored because no `on<SavePreset>` / `on<DeletePreset>` handlers were registered).
- `LogLevel` enum (`debug`, `info`, `warn`, `error`) on `AppendLog` - debug-level lines are stored in the log buffer but tagged `[DEBUG]` so they are visually grouped; future work can filter them out of the panel.

#### Services
- `FFmpegService.getVideoMetadata(String videoPath)` - new abstract method implemented in both `FFmpegServiceDesktop` (ffmpeg) and `FFmpegServiceMobile` (FFprobeKit).
- `FFmpegService.extractPreviewFrame({required String videoPath, required String timestamp})` - renders a single JPEG to the temp directory; cached by path + timestamp.

#### Models
- `VideoMetadata` - new model: `duration`, `width`, `height`, `fps`, `codec`, `thumbnailPath`. Helpers: `resolutionLabel`, `durationFormatted`.
- `ExtractionRecord` - new model for history: full JSON serialization round-trips via `listFromJson` / `listToJson`. Fields: `id`, `videoPath`, `outputDirectory`,`frameCount`, `completedAt`, `elapsed`, `format`, `fps`. Helper: `videoName`.
- `ExtractionSuccess` now carries `frameCount` (previously always 0), which is used when persisting the history record.
- `ExtractionInProgress` now carries `batchIndex` and `batchTotal` for batch progress UI. Helper getter `isBatch`.

#### Validation
- **Time range validation** - Start/End time fields now validate in real-time: incorrect format (non-HH:MM:SS), start ≥ end, and range < 0.1s are flagged with inline error messages. Fields turn red and extraction is blocked until fixed
- **Pre-extraction validation** - `ExtractionParams` now has a `validate()` method and `isValid` getter. Both FFmpeg services validate params before running and emit a clear error if validation fails
- **Illegal character check** in frame name prefix (rejects `< > : " / \ | ? *`)
- **Recent video file validation** - Recent video entries are now checked for existence on disk at startup; stale entries are automatically removed from the list

#### ExtractionParams improvements
- `estimatedFrameCount` getter - calculates frames from time range × FPS
- `estimatedSizeBytes` and `estimatedSizeFormatted` getters - rough per-format size estimate
- `ExtractionParams.validated()` factory - throws `ArgumentError` with all error details if params are invalid
- `==` and `hashCode` overrides for safe comparison
- Descriptive `toString()`

#### Preset Model
- New `ExtractionPreset` model with full JSON serialization/deserialization
- `ExtractionPreset.defaults` - 4 built-in read-only presets
- `isDefault` flag - built-in presets cannot be deleted by the user

#### AppPrefs
- `lastFps`, `lastFormat`, `lastQuality`, `lastScale`, `lastStartTime`, `lastEndTime`, `lastPrefix`, `openFolderOnDone` - persisted extraction settings
- `customPresets`, `allPresets`, `savePreset()`, `deletePreset()`, `clearCustomPresets()` - full preset CRUD
- `addHistoryRecord()`, `history` getter, `clearHistory()` - history CRUD backed by `prefHistory` key.

#### AppConstants
- `prefLastFps`, `prefLastFormat`, `prefLastQuality`, `prefLastScale`, `prefLastStartTime`, `prefLastEndTime`, `prefLastPrefix`, `prefOpenFolderOnDone`, `prefPresets` - new preference keys
  - `ffmpegThreads` constant (defaults to `0` = auto)
- `maxCustomPresets` limit (20)
- Expanded `supportedVideoExtensions`: added `ts`, `3gp`
- `maxFps` raised from 60 → 120
- `minScale` lowered from 0.25 → 0.1, `maxScale` raised from 2.0 → 4.0
- `maxHistoryRecords` constant (50).
- `prefHistory` preference key.

#### User Interface
- **Presets panel** accessible via new title bar button (bookmarks icon) or Ctrl+P
  - Lists all presets with name, settings summary, Apply and Delete buttons
  - Built-in presets show a lock icon and cannot be deleted
- **Save as Preset** button inside Advanced settings panel
- **Estimate row** below settings card: shows `~N frames` and `~X MB` live as user adjusts FPS, format, quality, and time range
- **Pulse animation** for progress indicator now correctly starts/stops based on actual extraction state (was always running before)
- **Full path tooltip** on Video File and Output Folder rows - hovering shows the complete file/directory path, not just the truncated filename
- **History screen** - full-screen list of past extractions. Each tile shows video name, date, frame count, elapsed time, fps, format, and output path. "Clear all" with confirmation dialog. Works on desktop and Android (folder-open disabled on mobile).
- **VideoMetadataCard widget** - thumbnail + resolution + duration + codec + fps chips. Tapping opens FramePreviewScreen.
- **FramePreviewScreen** - scrubber slider (0–3600 s), timestamp label, refresh button, pinch-to-zoom via `InteractiveViewer`. Loading spinner and "could not extract" error state.
- **Set as Start / Set as End** - two buttons in the preview control bar let the user set the extraction start or end time directly from the scrubbed frame, updating `_startTimeCtrl` / `_endTimeCtrl` in the home screen without leaving the preview screen.
- **Retry on error** - if a frame cannot be extracted (e.g. timestamp beyond the actual end), an error state with a Retry button is shown instead of a blank screen.
- **Save log** button added next to "Copy all". On desktop it writes to the Downloads folder (falls back to Documents); on Android it writes to the app Documents directory. Filename format: `frameextractor_log_YYYY-MM-DDTHH-MM-SS.txt`. The button is visually disabled (dimmed) when there are no log lines.
- History button (clock icon) in title bar; `Ctrl+H` shortcut.
- ProgressSection now shows a "Job N of M" indicator during batch runs and renders a `BATCH` phase label.
- Time field error state: red border, red icon, red label, red tinted background, inline error text below field
- Presets keyboard shortcut `Ctrl+P` row added to Settings panel
- Update badge label changed from generic "out-of-date" to the specific version string (e.g. "v1.2.0 available")

### Fixed
#### Core
- **`SavePreset` / `DeletePreset` silently dropped** - the bloc now has `on<SavePreset>` and `on<DeletePreset>` handlers that call `AppPrefs.savePreset()` / `AppPrefs.deletePreset()`. Previously, dispatching these events did nothing.
- **`LogMixin` dead code removed** from `extraction_state.dart` - the mixin was defined but never mixed into any state class. Log state is correctly managed on the bloc itself as `_logs`.
- **`_parseSeconds` duplicated** in `home_screen.dart` and `extraction_params.dart` - both copies are replaced by a single top-level `parseTimeString(String t)` function exported from `extraction_params.dart`. The UI import is `show parseTimeString` to keep the namespace clean.
- **`isClosed` guards missing** inside `_copyFramesToUserDir` - every `await` in the copy loop and SAF path is now preceded by an `if (isClosed) return` guard, preventing state emissions after the bloc is disposed.
- **`[DEBUG]` log strings in user-visible panel** - bloc internal diagnostic lines are now emitted via `AppendLog(line, level: LogLevel.debug)` and stored with a `[DEBUG]` prefix. They appear in the log buffer (for export) but are visually distinguished from user-facing `[INFO]` / `[WARN]` / `[ERR]` lines.

#### YouTube Service
- **Cancel flag not reset** - `YouTubeService._cancelled` was never reset to `false` before starting a new download, causing the first download after a cancellation to immediately return `null`. Fixed via new `resetCancelFlag()` method called by `ExtractionBloc` before each download
- **YouTubeService recreated on every fetch** - `_fetchYtInfo()` was instantiating a new `YouTubeService()` on each button press. It now reuses the instance owned by `ExtractionBloc`, avoiding redundant allocations and potential state inconsistency

#### FFmpeg Services
- **FFmpegServiceMobile blocking UI thread** - replaced `FFmpegKit.execute()` with `FFmpegKit.executeAsync()` + polling loop, preventing jank during long extractions on mobile
- **Scale filter quality** - resolution scaling now uses `flags=lanczos` for better downscale quality
- Progress emit throttle reduced from 500ms → 300ms for more responsive progress updates
- `ffmpeg_service_base.dart`: `estimateExtractionImpl` now uses a more realistic speed estimate for PNG (67% of JPG speed)

#### User Interface
- **`_LiveThemeChild` polling loop removed** - the 100ms polling timer that detected theme changes by repeated `AppTheme.of()` calls is eliminated. Dialogs and sheets now read theme directly from the `InheritedWidget` (`AppTheme.of()`), which rebuilds automatically on change with zero overhead
- **`_AppThemeNotifier` static singleton removed** - the leaked `ChangeNotifier` singleton that was never disposed is fully removed. Theme propagation now relies exclusively on Flutter's `InheritedWidget` mechanism
- **`BlocBuilder` rebuild scope reduced** - the main `Column` is no longer wrapped in a single `BlocBuilder`. Each section (source card, output card, settings, progress, action buttons) now has its own narrowly-scoped `BlocBuilder` with `buildWhen` guards, so progress updates only rebuild the progress card instead of the entire screen
- **Pulse animation no longer synced inside `BlocBuilder` builder** - starting/stopping `_pulseCtrl` is now handled in `BlocListener` (side-effect handler) instead of the `BlocBuilder` rebuild cycle, preventing potential animation restart glitches
- **`ExtractionParams` construction cached** - estimate values (`_cachedEstimatedFrames`, `_cachedEstimatedSize`) are computed once via `_refreshEstimates()` when inputs change (slider, format chip, time field), instead of rebuilding `ExtractionParams` on every `build()` call
- **`_buildAdvancedToggle` opacity corrected** - was always applying the disabled opacity value regardless of the `disabled` flag. Now only applies reduced opacity when the toggle is actually disabled

### Changed
#### Architecture
- `buildVfFilter()` and `qualityToQv()` moved to `FFmpegService` base class (shared between desktop and mobile instead of duplicated)
- `ExtractionBloc._onStartYouTubeExtraction` now calls `youTubeService.resetCancelFlag()` before download
- `ExtractionBloc` persists settings to `AppPrefs` after each successful extraction start via `_persistSettings()`
- `HomeScreen._loadPrefs()` now restores all persisted extraction settings on init, and filters stale recent video entries asynchronously
- `_validateTimeRange()` wired to `_onTimeChanged()` listener which also triggers `_refreshEstimates()`, keeping estimate display in sync with time field edits
- `HomeScreen` split into focused files under `presentation/screens/sections/`: `source_section.dart`, `output_section.dart`, `settings_section.dart`, `advanced_section.dart`, `progress_section.dart`. The root `home_screen.dart` is now a thin orchestrator.
- Shared UI primitives extracted to `presentation/widgets/`: `app_card.dart`, `app_divider.dart`, `clear_row.dart`, `compact_field.dart`, `disabled_overlay.dart`, `file_row.dart`, `gloss_chip.dart`, `slider_row.dart`, `small_btn.dart`, `time_field.dart`, `video_metadata_card.dart`.
- `isGlass` and `isDark` are no longer prop-drilled through every widget constructor. All extracted widgets call `AppTheme.of(context)` directly, relying on Flutter's `InheritedWidget` mechanism.
- `ExtractionBloc._persistSettings` refactored to accept `ExtractionParams` instead of seven individual parameters.

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
- Hint bar below Extract button - explains what needs to be selected before extraction can start
- Clear button on video file and output folder rows for quick reset
- Hover effect on file/folder rows using `borderHi` color
- Hover effect on Extract and Cancel buttons (brighter fill on hover)
- Toast notifications now include an icon (check, error, cancel)
- Progress card background tinted by phase: blue for extraction, red for YouTube download
- Log panel: color-coded log lines - `[ERR]` red, `[WARN]` orange, `[INFO]`/`[Android]`/`[Copy]` blue
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
- ffmpeg and yt-dlp are included by default - no manual installation needed
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

[Unreleased]: https://github.com/nokarin-dev/frameextractor/compare/v1.2.0...HEAD
[1.1.3]: https://github.com/nokarin-dev/frameextractor/releases/tag/v1.2.0
[1.1.3]: https://github.com/nokarin-dev/frameextractor/releases/tag/v1.1.3
[1.1.2]: https://github.com/nokarin-dev/frameextractor/releases/tag/v1.1.2
[1.1.1]: https://github.com/nokarin-dev/frameextractor/releases/tag/v1.1.1
[1.1.0]: https://github.com/nokarin-dev/frameextractor/releases/tag/v1.1.0
