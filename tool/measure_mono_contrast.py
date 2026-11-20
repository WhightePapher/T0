"""在渲染出来的深色截图里实测小字对比度（不只看设计稿上的理论值）。

做法：给一块只含文字的矩形，取该区域出现最多的颜色当底，再取亮度最高的几个像素
的均值当「笔画核心色」（12px 字在 DPR 1 下会有抗锯齿过渡，取最亮的核心像素才代表设计色），
按 WCAG 相对亮度公式算比值。

用法：
    python tool/measure_contrast.py            # 用内置的 regions 量 screenshots_v5 + v4 基线
    python tool/measure_contrast.py --json     # 输出 JSON
"""

from __future__ import annotations

import argparse
import json
import os
from collections import Counter

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V5 = os.path.join(ROOT, "docs", "screenshots_v5")
V4 = os.path.join(ROOT, "docs", "screenshots_v4")


def channel(v: float) -> float:
    v /= 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def luminance(rgb: tuple[int, int, int]) -> float:
    r, g, b = rgb
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def contrast(fg: tuple[int, int, int], bg: tuple[int, int, int]) -> float:
    a, b = luminance(fg), luminance(bg)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def measure(path: str, box: tuple[int, int, int, int]) -> dict:
    im = Image.open(path).convert("RGB")
    x1, y1, x2, y2 = box
    pixels = [im.getpixel((x, y)) for x in range(x1, x2) for y in range(y1, y2)]
    bg = Counter(pixels).most_common(1)[0][0]
    ranked = sorted(pixels, key=luminance, reverse=True)
    # 12px/10px 的小字在 DPR 1 下笔画不满一像素，取「最实的那一个像素」代表设计色，
    # 再用最亮 2% 的均值做抗锯齿参考（后者必然更低，只作对照）
    core = ranked[0]
    core_set = ranked[: max(3, len(ranked) // 50)]
    avg = tuple(round(sum(c[i] for c in core_set) / len(core_set)) for i in range(3))
    return {
        "box": list(box),
        "bg": "#%02X%02X%02X" % bg,
        "core": "#%02X%02X%02X" % core,
        "avg2pct": "#%02X%02X%02X" % avg,
        "ratio": round(contrast(core, bg), 2),
        "avg_ratio": round(contrast(avg, bg), 2),
        "theoretical_ratio": None,
    }


def theory(fg: str, bg: str) -> float:
    def parse(h: str) -> tuple[int, int, int]:
        h = h.lstrip("#")
        return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

    return round(contrast(parse(fg), parse(bg)), 2)


REGIONS = [
    # (说明, 目录, 文件名, 矩形, (设计前景, 设计背景))
    ("workbench · WORKBENCH · 04 小标（eyebrow / muted, on bg）", V5, "workbench_dark.png",
     (125, 165, 272, 181), ("#B8ADC4", "#2E2536")),
    ("workbench · 三步卡 01/02/03 序号（mono / muted, on surface）", V5, "workbench_dark.png",
     (1033, 515, 1052, 626), ("#B8ADC4", "#3A2F44")),
    ("workbench · 产品流程 标签（label / muted, on surface）", V5, "workbench_dark.png",
     (1033, 443, 1083, 458), ("#B8ADC4", "#3A2F44")),
    ("workspace · 左栏模块序号 01~05（mono / muted, on surface）", V5, "workspace_dark.png",
     (20, 265, 36, 546), ("#B8ADC4", "#3A2F44")),
    ("workspace · to copilot 标签（mono / ink2，本就不受影响）", V5, "workspace_dark.png",
     (1098, 200, 1166, 218), ("#C6BACE", "#2E2536")),
]

BASELINE = [
    # 改前基线：screenshots_v4（main @205da09，muted = #9C8FA9；文件名是那一批的）
    ("workbench · WORKBENCH · 04 小标（改前）", "02_dark_工作台.png", (125, 165, 272, 181),
     "#9C8FA9", "#2E2536"),
    ("workbench · 三步卡 01/02/03 序号（改前）", "02_dark_工作台.png", (1033, 515, 1052, 626),
     "#9C8FA9", "#3A2F44"),
    ("workbench · 产品流程 标签（改前）", "02_dark_工作台.png", (1033, 443, 1083, 458),
     "#9C8FA9", "#3A2F44"),
    ("workspace · 左栏模块序号 01~05（改前）", "04_dark_模块工作区.png", (20, 265, 36, 546),
     "#9C8FA9", "#3A2F44"),
]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    rows = []

    def add(label: str, path: str, box, fg: str, bg: str) -> None:
        if not os.path.exists(path):
            return
        m = measure(path, box)
        m["theoretical_ratio"] = theory(fg, bg)
        m["theoretical_fg"] = fg
        m["label"] = label
        rows.append(m)

    for label, root, name, box, (fg, bg) in REGIONS:
        add(label, os.path.join(root, name), box, fg, bg)

    for label, name, box, fg, bg in BASELINE:
        add(label, os.path.join(V4, name), box, fg, bg)

    if args.json:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
        return
    w = max(len(r["label"]) for r in rows)
    print(f"{'区域'.ljust(w)}  笔画核心 / 底            核心   2%均值  理论")
    for r in rows:
        print(
            f"{r['label'].ljust(w)}  {r['core']} / {r['bg']}   "
            f"{r['ratio']:>5.2f}  {r['avg_ratio']:>5.2f}  {r['theoretical_ratio']:>5.2f}"
        )


if __name__ == "__main__":
    main()
