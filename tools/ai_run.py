#!/usr/bin/env python3
"""Runs one AI build per prompt/README.md: prepares a fresh workspace and runs Claude Code headless.

  ai_run.py <app dir name, e.g. react-native> [--runs-root ~/shopbench-runs] [--effort high] [--run-name NAME]
"""
import argparse
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL = "claude-opus-5-5"
MESSAGE = "Read spec/PROMPT.md and follow it."


def framework_values(app_dir):
    for line in (ROOT / "prompt" / "frameworks.md").read_text().splitlines():
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) == 4 and cells[3].strip("`") == f"apps/{app_dir}/":
            return {"FRAMEWORK_NAME": cells[0], "FRAMEWORK_REPO": cells[1], "APP_ID_SUFFIX": cells[2].strip("`")}
    raise SystemExit(f"{app_dir} is not in prompt/frameworks.md")


def summarize(transcript):
    """A headless session emits one `result` per turn it ends (e.g. again after a background task
    finishes); `total_cost_usd` and `duration_api_ms` are cumulative, the other counters are per result."""
    results, tools = [], {}
    for line in Path(transcript).read_text().splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get("type") == "result":
            results.append(event)
        elif event.get("type") == "assistant":
            for c in event["message"].get("content", []):
                if c.get("type") == "tool_use":
                    tools[c["name"]] = tools.get(c["name"], 0) + 1
    usage_keys = ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens")
    return {
        "results": len(results),
        "final_subtype": results[-1].get("subtype") if results else None,
        "is_error": any(r.get("is_error") for r in results),
        "total_cost_usd": results[-1].get("total_cost_usd") if results else None,
        "num_turns": sum(r.get("num_turns") or 0 for r in results),
        "duration_api_ms": results[-1].get("duration_api_ms") if results else None,
        "usage": {k: sum((r.get("usage") or {}).get(k) or 0 for r in results) for k in usage_keys},
        "tool_calls": tools,
        "final_message": results[-1].get("result") if results else None,
    }


def session_id(transcript):
    for line in Path(transcript).read_text().splitlines():
        try:
            sid = json.loads(line).get("session_id")
        except ValueError:
            continue
        if sid:
            return sid
    raise SystemExit(f"no session_id in {transcript}")


def resume(a, workspace):
    """Continues the session in place and records the intervention next to the original run."""
    out = ROOT / "results" / "ai-runs" / a.run_name
    meta = json.loads((out / "run.json").read_text())
    sid = session_id(out / "transcript.jsonl")
    n = len(meta.get("interventions", [])) + 1
    cmd = [c if c != MESSAGE else a.resume_message for c in meta["command"]]
    cmd[cmd.index("-p") + 2 : cmd.index("-p") + 2] = ["--resume", sid]
    transcript = out / f"transcript-resume-{n}.jsonl"
    entry = {"message": a.resume_message, "sent_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "transcript": transcript.name}
    start = time.monotonic()
    with open(transcript, "w") as f:
        code = subprocess.run(cmd, cwd=workspace, stdout=f, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL).returncode
    entry.update({"ended_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "wall_seconds": round(time.monotonic() - start, 1), "exit_code": code, "result": summarize(transcript)})
    meta.setdefault("interventions", []).append(entry)
    (out / "run.json").write_text(json.dumps(meta, indent=2))
    print(json.dumps(entry, indent=2))
    sys.exit(code)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("app_dir")
    p.add_argument("--runs-root", default=str(Path.home() / "shopbench-runs"))
    p.add_argument("--effort", default="high")
    p.add_argument("--resume-message", help="continue the recorded session with this human message (counts as an intervention)")
    p.add_argument("--run-name", help="workspace and results/ai-runs/ directory name for a repeat run (default: app dir)")
    a = p.parse_args()
    a.run_name = a.run_name or a.app_dir

    values = framework_values(a.app_dir)
    workspace = Path(a.runs_root) / a.run_name
    if a.resume_message:
        resume(a, workspace)
        return
    if workspace.exists():
        raise SystemExit(f"{workspace} already exists; every run needs a fresh directory")
    spec = workspace / "spec"
    spec.mkdir(parents=True)
    prompt = (ROOT / "prompt" / "PROMPT.md").read_text()
    for k, v in values.items():
        prompt = prompt.replace("{{" + k + "}}", v)
    if re.search(r"\{\{[A-Z_]+\}\}", prompt):
        raise SystemExit("unsubstituted placeholder in PROMPT.md")
    (spec / "PROMPT.md").write_text(prompt)
    shutil.copy2(ROOT / "prompt" / "storefront.graphql", spec)
    shutil.copytree(ROOT / "design", spec / "design")

    out = ROOT / "results" / "ai-runs" / a.run_name
    if (out / "run.json").exists():
        raise SystemExit(f"{out} already holds a run; pass a new --run-name")
    out.mkdir(parents=True, exist_ok=True)
    cmd = [
        "claude", "-p", MESSAGE,
        "--model", MODEL,
        "--effort", a.effort,
        "--permission-mode", "bypassPermissions",
        "--setting-sources", "project",
        "--strict-mcp-config",
        "--disable-slash-commands",
        "--output-format", "stream-json",
        "--verbose",
    ]
    meta = {
        "app_dir": a.app_dir,
        "run_name": a.run_name,
        "workspace": str(workspace),
        "command": cmd,
        "claude_version": subprocess.run(["claude", "--version"], capture_output=True, text=True).stdout.strip(),
        "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    (out / "run.json").write_text(json.dumps(meta, indent=2))
    start = time.monotonic()
    with open(out / "transcript.jsonl", "w") as transcript:
        code = subprocess.run(cmd, cwd=workspace, stdout=transcript, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL).returncode
    meta.update(
        {
            "ended_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "wall_seconds": round(time.monotonic() - start, 1),
            "exit_code": code,
        }
    )
    meta["result"] = summarize(out / "transcript.jsonl")
    (out / "run.json").write_text(json.dumps(meta, indent=2))
    print(json.dumps(meta, indent=2))
    sys.exit(code)


if __name__ == "__main__":
    main()
