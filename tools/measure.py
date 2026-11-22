#!/usr/bin/env python3
"""Runs the full protocol in measurement/README.md for several apps and rounds, then extracts metrics.

  measure.py --udid UDID --host MAC_LAN_IP [--rounds 3] [--launch-runs 10] [--journey-runs 3]
             [--instruments activity,hitches,power] [--apps react-native,flutter,...] [--out results/<date>]
             [--app-path APP=PATH.app ...]

Round r starts at app r in APPS and wraps, so no framework always runs first. Each app is installed
alone, measured, extracted, and uninstalled. The replay server is started here and must not already run.
"""
import argparse
import datetime
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNS = Path.home() / "shopbench-runs"
APPS = {
    "react-native": ("reactnative", RUNS / "react-native/ios/build/Build/Products/Release-iphoneos/Everbloom.app"),
    "flutter": ("flutter", RUNS / "flutter/build/ios-device/Build/Products/Release-iphoneos/Runner.app"),
    "whisker": ("whisker", RUNS / "whisker/build/device/Build/Products/Release-iphoneos/Everbloom.app"),
    "nsh": ("nsh", RUNS / "nsh/build/ios-device/Build/Products/Release-iphoneos/Everbloom.app"),
    "nativescript": ("nativescript", RUNS / "nativescript/build/ios-device/Everbloom.app"),
    "exact": ("exact", RUNS / "exact/build/ios-device/Everbloom.app"),
    "uikit": ("uikit", RUNS / "uikit/build/Build/Products/Release-iphoneos/Everbloom.app"),
    "swiftui": ("swiftui", RUNS / "swiftui/build/Build/Products/Release-iphoneos/Everbloom.app"),
    "nativephp": ("nativephp", RUNS / "nativephp/nativephp/ios/build/Build/Products/Release-iphoneos/NativePHP.app"),
    "dartnative": ("dartnative", RUNS / "dartnative/build/ios/iphoneos/Runner.app"),
}


def bench(*args):
    subprocess.run([sys.executable, str(ROOT / "tools" / "bench.py"), *map(str, args)], check=True)


def log(msg):
    print(f"{time.strftime('%H:%M:%S')} {msg}", flush=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--udid", required=True)
    p.add_argument("--host", required=True, help="the Mac's LAN IP, reachable from the iPhone")
    p.add_argument("--rounds", type=int, default=3)
    p.add_argument("--first-round", type=int, default=1, help="resume from this round")
    p.add_argument("--launch-runs", type=int, default=10)
    p.add_argument("--journey-runs", type=int, default=3)
    p.add_argument("--instruments", default="activity,hitches,power")
    p.add_argument("--apps", default=",".join(APPS))
    p.add_argument("--settle", type=int, default=180, help="seconds idle after install, before measuring")
    p.add_argument("--out", default=str(ROOT / "results" / datetime.date.today().isoformat()))
    p.add_argument("--app-path", action="append", default=[], metavar="APP=PATH",
                   help="measure this .app instead of the default build of APP; repeatable")
    a = p.parse_args()

    apps = a.apps.split(",")
    paths = {app: path for app, (_, path) in APPS.items()}
    for item in a.app_path:
        app, _, path = item.partition("=")
        if app not in APPS or not path:
            p.error(f"--app-path expects APP=PATH with APP in {', '.join(APPS)}")
        paths[app] = Path(path).expanduser()
    api = f"http://{a.host}:8787/api"
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    replay = subprocess.Popen(
        [sys.executable, str(ROOT / "tools/replay/replay.py"), "serve", "--port", "8787", "--log", str(out / "replay.log")],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    try:
        time.sleep(2)
        for r in range(a.first_round, a.rounds + 1):
            order = apps[(r - 1) % len(apps):] + apps[:(r - 1) % len(apps)]
            log(f"round {r}: {' → '.join(order)}")
            for app in order:
                suffix, path = APPS[app][0], paths[app]
                bundle = f"dev.whiskerrs.shopbench.{suffix}"
                dest = out / f"round-{r}" / app
                if (dest / "metrics.json").exists():
                    log(f"{app}: already measured, skipping")
                    continue
                dest.mkdir(parents=True, exist_ok=True)
                common = ["--bundle-id", bundle, "--udid", a.udid, "--api", api]
                for other in APPS.values():
                    subprocess.run(["xcrun", "devicectl", "device", "uninstall", "app", "--device", a.udid,
                                    f"dev.whiskerrs.shopbench.{other[0]}"], capture_output=True)
                bench("size", "--app", path, "--out", dest)
                bench("prepare", "--app", path, *common)
                log(f"{app}: settling {a.settle} s")
                time.sleep(a.settle)
                if a.launch_runs:
                    log(f"{app}: launch × {a.launch_runs}")
                    bench("launch", *common, "--out", dest, "--runs", a.launch_runs)
                for inst in filter(None, a.instruments.split(",")):
                    log(f"{app}: journey {inst} × {a.journey_runs}")
                    bench("journey", *common, "--instrument", inst, "--out", dest, "--runs", a.journey_runs)
                subprocess.run(["xcrun", "devicectl", "device", "uninstall", "app", "--device", a.udid, bundle], capture_output=True)
                log(f"{app}: extracting")
                subprocess.run([sys.executable, str(ROOT / "tools" / "extract.py"), str(dest)], check=True, stdout=subprocess.DEVNULL)
                log(f"{app}: done")
    finally:
        replay.terminate()
    meta = {"udid": a.udid, "rounds": a.rounds, "apps": apps, "finished_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    (out / "run.json").write_text(json.dumps(meta, indent=2))


if __name__ == "__main__":
    main()
