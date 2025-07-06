import os
import subprocess
import sys
import platform
import shutil
import re
from datetime import datetime

LOG_FILE = "frame.log"

def log(message):
    timestamp = datetime.now().strftime("[%Y-%m-%d %H:%M:%S]")
    with open(LOG_FILE, "a") as f:
        f.write(f"{timestamp} {message}\n")
    print(message)

def check_ffmpeg():
    if shutil.which("ffmpeg") is not None:
        log("✔ FFmpeg is installed.")
        return True
    else:
        log("❌ FFmpeg is not installed.")
        return False

def ask_install_ffmpeg():
    answer = input("FFmpeg is not installed. Do you want to install it automatically? (y/n): ").lower()
    if answer != 'y':
        log("User declined FFmpeg installation.")
        sys.exit("Cannot continue without FFmpeg.")
    install_ffmpeg()

def install_ffmpeg():
    os_name = platform.system()
    distro = platform.linux_distribution()[0].lower() if hasattr(platform, 'linux_distribution') else ""

    try:
        if os_name == "Linux":
            if "ubuntu" in distro or "debian" in distro:
                subprocess.run(["sudo", "apt", "update"])
                subprocess.run(["sudo", "apt", "install", "-y", "ffmpeg"])
            elif "arch" in distro or "manjaro" in distro:
                subprocess.run(["sudo", "pacman", "-S", "--noconfirm", "ffmpeg"])
            elif "fedora" in distro:
                subprocess.run(["sudo", "dnf", "install", "-y", "ffmpeg"])
            else:
                log("❌ Unsupported Linux distro. Please install ffmpeg manually.")
                sys.exit(1)

        elif os_name == "Darwin":  # macOS
            subprocess.run(["brew", "install", "ffmpeg"])

        elif os_name == "Windows":
            log("🔗 Please download and install FFmpeg manually: https://ffmpeg.org/download.html")
            input("Press Enter after installing FFmpeg and ensuring it is in your PATH...")
        else:
            log("❌ Unsupported operating system.")
            sys.exit(1)
    except Exception as e:
        log(f"❌ Failed to install ffmpeg: {str(e)}")
        sys.exit(1)

    if not check_ffmpeg():
        log("❌ FFmpeg installation failed or not found in PATH.")
        sys.exit(1)

def time_to_seconds(t):
    h, m, s = t.split(':')
    s, ms = s.split('.') if '.' in s else (s, 0)
    return int(h) * 3600 + int(m) * 60 + int(s) + int(ms) / 100

def time_to_ffmpeg_format(t):
    """Convert mm:ss or ss to HH:MM:SS"""
    if ':' in t:
        parts = list(map(int, t.strip().split(':')))
        if len(parts) == 2:
            return f"00:{parts[0]:02}:{parts[1]:02}"
        elif len(parts) == 3:
            return f"{parts[0]:02}:{parts[1]:02}:{parts[2]:02}"
    else:
        seconds = int(t)
        return f"00:00:{seconds:02}"

def get_user_input():
    path = input("Enter path to video file: ").strip('"')
    if not os.path.exists(path):
        log("❌ File does not exist.")
        sys.exit(1)

    start_time = time_to_ffmpeg_format(input("Start time (in seconds or mm:ss): "))
    end_time = time_to_ffmpeg_format(input("End time (in seconds or mm:ss): "))
    fps = input("FPS to extract (e.g. 1, 10, 30): ")

    image_format = input("Image format? (png/jpg/jpeg): ").strip().lower()
    if image_format not in ['png', 'jpg', 'jpeg']:
        log("❌ Invalid image format.")
        sys.exit(1)

    prefix = input("Enter frame filename prefix (e.g., '69'): ").strip()
    if not prefix:
        prefix = "frame"

    base_name = os.path.splitext(os.path.basename(path))[0]
    default_base_dir = f"{base_name}_{image_format}"

    output_path = input(f"Output directory (leave blank for default: {default_base_dir}): ").strip()
    if not output_path:
        output_path = default_base_dir

    os.makedirs(output_path, exist_ok=True)
    log(f"📁 Output directory created: {output_path}")

    return path, start_time, end_time, fps, image_format, output_path, prefix

def extract_frames_ffmpeg(video_path, start, end, fps, image_format, output_dir, prefix):
    temp_pattern = os.path.join(output_dir, f"{prefix}%d.{image_format}")

    ffmpeg_cmd = [
        "ffmpeg",
        "-ss", start,
        "-to", end,
        "-i", video_path,
        "-vf", f"fps={fps}",
        "-fps_mode", "vfr",
        temp_pattern,
        "-hide_banner",
    ]

    log("🎬 Running FFmpeg to extract frames...")

    # Calculate total seconds for progress bar
    start_sec = time_to_seconds(start)
    end_sec = time_to_seconds(end)
    duration = end_sec - start_sec

    with open(LOG_FILE, "a") as log_file:
        log_file.write(f"\n--- FFmpeg Command: {' '.join(ffmpeg_cmd)} ---\n")

        process = subprocess.Popen(ffmpeg_cmd, stderr=subprocess.PIPE, stdout=subprocess.DEVNULL, text=True)

        for line in process.stderr:
            log_file.write(line)
            line = line.strip()

            # Match time from FFmpeg output
            match = re.search(r'time=(\d+:\d+:\d+\.\d+)', line)
            if match:
                current_time = match.group(1)
                elapsed_sec = time_to_seconds(current_time)
                percent = min(100, int((elapsed_sec / duration) * 100))

                bar_length = 40
                filled = int(bar_length * percent / 100)
                bar = '=' * filled + ' ' * (bar_length - filled)
                print(f"\rProgress: [{bar}] {percent}% ", end='', flush=True)

        process.wait()

    if process.returncode == 0:
        log(f"\n✅ Done! Frames saved to: {output_dir}")
    else:
        log("\n❌ FFmpeg failed to extract frames.")

if __name__ == "__main__":
    log("=== Video to Frames Script Started ===")
    if not check_ffmpeg():
        ask_install_ffmpeg()

    video_path, start_time, end_time, fps, image_format, output_path, prefix = get_user_input()
    extract_frames_ffmpeg(video_path, start_time, end_time, fps, image_format, output_path, prefix)
    log("=== Script Finished ===")
