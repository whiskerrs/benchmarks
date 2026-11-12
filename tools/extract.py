#!/usr/bin/env python3
"""Extracts the metrics in measurement/README.md from the traces bench.py records.

  extract.py <result dir written by bench.py>   # writes metrics.json there and prints it
  extract.py --summary <dir with one result dir per app>

Phase boundaries come from the runner's `SHOPBENCH_RUNNER begin|end <phase>` os_log lines and the
app's `SHOPBENCH home_ready` line, both recorded in the same trace as the metrics.
"""
import argparse
import json
import re
import statistics
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

SCROLL = re.compile(r"^scroll-")
NAV = re.compile(r"^product-\d+$")


def table(trace, schema):
    """Rows of one table as dicts of mnemonic -> (raw text, fmt), resolving xctrace's id/ref sharing."""
    with tempfile.NamedTemporaryFile(suffix=".xml") as f:
        subprocess.run(
            ["xcrun", "xctrace", "export", "--input", str(trace), "--output", f.name,
             "--xpath", f'/trace-toc/run[@number="1"]/data/table[@schema="{schema}"]'],
            check=True, capture_output=True,
        )
        cols, ids, rows = [], {}, []
        for event, el in ET.iterparse(f.name, events=("end",)):
            if el.tag == "mnemonic":
                cols.append(el.text)
            elif el.tag == "row":
                row = {}
                for col, cell in zip(cols, el):
                    row[col] = resolve(cell, ids)
                rows.append(row)
                el.clear()
            elif "id" in el.attrib:
                ids[el.attrib["id"]] = (el.text, el.attrib.get("fmt"), [resolve(c, ids) for c in el])
        return rows


def resolve(el, ids):
    if "ref" in el.attrib:
        return ids[el.attrib["ref"]]
    return (el.text, el.attrib.get("fmt"), [])


def num(cell):
    return float(cell[0]) if cell and cell[0] not in (None, "") else None


def pid_of(cell):
    """Process cells hold a nested <pid>; the fmt reads 'Name (1234)'."""
    m = re.search(r"\((\d+)\)\s*$", cell[1] or "")
    return int(m.group(1)) if m else None


def marks(trace):
    """(time ns, pid, message) for every SHOPBENCH log line, in time order."""
    out = []
    for r in table(trace, "os-log"):
        msg = (r.get("message") or (None, None, []))[1] or ""
        if "SHOPBENCH" in msg:
            out.append((num(r["time"]), pid_of(r["process"]), msg))
    return sorted(out)


def phases(log):
    begin, out = {}, {}
    for t, _, msg in log:
        m = re.search(r"SHOPBENCH_RUNNER (begin|end) (\S+)", msg)
        if m and m.group(1) == "begin":
            begin[m.group(2)] = t
        elif m and m.group(2) in begin:
            out[m.group(2)] = (begin[m.group(2)], t)
    return out


def app_pid(log, start, live=None):
    """The app's pid: from its home_ready line, or, since the os_log stream drops lines under the
    runner's accessibility traffic, the largest process that first appears after the launch began."""
    ready = [p for t, p, msg in log if "SHOPBENCH home_ready" in msg and t >= start]
    if ready:
        return ready[0]
    if live is None:
        raise SystemExit("no SHOPBENCH home_ready after the journey started")
    first, peak = {}, {}
    for r in live:
        pid, t, mem = pid_of(r["process"]), num(r["start"]), num(r["memory-physical-footprint"]) or 0
        first[pid] = min(first.get(pid, t), t)
        peak[pid] = max(peak.get(pid, 0), mem)
    fresh = [p for p in peak if first[p] >= start - 2e9]
    if not fresh:
        raise SystemExit("no process started with the journey")
    return max(fresh, key=peak.get)


def thermal(trace):
    return sorted({(r.get("thermal-state") or r.get("state") or (None, "?", []))[1] for r in table(trace, "device-thermal-state-intervals")})


def journey_activity(trace):
    log = marks(trace)
    ph = phases(log)
    live = table(trace, "activity-monitor-process-live")
    pid = app_pid(log, ph["launch"][0], live)
    samples = sorted(
        (num(r["start"]), num(r["memory-physical-footprint"]), num(r["cpu-total"]))
        for r in live
        if pid_of(r["process"]) == pid
    )
    if not samples:
        raise SystemExit(f"no activity samples for pid {pid}")

    def at(t):
        return min(samples, key=lambda s: abs(s[0] - t))

    start, end = ph["launch"][0], ph["idle-after-journey"][1]
    within = [s for s in samples if start <= s[0] <= end]
    scroll_pct, peaks = [], []
    for name, (b, e) in ph.items():
        if not SCROLL.match(name):
            continue
        part = [s for s in samples if b <= s[0] <= e]
        if len(part) >= 2:
            scroll_pct.append((part[-1][2] - part[0][2]) / (part[-1][0] - part[0][0]) * 100)
            peaks += [(y[2] - x[2]) / (y[0] - x[0]) * 100 for x, y in zip(part, part[1:]) if y[0] > x[0]]
    return {
        "pid": pid,
        "M1_mb": at(ph["idle-after-launch"][1])[1] / 2**20,
        "M2_mb": max(s[1] for s in within) / 2**20,
        "M3_mb": at(ph["idle-after-journey"][1])[1] / 2**20,
        "C1_s": (within[-1][2] - within[0][2]) / 1e9,
        "C2_avg_pct": statistics.mean(scroll_pct) if scroll_pct else None,
        "C2_peak_pct": max(peaks) if peaks else None,
        "phase_s": {k: (e - b) / 1e9 for k, (b, e) in ph.items()},
        "thermal": thermal(trace),
    }


def journey_hitches(trace):
    """The app's hitches are those charged to a process other than SpringBoard; system rows have none."""
    ph = phases(marks(trace))
    hitches = [
        (num(r["start"]), num(r["duration"]))
        for r in table(trace, "hitches")
        if r.get("process") and r["process"][1] and not r["process"][1].startswith("SpringBoard")
    ]

    def rate(pattern):
        spans = [v for k, v in ph.items() if pattern.match(k)]
        secs = sum(e - b for b, e in spans) / 1e9
        hit = [d for t, d in hitches if any(b <= t <= e for b, e in spans)]
        return sum(hit) / 1e6 / secs if secs else None, len(hit)

    f1, f2 = rate(SCROLL)
    f3, _ = rate(NAV)
    return {"F1_ms_per_s": f1, "F2_count": f2, "F3_ms_per_s": f3, "hitches_total": len(hitches),
            "phase_s": {k: (e - b) / 1e9 for k, (b, e) in ph.items()}}


def journey_power(trace):
    """E1: mean system power (battery %/hour) over the journey, weighted by interval length."""
    ph = phases(marks(trace))
    start, end = ph["launch"][0], ph["idle-after-journey"][1]
    spans = [(num(r["start"]), num(r["duration"]), num(r["power-usage"])) for r in table(trace, "SystemPowerLevel")]
    within = [(d, p) for t, d, p in spans if p is not None and start <= t <= end]
    total = sum(d for d, _ in within)
    # Power usage reads 0 %/hour for as long as the device is charging.
    charging = bool(table(trace, "DeviceChargingState"))
    return {
        "E1_pct_per_hour": sum(d * p for d, p in within) / total if total and not charging else None,
        "charging": charging,
        "thermal": sorted({(r.get("thermal-state") or (None, "?", []))[1] for r in table(trace, "SystemThermalState")}),
    }


def launch(trace):
    periods = table(trace, "life-cycle-period")
    if not periods:
        return None
    pid = pid_of(periods[0]["process"])
    mine = [r for r in periods if pid_of(r["process"]) == pid]
    t0 = min(num(r["start"]) for r in mine)
    frame = [num(r["start"]) + num(r["duration"]) for r in mine if "Initial Frame Rendering" in (r["period"][1] or "")]
    ready = [t for t, p, msg in marks(trace) if p == pid and "SHOPBENCH home_ready" in msg]
    return {
        "pid": pid,
        "L1_ms": (max(frame) - t0) / 1e6 if frame else None,
        "L2_ms": (ready[0] - t0) / 1e6 if ready else None,
    }


def median_iqr(values):
    values = sorted(v for v in values if v is not None)
    if not values:
        return None
    q = statistics.quantiles(values, n=4) if len(values) > 1 else [values[0]] * 3
    return {"median": statistics.median(values), "q1": q[0], "q3": q[2], "n": len(values)}


KEYS = {
    "launch": ["L1_ms", "L2_ms"],
    "activity": ["M1_mb", "M2_mb", "M3_mb", "C1_s", "C2_avg_pct", "C2_peak_pct", "N1_requests", "N1_bytes"],
    "hitches": ["F1_ms_per_s", "F2_count", "F3_ms_per_s"],
    "power": ["E1_pct_per_hour"],
}


def summarize(result):
    return {k: median_iqr(r.get(k) for r in result[kind]) for kind, ks in KEYS.items() for k in ks}


def extract(out):
    out = Path(out)
    result = {"launch": [], "activity": [], "hitches": [], "power": []}
    for t in sorted(out.glob("launch-[0-9]*.trace")):
        result["launch"].append(launch(t) or {"trace": t.name, "error": "no life-cycle periods"})
    for kind, fn in (("activity", journey_activity), ("hitches", journey_hitches), ("power", journey_power)):
        for t in sorted(out.glob(f"{kind}-*/journey.trace")):
            if not re.fullmatch(rf"{kind}-\d+", t.parent.name):
                continue
            if "launch" not in phases(marks(t)):
                # The os_log stream sometimes records nothing for a whole trial.
                result[kind].append({"trace": str(t.relative_to(out)), "error": "no runner phase marks"})
                continue
            m = fn(t)
            stats = t.parent / "replay-stats.json"
            if stats.exists():
                s = json.loads(stats.read_text())
                m["N1_requests"], m["N1_bytes"] = s["requests"], s["bytes"]
            result[kind].append(m)
    result["summary"] = summarize(result)
    size = out / "size.json"
    if size.exists():
        result["summary"]["S2_app_bytes"] = json.loads(size.read_text())["app_bytes"]
    (out / "metrics.json").write_text(json.dumps(result, indent=2))
    return result


def main():
    p = argparse.ArgumentParser()
    p.add_argument("dir")
    p.add_argument("--summary", action="store_true", help="dir holds result dirs per app (optionally under round-*); print a table of medians")
    p.add_argument("--marks", action="store_true", help="dir is one trace; print its SHOPBENCH log lines")
    a = p.parse_args()
    if a.marks:
        for t, pid, msg in marks(a.dir):
            print(t, pid, msg)
        return
    if not a.summary:
        print(json.dumps(extract(a.dir)["summary"], indent=2))
        return
    # Pool every run of an app across round-*/<app>/metrics.json (or <app>/metrics.json) before taking medians.
    pooled = {}
    for m in sorted(Path(a.dir).glob("**/metrics.json")):
        result = json.loads(m.read_text())
        app = pooled.setdefault(m.parent.name, {kind: [] for kind in KEYS} | {"size": None})
        for kind in KEYS:
            app[kind] += result.get(kind, [])
        app["size"] = result["summary"].get("S2_app_bytes", app["size"])
    rows = {}
    for name, app in pooled.items():
        rows[name] = summarize(app)
        if app["size"]:
            rows[name]["S2_app_mb"] = app["size"] / 1e6
    keys = sorted({k for s in rows.values() for k in s})
    print("| metric | " + " | ".join(rows) + " |")
    print("|---|" + "---|" * len(rows))
    for k in keys:
        cells = []
        for s in rows.values():
            v = s.get(k)
            v = v["median"] if isinstance(v, dict) else v
            cells.append("" if v is None else f"{v:.1f}" if isinstance(v, float) else str(v))
        print(f"| {k} | " + " | ".join(cells) + " |")


if __name__ == "__main__":
    main()
