#!/usr/bin/env python3
"""Builds the side-by-side launch video from tools/tap-launch.sh recordings, aligned on the start of each launch animation.

  launch-video.py [--pre 0.5] [--seconds 10] [--out results/tap-launch/launch-grid.mp4]
"""
import argparse
import re
import subprocess

import numpy as np
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPS = [("react-native", "React Native"), ("flutter", "Flutter"), ("whisker", "Whisker"),
        ("nsh", "Native Shell"), ("nativescript", "NativeScript"), ("exact", "Exact")]
FONT = "/System/Library/Fonts/Helvetica.ttc"
CELL_W, CELL_H, LABEL_H, COLS = 360, 780, 56, 3


def tap_time(log, video):
    """When the launch animation starts: the XCTest log's tap time is off by up to ~0.4 s against the
    recording, so it only bounds a search for the first frame that differs from the Home Screen."""
    m = re.search(r't =\s+([\d.]+)s Tap "Everbloom" Icon', Path(log).read_text())
    start = float(m.group(1)) - 0.6
    # Decode from 0 with fps= filling gaps: the recording has no frames while the screen is static,
    # so seeking with -ss would land on the first changed frame.
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(video),
         "-vf", f"fps=60:start_time=0,trim=start={start:.3f}:duration=2,scale=60:130,format=gray", "-f", "rawvideo", "-"],
        capture_output=True, check=True,
    ).stdout
    frames = np.frombuffer(raw, np.uint8).reshape(-1, 130, 60).astype(float)
    diff = np.abs(frames - frames[0]).mean(axis=(1, 2))
    return start + int(np.argmax(diff > 6)) / 60


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--pre", type=float, default=0.5, help="seconds kept before the tap")
    p.add_argument("--seconds", type=float, default=10)
    p.add_argument("--blur", type=float, default=0, help="blur the Home Screen until this long into the launch animation")
    p.add_argument("--out", default=str(ROOT / "results" / "tap-launch" / "launch-grid.mp4"))
    a = p.parse_args()

    inputs, filters = [], []
    for i, (app, name) in enumerate(APPS):
        d = ROOT / "results" / "tap-launch" / app
        video = next((d / "attachments").glob("*.mp4"))
        start = tap_time(d / "tap.log", video) - a.pre
        inputs += ["-i", str(video)]
        filters.append(
            # The recorder writes no frames while the screen is static: fps= fills gaps, tpad holds the end.
            f"[{i}:v]tpad=stop_mode=clone:stop_duration={a.seconds + 30},fps=30:start_time=0,"
            f"trim=start={start:.3f}:duration={a.seconds:.3f},setpts=PTS-STARTPTS,scale={CELL_W}:{CELL_H}:force_original_aspect_ratio=decrease,"
            + (f"boxblur=20:enable='lt(t,{a.pre + a.blur:.3f})'," if a.blur else "") +
            f"pad={CELL_W}:{CELL_H}:(ow-iw)/2:0:white,"
            f"pad={CELL_W}:{CELL_H + LABEL_H}:0:{LABEL_H}:white,"
            f"drawtext=fontfile={FONT}:text='{name}':fontsize=30:fontcolor=black:x=(w-tw)/2:y=14[v{i}]"
        )
    rows = (len(APPS) + COLS - 1) // COLS
    layout = "|".join(f"{(i % COLS) * CELL_W}_{(i // COLS) * (CELL_H + LABEL_H)}" for i in range(len(APPS)))
    filters.append("".join(f"[v{i}]" for i in range(len(APPS))) + f"xstack=inputs={len(APPS)}:layout={layout}:fill=white[grid]")
    filters.append(
        f"[grid]drawtext=fontfile={FONT}:text='%{{eif\\:max(0\\,t-{a.pre})\\:d}}.%{{eif\\:mod(max(0\\,t-{a.pre})*10\\,10)\\:d}} s':"
        f"fontsize=34:fontcolor=white:box=1:boxcolor=black@0.6:boxborderw=10:x=w-tw-20:y=h-th-20[out]"
    )
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", ";".join(filters), "-map", "[out]",
         "-t", f"{a.seconds:.3f}", "-c:v", "libx264", "-crf", "18", "-preset", "slow", "-pix_fmt", "yuv420p",
         "-movflags", "+faststart", a.out],
        check=True,
    )
    print(f"{a.out}: {COLS * CELL_W}x{rows * (CELL_H + LABEL_H)}, {a.seconds:.0f} s, tap at {a.pre} s")


if __name__ == "__main__":
    main()
