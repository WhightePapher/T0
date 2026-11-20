"""量过渡帧：主按钮（CTA）底色是不是还在绿系里，以及帧里有没有纯黑 / 纯白块。

审图 P1 的现象是「CTA 在 105–120ms 变纯黑、210ms 变纯白」。这个脚本做两件事：

1. 全帧采样（步长 3，和审图同法）统计纯黑 #000000 / 纯白 #FFFFFF 占比；
2. 定位 CTA（浅色落定帧里找面积最大的 accent 绿色块），在每一帧里取它的
   众数色当底色、取与底色亮度差最大的像素当字色，算 WCAG 比值。

用法：
    python tool/measure_transition_fill.py                # 默认量 docs/screenshots_v7
    python tool/measure_transition_fill.py --dir docs/screenshots_v7 --json
"""

from __future__ import annotations

import argparse
import json
import os
from collections import Counter

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_DIR = os.path.join(ROOT, "docs", "screenshots_v7")
FRAMES = [
    ("07_t105.png", "105ms"),
    ("08_t120.png", "120ms"),
    ("09_t210.png", "210ms"),
    ("10_t315.png", "315ms"),
]
LIGHT_REF = os.path.join("..", "screenshots_v5", "workbench_light.png")  # 浅色落定帧：拿它定位 CTA
ACCENT = (0x14, 0x7A, 0x62)


def channel(v: float) -> float:
    v /= 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def luminance(rgb: tuple[int, int, int]) -> float:
    return 0.2126 * channel(rgb[0]) + 0.7152 * channel(rgb[1]) + 0.0722 * channel(rgb[2])


def contrast(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def find_cta(path: str) -> tuple[int, int, int, int]:
    """在浅色落定帧里定位主按钮：accent 绿色块里最宽的那条水平带。"""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    counts: dict[int, int] = {}
    for y in range(int(h * 0.25), int(h * 0.55)):
        c = 0
        for x in range(int(w * 0.6), w - 8):
            r, g, b = im.getpixel((x, y))
            if abs(r - ACCENT[0]) < 20 and abs(g - ACCENT[1]) < 20 and abs(b - ACCENT[2]) < 20:
                c += 1
        if c:
            counts[y] = c
    if not counts:
        raise SystemExit("没找到主按钮")
    peak = max(counts.values())
    rows = [y for y, c in counts.items() if c > peak * 0.6]
    y1, y2 = min(rows), max(rows)
    mid = (y1 + y2) // 2
    cols = [
        x for x in range(int(w * 0.6), w - 8)
        if abs(im.getpixel((x, mid))[0] - ACCENT[0]) < 20
        and abs(im.getpixel((x, mid))[1] - ACCENT[1]) < 20
        and abs(im.getpixel((x, mid))[2] - ACCENT[2]) < 20
    ]
    x1, x2 = min(cols), max(cols)
    return x1, y1, x2, y2


def pure_share(im: Image.Image, box: tuple[int, int, int, int] | None = None) -> tuple[float, float]:
    x1, y1, x2, y2 = box if box else (0, 0, im.width, im.height)
    pixels = 0
    black = 0
    white = 0
    for y in range(y1, y2, 3):
        for x in range(x1, x2, 3):
            r, g, b = im.getpixel((x, y))
            pixels += 1
            if r == 0 and g == 0 and b == 0:
                black += 1
            elif r == 255 and g == 255 and b == 255:
                white += 1
    return 100.0 * black / pixels, 100.0 * white / pixels


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=DEFAULT_DIR)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    light_ref = os.path.normpath(os.path.join(args.dir, LIGHT_REF))
    box = find_cta(light_ref)
    print(f"CTA 区域 = {box}（在 {os.path.relpath(light_ref, ROOT)} 里按 accent 绿定位）")
    rows = []
    for name, label in FRAMES:
        path = os.path.join(args.dir, name)
        if not os.path.exists(path):
            continue
        im = Image.open(path).convert("RGB")
        x1, y1, x2, y2 = box
        inside = [im.getpixel((x, y)) for y in range(y1, y2) for x in range(x1, x2)]
        fill = Counter(inside).most_common(1)[0][0]
        # 只量中间那条（避开胶囊圆角 / 页面底色）：字色 = 与底色亮度差最大的像素
        inner = [
            im.getpixel((x, y))
            for y in range(y1 + 11, y2 - 11)
            for x in range(x1 + 22, x2 - 22)
        ]
        text = max(inner, key=lambda p: abs(luminance(p) - luminance(fill)))
        black_pct, white_pct = pure_share(im)
        cta_black, cta_white = pure_share(im, box)
        rows.append({
            "frame": label,
            "file": name,
            "fill": "#%02X%02X%02X" % fill,
            "text": "#%02X%02X%02X" % text,
            "text_ratio": round(contrast(text, fill), 2),
            "pure_black_pct": round(black_pct, 2),
            "pure_white_pct": round(white_pct, 2),
            "cta_black_pct": round(cta_black, 2),
            "cta_white_pct": round(cta_white, 2),
        })

    if args.json:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
        return
    print(f"{'帧':<7}{'CTA 底色':<10}{'字色':<10}{'字/底':<7}"
          f"{'CTA内纯黑%':<10}{'CTA内纯白%':<10}{'全帧纯黑%':<10}{'全帧纯白%'}")
    for r in rows:
        print(f"{r['frame']:<7}{r['fill']:<10}{r['text']:<10}{r['text_ratio']:<7}"
              f"{r['cta_black_pct']:<10}{r['cta_white_pct']:<10}"
              f"{r['pure_black_pct']:<10}{r['pure_white_pct']}")


if __name__ == "__main__":
    main()
