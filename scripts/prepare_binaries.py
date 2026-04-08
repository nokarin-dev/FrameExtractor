#!/usr/bin/env python3

import argparse, platform, shutil, stat, sys, tarfile, urllib.request, zipfile
from pathlib import Path

ASSETS_DIR  = Path("assets/binaries")
JNILIBS_DIR = Path("android/app/src/main/jniLibs")

SOURCES = {
    "windows": {
        "ffmpeg.exe": {
            "url":   "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip",
            "type":  "zip",
            "inner": "ffmpeg-master-latest-win64-gpl/bin/ffmpeg.exe",
        },
        "ffprobe.exe": {
            "url":   "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip",
            "type":  "zip",
            "inner": "ffmpeg-master-latest-win64-gpl/bin/ffprobe.exe",
        },
        "yt-dlp.exe": {
            "url":  "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe",
            "type": "raw",
        },
    },
    "linux": {
        "ffmpeg": {
            "url":   "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz",
            "type":  "tar.xz",
            "inner": "ffmpeg-master-latest-linux64-gpl/bin/ffmpeg",
        },
        "ffprobe": {
            "url":   "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz",
            "type":  "tar.xz",
            "inner": "ffmpeg-master-latest-linux64-gpl/bin/ffprobe",
        },
        "yt-dlp": {
            "url":  "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux",
            "type": "raw",
        },
    },
    "android/arm64-v8a": {
        "libytdlp.so": {
            "url":  "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_aarch64",
            "type": "raw",
        },
    },
    "android/armeabi-v7a": {
        "libytdlp.so": {
            "url":   "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_armv7l.zip",
            "type":  "zip",
            "inner": "yt-dlp_linux_armv7l",
        },
    },
    "android/x86_64": {
        "libytdlp.so": {
            "url":  "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux",
            "type": "raw",
        },
    },
}

def download(url, dest):
    print(f"    ↓  {url}")
    def hook(c, b, t):
        if t > 0: print(f"\r       {min(int(c*b*100/t),100)}%", end="", flush=True)
    urllib.request.urlretrieve(url, dest, hook)
    print()

def stage(plat, filename, spec):
    out_dir = ASSETS_DIR / plat
    out_dir.mkdir(parents=True, exist_ok=True)
    dest = out_dir / filename
    if dest.exists():
        print(f"  ✓  {dest}  (cached, {dest.stat().st_size//1024} KB)")
        return
    tmp = Path(f"/tmp/_fe_{plat.replace('/','_')}_{filename}")
    kind = spec["type"]
    try:
        if kind == "raw":
            download(spec["url"], dest)
        elif kind == "zip":
            download(spec["url"], tmp)
            with zipfile.ZipFile(tmp) as z:
                with z.open(spec["inner"]) as s, open(dest,"wb") as o: shutil.copyfileobj(s,o)
        elif kind == "tar.xz":
            download(spec["url"], tmp)
            with tarfile.open(tmp) as t:
                with t.extractfile(t.getmember(spec["inner"])) as s, open(dest,"wb") as o: shutil.copyfileobj(s,o)
    finally:
        if tmp.exists(): tmp.unlink()
    if platform.system() != "Windows":
        dest.chmod(dest.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
    print(f"  ✓  {dest}  ({dest.stat().st_size//1024} KB)")

    if plat.startswith("android/") and filename.endswith(".so"):
        abi = plat.split("/")[1] # arm64-v8a, armeabi-v7a, x86_64
        jni_dest = JNILIBS_DIR / abi / filename
        jni_dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(dest, jni_dest)
        print(f"  ✓  jniLibs/{abi}/{filename}  (symlinked from assets)")

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--platform", nargs="+", choices=["windows","linux","android","all"])
    p.add_argument("--all", action="store_true")
    args = p.parse_args()
    if not args.platform and not args.all: p.print_help(); sys.exit(1)
    targets = set()
    if args.all or (args.platform and "all" in args.platform):
        targets = set(SOURCES.keys())
    else:
        for x in (args.platform or []):
            if x == "android": targets.update(k for k in SOURCES if k.startswith("android/"))
            else: targets.add(x)
    failed = []
    for plat in sorted(targets):
        if plat not in SOURCES: print(f"\n⚠  No source: {plat}"); continue
        print(f"\n── {plat} ──")
        for fname, spec in SOURCES[plat].items():
            try: stage(plat, fname, spec)
            except Exception as e: print(f"  ✗  {fname}: {e}"); failed.append(f"{plat}/{fname}")
    print()
    if failed: print(f"✗  Failed: {', '.join(failed)}"); sys.exit(1)
    else: print("✅  Done. Run `flutter build` now.")

if __name__ == "__main__": main()