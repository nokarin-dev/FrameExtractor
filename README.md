# FrameExtractor
**FrameExtractor** is a powerful cross-platform CLI tool to extract frames from videos using FFmpeg.  
It supports custom frame rate (FPS), time range trimming, custom filename prefix, and output format (PNG, JPG, JPEG).  
Designed to be simple, fast, and developer-friendly.

---

# Features
- Extract frames from any video file
- Select custom start and end time (e.g., 00:10 to 00:20)
- Control frame rate (e.g., 1 fps, 10 fps, 30 fps)
- Custom frame filename prefix (e.g., `myframe_1.jpg`)
- Output directory auto-generated or user-defined
- Choose image format: `png`, `jpg`, or `jpeg`
- FFmpeg log written to `video_to_frames.log`
- Real-time terminal progress bar
- Auto-check and offer to install FFmpeg if missing
- Build-ready as single executable for Windows, Linux, and macOS

---

# Usage (CLI)
```bash
$ python video_to_frames.py
```

---

# License
```
FrameExtractor is under MIT License
```
Made with ❤️ by nokarin-dev