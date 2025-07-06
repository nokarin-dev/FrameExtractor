# 📦 Changelog

All notable changes to this project will be documented in this file.

The format is based on [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) and this project adheres to [Semantic Versioning](https://semver.org/).

---

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