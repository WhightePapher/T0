"""帧耗时采集：`flutter build web --profile` + headless chromium + `window.__t0perf`。

一条命令重跑全部四场景（仓库根目录）：

    export PATH=/data/flutter/bin:$PATH
    python3 tool/measure_fps.py                 # 构建 + 跑 cold/theme/works/dialog，各 3 次
    python3 tool/measure_fps.py --no-build      # 直接用现有 build/web
    python3 tool/measure_fps.py --label after   # 结果写到 docs/帧耗时_after.json

为什么在 Web 上量：线上就是这个构建；桌面 `--perf=` 要 GUI 会话，沙箱没有显示栈。
口径（doc 里必须写同一句）：`SchedulerBinding.addTimingsCallback` 的 FrameTiming
在 web 引擎上不回调（结果 JSON 里 `frame_timing.supported=false`），本表两列并排：
`FrameTiming`（引擎上报的 build / raster）与 `requestAnimationFrame` 帧间隔（等效 FPS、
掉帧计数）。两套各自成列，不互相换算。
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
import urllib.request

from websockets.sync.client import connect

ROOT = os.environ.get("T0_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "docs")
PORT_HTTP = 8141
PORT_CDP = 9347
VIEW = (1440, 900)
VIEW_OVERRIDE: tuple[int, int] | None = None
SCENARIOS = ("cold", "theme", "works", "dialog")
FAMILIES = {
    "theme": ("theme",),
    "works": ("works.module", "works.edit", "works.compare"),
    "dialog": ("dialog.open", "dialog.close"),
}

_nonce = [0]


class CDP:
    def __init__(self, ws_url: str) -> None:
        self.ws = connect(ws_url, max_size=None, open_timeout=30)
        self.next_id = 0

    def call(self, method: str, **params):
        self.next_id += 1
        mid = self.next_id
        self.ws.send(json.dumps({"id": mid, "method": method, "params": params}))
        while True:
            msg = json.loads(self.ws.recv(timeout=60))
            if msg.get("id") == mid:
                if "error" in msg:
                    raise RuntimeError(f"{method}: {msg['error']}")
                return msg.get("result", {})

    def eval(self, expression: str):
        res = self.call("Runtime.evaluate", expression=expression, returnByValue=True, awaitPromise=False)
        return (res.get("result") or {}).get("value")


def start_http() -> subprocess.Popen:
    proc = subprocess.Popen(
        [sys.executable, "-m", "http.server", str(PORT_HTTP), "--bind", "127.0.0.1"],
        cwd=os.path.join(ROOT, "build", "web"),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    for _ in range(100):
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{PORT_HTTP}/index.html", timeout=1) as r:
                if r.status == 200:
                    return proc
        except Exception:
            time.sleep(0.1)
    proc.kill()
    raise SystemExit("静态服务没起来（build/web 里没有 index.html？先 flutter build web --profile）")


def find_chromium() -> str:
    for name in ("chromium", "chromium-browser", "google-chrome", "chrome"):
        path = shutil.which(name)
        if path:
            return path
    raise SystemExit("找不到 chromium")


def start_chrome() -> subprocess.Popen:
    global VIEW
    profile = os.path.join(tempfile.gettempdir(), "t0-fps-chrome")
    shutil.rmtree(profile, ignore_errors=True)
    proc = subprocess.Popen(
        [
            find_chromium(),
            "--headless=new",
            f"--remote-debugging-port={PORT_CDP}",
            f"--user-data-dir={profile}",
            f"--window-size={VIEW[0]},{VIEW[1]}",
            "--force-device-scale-factor=1",
            "--hide-scrollbars",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-extensions",
            "--disable-features=Translate",
            "--mute-audio",
            "--no-sandbox",
            "about:blank",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    for _ in range(200):
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{PORT_CDP}/json/version", timeout=1) as r:
                json.load(r)
            return proc
        except Exception:
            time.sleep(0.2)
    proc.kill()
    raise SystemExit("chromium 调试端口没起来")


def open_target() -> CDP:
    with urllib.request.urlopen(f"http://127.0.0.1:{PORT_CDP}/json/list", timeout=5) as r:
        targets = json.load(r)
    page = next(t for t in targets if t.get("type") == "page")
    cdp = CDP(page["webSocketDebuggerUrl"])
    cdp.call("Page.enable")
    cdp.call("Runtime.enable")
    cdp.call(
        "Emulation.setDeviceMetricsOverride",
        width=VIEW[0],
        height=VIEW[1],
        deviceScaleFactor=1,
        mobile=False,
    )
    return cdp


def run_once(cdp: CDP, scenario: str, timeout: float = 240.0) -> dict:
    _nonce[0] += 1
    url = f"http://127.0.0.1:{PORT_HTTP}/index.html?perf={scenario}&n={_nonce[0]}"
    cdp.call("Page.navigate", url=url)
    deadline = time.time() + timeout
    while time.time() < deadline:
        raw = cdp.eval("window.__t0perf || null")
        if isinstance(raw, str):
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                data = None
            if data and data.get("scenario") == scenario:
                return data
        time.sleep(0.25)
    raise SystemExit(f"场景 {scenario} 在 {timeout:.0f}s 内没有产出 window.__t0perf")


def pct(values: list[float], p: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    idx = round((len(ordered) - 1) * p)
    return ordered[min(max(idx, 0), len(ordered) - 1)]


def pool(runs: list[dict], families: tuple[str, ...]) -> dict:
    intervals: list[float] = []
    builds: list[float] = []
    rasters: list[float] = []
    for run in runs:
        for window in run["windows"]:
            if window["name"].split("#")[0] in families:
                intervals.extend(window.get("intervals") or [])
                builds.extend(window.get("build_samples") or [])
                rasters.extend(window.get("raster_samples") or [])
    p50 = pct(intervals, 0.50)
    return {
        "frames": len(intervals),
        "p50": p50,
        "p95": pct(intervals, 0.95),
        "max": max(intervals) if intervals else 0.0,
        "fps_p50": 1000.0 / p50 if p50 > 0 else 0.0,
        "dropped_over_33ms": sum(1 for v in intervals if v > 33),
        "over_50ms": sum(1 for v in intervals if v >= 50),
        "frame_timing_samples": len(builds),
        "build_p50": pct(builds, 0.50),
        "build_p95": pct(builds, 0.95),
        "build_max": max(builds) if builds else 0.0,
        "raster_p50": pct(rasters, 0.50),
        "raster_p95": pct(rasters, 0.95),
        "raster_max": max(rasters) if rasters else 0.0,
    }


def machine_info() -> dict:
    cpu = ""
    try:
        with open("/proc/cpuinfo", encoding="utf-8") as fh:
            for line in fh:
                if line.startswith("model name"):
                    cpu = line.split(":", 1)[1].strip()
                    break
    except OSError:
        cpu = platform.processor()
    try:
        chromium = subprocess.run([find_chromium(), "--version"], capture_output=True, text=True, timeout=30).stdout.strip()
    except Exception:
        chromium = "unknown"
    try:
        env = dict(os.environ)
        env["PATH"] = "/data/flutter/bin:" + env.get("PATH", "")
        flutter = subprocess.run(["flutter", "--version"], capture_output=True, text=True, timeout=120, env=env).stdout.splitlines()[0]
    except Exception:
        flutter = "unknown"
    return {"cpu": cpu, "cores": os.cpu_count(), "chromium": chromium, "flutter": flutter, "viewport": list(VIEW)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-build", action="store_true", help="跳过 flutter build web --profile")
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--label", default="current", help="结果文件名后缀：docs/帧耗时_<label>.json")
    parser.add_argument("--scenarios", default=",".join(SCENARIOS))
    parser.add_argument("--view", default="", help="WxH，默认 1440x900；480x900 这类小视口用来验证是不是填充率瓶颈")
    args = parser.parse_args()

    global VIEW
    if args.view:
        width, height = (int(v) for v in args.view.lower().split("x"))
        VIEW = (width, height)

    if not args.no_build:
        print("== flutter build web --profile")
        subprocess.run(
            ["flutter", "build", "web", "--profile"],
            cwd=ROOT,
            check=True,
            env={**os.environ, "PATH": "/data/flutter/bin:" + os.environ.get("PATH", "")},
        )

    http = start_http()
    chrome = start_chrome()
    try:
        cdp = open_target()
        results: dict[str, list[dict]] = {name: [] for name in args.scenarios.split(",")}
        for run in range(args.runs):
            for name in results:
                print(f"== run {run + 1}/{args.runs}: {name}")
                results[name].append(run_once(cdp, name))
    finally:
        chrome.kill()
        http.kill()

    summary: dict = {
        "machine": machine_info(),
        "build_mode": "flutter build web --profile",
        "metric": "requestAnimationFrame frame interval (FrameTiming not reported on web)",
        "runs": args.runs,
        "scenarios": {},
    }
    for name, runs in results.items():
        entry: dict = {
            "cold_start_ms_runs": [r.get("cold_start_ms") for r in runs],
            "cold_start_ms_median": statistics.median(
                [r["cold_start_ms"] for r in runs if r.get("cold_start_ms") is not None] or [0]
            ),
            "frame_timing_supported": any(r["frame_timing"]["supported"] for r in runs),
            "raf_samples": [r["raf_samples"] for r in runs],
        }
        for family, prefixes in FAMILIES.items():
            entry[family] = pool(runs, prefixes)
        summary["scenarios"][name] = entry

    print()
    head = (f"{'场景':<14}{'帧数':>6}{'间隔p50':>9}{'间隔p95':>9}{'间隔max':>9}"
            f"{'>33ms':>7}{'≥50ms':>7}{'build p95':>10}{'raster p95':>11}{'raster max':>11}")
    print(head)
    print("-" * len(head))
    for name, entry in summary["scenarios"].items():
        if name == "cold":
            print(f"{'冷启动(ms)':<12}{'-':>6}{'-':>9}{'-':>9}{entry['cold_start_ms_median']:>9.0f}")
            continue
        for family in FAMILIES:
            row = entry[family]
            if row["frames"] == 0:
                continue
            print(
                f"{family:<16}{row['frames']:>6}{row['p50']:>9.2f}{row['p95']:>9.2f}"
                f"{row['max']:>9.2f}{row['dropped_over_33ms']:>7}{row['over_50ms']:>7}"
                f"{row['build_p95']:>10.2f}{row['raster_p95']:>11.2f}{row['raster_max']:>11.2f}"
            )

    summary["machine"]["viewport"] = list(VIEW)
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, f"帧耗时_{args.label}.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(summary, fh, ensure_ascii=False, indent=2)
    print(f"\n写入 {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
