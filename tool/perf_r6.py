"""r6 主题切换帧耗时采集：跑 A/B/C/D/E/soak 场景，每组跑 N 次取中位数。

为什么不是点鼠标：这台机器上顶栏按钮经常被别的窗口压住（见 tool/shoot_windows_exe.py
的注释），合成点击不稳。应用自身支持 `--perf=A|B|C|D|E|soak`（lib/main.dart 的
_runPerfScenario），走的是同一套 ThemeController.toggle()，统计口径一致：
每次切换后 420ms 内的真实 FrameTiming（build / raster 分开），同时记 Element 数与 RSS。

为什么重复跑：一个 420ms 窗口里只有 1~9 帧，p95 很容易被一帧抖动带跑
（别的窗口压上来、GPU 降频），单次结果不能当结论。

用法（仓库根目录）：
    flutter build windows --debug
    python tool/perf_r6.py before 3      # 写到 docs/perf_r6/before_*.log
    python tool/perf_r6.py after 3
环境变量 T0_PERF_EXE 可指向别的产物（例如 release exe）复核。
"""

from __future__ import annotations

import os
import pathlib
import re
import statistics
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_EXE = ROOT / "build" / "windows" / "x64" / "runner" / "Debug" / "lab5_crossplatformvisualdesignpractice.exe"
OUT_DIR = ROOT / "docs" / "perf_r6"
SCENARIOS = ["A", "B", "C", "D", "E", "soak"]
TIMEOUT_S = 240
SWITCH_RE = re.compile(
    r"SWITCH (?P<label>.+?) to=(?P<to>\w+) frames=(?P<frames>\d+) "
    r"build_p50=(?P<bp50>[\d.]+) build_p95=(?P<bp95>[\d.]+) "
    r"raster_p50=(?P<rp50>[\d.]+) raster_p95=(?P<rp95>[\d.]+) "
    r"elements=(?P<elements>\d+) rss_mb=(?P<rss>[\d.]+)"
)


def run(tag: str, scenario: str, rep: int, exe: pathlib.Path) -> str:
    log = OUT_DIR / f"{tag}_{scenario}_{rep}.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    if log.exists():
        log.unlink()
    env = dict(os.environ)
    env["T0_PERF_LOG"] = str(log)
    proc = subprocess.Popen([str(exe), "--route=/workspace", f"--perf={scenario}"], env=env)
    deadline = time.time() + TIMEOUT_S
    try:
        while time.time() < deadline:
            if log.exists() and "DONE" in log.read_text(encoding="utf-8", errors="ignore"):
                break
            if proc.poll() is not None:
                break
            time.sleep(0.4)
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
    return log.read_text(encoding="utf-8", errors="ignore") if log.exists() else ""


def median(values: list[float] | list[int]) -> float:
    return round(statistics.median(values), 1) if values else 0.0


def main() -> int:
    tag = sys.argv[1] if len(sys.argv) > 1 else "run"
    reps = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    scenarios = sys.argv[3].split(",") if len(sys.argv) > 3 else SCENARIOS
    exe = pathlib.Path(os.environ.get("T0_PERF_EXE", str(DEFAULT_EXE)))
    if not exe.exists():
        print(f"找不到 exe: {exe}")
        return 2

    summary: dict[str, list[dict[str, str]]] = {}
    for scenario in scenarios:
        rows: list[dict[str, str]] = []
        for rep in range(1, reps + 1):
            text = run(tag, scenario, rep, exe)
            matches = [m.groupdict() for m in SWITCH_RE.finditer(text)]
            if scenario == "soak":
                # soak 一次跑 20 次切换，全部收集起来看趋势
                rows.extend(matches)
            else:
                rows.extend(matches[-1:])
        summary[scenario] = rows

    print(f"\n===== {tag} / {exe.name} / reps={reps} =====")
    for scenario, rows in summary.items():
        if not rows:
            print(f"{scenario}: 无数据")
            continue
        bp95 = [float(r["bp95"]) for r in rows]
        rp95 = [float(r["rp95"]) for r in rows]
        bp50 = [float(r["bp50"]) for r in rows]
        rp50 = [float(r["rp50"]) for r in rows]
        frames = [int(r["frames"]) for r in rows]
        elements = [int(r["elements"]) for r in rows]
        rss = [float(r["rss"]) for r in rows]
        print(
            f"{scenario:5s} n={len(rows):2d} frames~{median(frames):.0f} "
            f"build p50={median(bp50):6.1f} p95={median(bp95):6.1f} | "
            f"raster p50={median(rp50):5.1f} p95={median(rp95):5.1f} | "
            f"elements={median(elements):.0f} rss={median(rss):.0f}MB"
        )
        if scenario == "soak":
            quarter = max(1, len(rows) // 4)
            first, last = rows[:quarter], rows[-quarter:]
            print(
                f"      soak 前 {len(first)} 次 raster p95={median([float(r['rp95']) for r in first])} "
                f"build p95={median([float(r['bp95']) for r in first])} | "
                f"后 {len(last)} 次 raster p95={median([float(r['rp95']) for r in last])} "
                f"build p95={median([float(r['bp95']) for r in last])}"
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
