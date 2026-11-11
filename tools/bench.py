#!/usr/bin/env python3
"""Drives the measurements in measurement/README.md on a connected iPhone.

  bench.py size    --app PATH.app [--thinning-report PATH] --out DIR
  bench.py prepare --app PATH.app --bundle-id ID --udid UDID --api URL
  bench.py launch  --bundle-id ID --udid UDID --api URL --out DIR [--runs 10]
  bench.py journey --bundle-id ID --udid UDID --api URL --instrument {activity,hitches,power} --out DIR [--runs 3]

The replay server (tools/replay/replay.py serve) must be reachable at --api from both the Mac and the device.
`prepare` installs the app and lets the runner answer the Local Network prompt; run it before `launch` and `journey`.
Metrics are extracted from the traces by tools/extract.py.
"""
import argparse
import json
import os
import shutil
import signal
import subprocess
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "tools" / "runner"
TEMPLATES = {"activity": "Activity Monitor", "hitches": "Animation Hitches", "power": "Power Profiler"}


def run(cmd, timeout=600, env=None, log=None):
    r = subprocess.run([str(c) for c in cmd], capture_output=True, text=True, timeout=timeout, env=env)
    if log:
        Path(log).write_text(r.stdout + r.stderr)
    if r.returncode:
        raise RuntimeError(f"{' '.join(map(str, cmd))} failed ({r.returncode}):\n{r.stderr[-2000:]}")
    return r.stdout


def replay(api, path, method="GET"):
    base = api.rsplit("/api", 1)[0]
    req = urllib.request.Request(base + path, method=method, data=b"" if method == "POST" else None)
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read())


def dir_bytes(path):
    path = Path(path)
    return sum(f.stat().st_size for f in path.rglob("*") if f.is_file() and not f.is_symlink())


def device_info(udid):
    out = Path(os.environ.get("TMPDIR", "/tmp")) / f"shopbench-device-{udid}.json"
    run(["xcrun", "devicectl", "device", "info", "details", "--device", udid, "--json-output", out])
    return json.loads(out.read_text()).get("result", {})


def write_json(path, value):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(value, indent=2))


def cmd_size(a):
    result = {"app": str(a.app), "app_bytes": dir_bytes(a.app)}
    if a.thinning_report:
        result["thinning_report"] = Path(a.thinning_report).read_text()
    write_json(Path(a.out) / "size.json", result)
    print(json.dumps({k: v for k, v in result.items() if k != "thinning_report"}))


def cmd_launch(a):
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    write_json(out / "device.json", device_info(a.udid))
    replay(a.api, "/_reset", "POST")
    for n in range(a.runs + 1):
        trace = out / ("launch-warmup.trace" if n == 0 else f"launch-{n}.trace")
        time.sleep(5)
        run(
            [
                "xcrun", "xctrace", "record",
                "--device", a.udid,
                "--template", "App Launch",
                "--instrument", "os_log",
                "--time-limit", f"{a.seconds}s",
                "--env", f"SHOP_API_URL={a.api}",
                "--output", trace,
                "--launch", "--", a.launch_target or a.bundle_id,
            ],
            timeout=a.seconds + 120,
            log=trace.with_suffix(".log"),
        )
        print(f"launch {n}/{a.runs}: {trace.name}", flush=True)
    stats = replay(a.api, "/_stats")
    write_json(out / "replay-stats.json", stats)
    if stats["misses"]:
        raise SystemExit(f"replay misses, run invalid: {stats['misses'][:5]}")


def xctestrun():
    """The built xctestrun with screenshots instead of screen recording, so recording adds no load."""
    products = RUNNER / "build" / "device" / "Build" / "Products"
    found = sorted(products.glob("ShopBenchRunner_iphoneos*.xctestrun"))
    if not found:
        raise SystemExit("Build the runner first: see tools/README.md")
    measure = products / "measure.xctestrun"
    if not measure.exists() or measure.stat().st_mtime < found[-1].stat().st_mtime:
        shutil.copy2(found[-1], measure)
        run(["plutil", "-replace", "ShopBenchUITests.PreferredScreenCaptureFormat", "-string", "screenshots", measure])
    return measure


def run_test(a, test, result, log, timeout):
    env = {**os.environ, "TEST_RUNNER_SHOP_BUNDLE_ID": a.bundle_id, "TEST_RUNNER_SHOP_API_URL": a.api}
    run(
        [
            "xcodebuild", "test-without-building",
            "-xctestrun", xctestrun(),
            "-destination", f"id={a.udid}",
            f"-only-testing:ShopBenchUITests/JourneyTests/{test}",
            "-resultBundlePath", result,
        ],
        timeout=timeout,
        env=env,
        log=log,
    )


def cmd_prepare(a):
    subprocess.run(["xcrun", "devicectl", "device", "uninstall", "app", "--device", a.udid, a.bundle_id], capture_output=True)
    run(["xcrun", "devicectl", "device", "install", "app", "--device", a.udid, a.app])
    tmp = Path(os.environ.get("TMPDIR", "/tmp")) / f"shopbench-prepare-{os.getpid()}"
    run_test(a, "testPrepare", tmp / "prepare.xcresult", None, 300)
    shutil.rmtree(tmp, ignore_errors=True)
    print(f"prepared {a.bundle_id}", flush=True)


def cmd_journey(a):
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    write_json(out / "device.json", device_info(a.udid))
    for n in range(1, a.runs + 1):
        trial = out / f"{a.instrument}-{n}"
        trial.mkdir(exist_ok=True)
        replay(a.api, "/_reset", "POST")
        trace_log = open(trial / "xctrace.log", "w")
        recorder = subprocess.Popen(
            [
                "xcrun", "xctrace", "record",
                "--device", a.udid,
                "--template", TEMPLATES[a.instrument],
                "--instrument", "os_log",
                "--all-processes",
                "--output", trial / "journey.trace",
            ],
            stdout=trace_log,
            stderr=subprocess.STDOUT,
        )
        try:
            time.sleep(5)
            run_test(a, "testJourney", trial / "runner.xcresult", trial / "runner.log", 900)
        finally:
            recorder.send_signal(signal.SIGINT)
            recorder.wait(timeout=600)
            trace_log.close()
        stats = replay(a.api, "/_stats")
        write_json(trial / "replay-stats.json", stats)
        if stats["misses"]:
            raise SystemExit(f"replay misses, run invalid: {stats['misses'][:5]}")
        print(f"journey {a.instrument} {n}/{a.runs}: {stats['requests']} requests, {stats['bytes']} bytes", flush=True)
        time.sleep(a.cooldown)


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("size")
    s.add_argument("--app", required=True)
    s.add_argument("--thinning-report")
    s.add_argument("--out", required=True)
    for name in ("prepare", "launch", "journey"):
        s = sub.add_parser(name)
        s.add_argument("--bundle-id", required=True)
        s.add_argument("--udid", required=True)
        s.add_argument("--api", required=True, help="replay server endpoint, e.g. http://192.168.1.20:8787/api")
        if name == "prepare":
            s.add_argument("--app", required=True)
            continue
        s.add_argument("--out", required=True)
        if name == "launch":
            s.add_argument("--runs", type=int, default=10)
            s.add_argument("--seconds", type=int, default=10)
            s.add_argument("--launch-target", help="what xctrace --launch receives; defaults to the bundle id")
        else:
            s.add_argument("--instrument", choices=TEMPLATES, required=True)
            s.add_argument("--runs", type=int, default=3)
            s.add_argument("--cooldown", type=int, default=60)
    a = p.parse_args()
    {"size": cmd_size, "prepare": cmd_prepare, "launch": cmd_launch, "journey": cmd_journey}[a.cmd](a)


if __name__ == "__main__":
    main()
