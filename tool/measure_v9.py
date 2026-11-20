"""r4 的对比度 / 内边距实测：同一把尺子量 v8（改前）与 v9（改后）。

方法（与审图、`tool/measure_contrast.py` 一致）：
  · 取样带里出现最多的颜色当底色；
  · 取「与底色亮度差最大、且像素数 ≥12」的颜色当字色（排除反锯齿零星点）；
  · 按 WCAG 相对亮度算比值。
取样带是写死的视口矩形（1440×900），材料输入页 r4 一个像素都没挪版面，
所以 v8 的基线图能用同一批矩形；工作台右卡改成按「卡面色的外接矩形」现量。

用法（仓库根目录）：
    python tool/measure_v9.py
输出：
    终端打印 + docs/screenshots_v9/measurements.txt
"""

from __future__ import annotations

import os
import sys
from collections import Counter

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shoot_v9 import find_paper_card, ink_bbox  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V8 = os.path.join(ROOT, "docs", "screenshots_v8")
V9 = os.path.join(ROOT, "docs", "screenshots_v9")
V6 = os.path.join(ROOT, "docs", "screenshots_v6")

# 取样带（x1, y1, x2, y2）左闭右开，写死是为了 v8 / v9 用同一把尺子
BOXES = {
    "danger_text": (280, 610, 380, 634),   # 「模拟解析失败」胶囊里的字
    "tab_text": (500, 290, 620, 308),      # 未选中 tab「粘贴文本」
    "file_meta": (185, 558, 400, 578),     # 文件卡 meta 那行
    "ring_caption": (860, 486, 932, 508),  # 环左侧「已确认 3/5」
}
LIGHT_SURFACE = (0xFF, 0xFD, 0xF8)
DARK_SURFACE = (0x3A, 0x2F, 0x44)


def channel(c: int) -> float:
    v = c / 255
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def luminance(rgb) -> float:
    return 0.2126 * channel(rgb[0]) + 0.7152 * channel(rgb[1]) + 0.0722 * channel(rgb[2])


def contrast(fg, bg) -> float:
    lfg, lbg = luminance(fg), luminance(bg)
    hi, lo = max(lfg, lbg), min(lfg, lbg)
    return (hi + 0.05) / (lo + 0.05)


def hexs(rgb) -> str:
    return "#%02X%02X%02X" % (rgb[0], rgb[1], rgb[2])


def measure(path: str, box) -> tuple[float, str, str]:
    im = Image.open(path).convert("RGB")
    crop = im.crop(box)
    pixels = list(crop.getdata())
    counts = Counter(pixels)
    bg = counts.most_common(1)[0][0]
    lbg = luminance(bg)
    candidates = [(n, p) for p, n in counts.items() if p != bg and n >= 12]
    if not candidates:
        candidates = [(n, p) for p, n in counts.items() if p != bg]
    fg = max(candidates, key=lambda t: abs(luminance(t[1]) - lbg))[1]
    return contrast(fg, bg), hexs(fg), hexs(bg)


def measure_core(path: str, box) -> tuple[float, str, str]:
    """字芯色：不管出现几次，取离底色最远的那个像素（11px 小字的笔画芯只有十来个像素）。"""
    im = Image.open(path).convert("RGB")
    pixels = list(im.crop(box).getdata())
    counts = Counter(pixels)
    bg = counts.most_common(1)[0][0]
    lbg = luminance(bg)
    fg = max((p for p in counts if p != bg), key=lambda p: abs(luminance(p) - lbg))
    return contrast(fg, bg), hexs(fg), hexs(bg)


def measure_card_padding(path: str) -> tuple[int, int, tuple[int, int, int, int]]:
    """右卡：卡面外接矩形 → 卡内墨迹外接矩形 → 上 / 下留白（像素）。"""
    im = Image.open(path).convert("RGB")
    region = (1010, 405, 1355, 790)
    crop = im.crop(region)
    px = crop.load()
    xs: list[int] = []
    ys: list[int] = []
    for y in range(crop.height):
        for x in range(crop.width):
            p = px[x, y]
            if max(abs(p[0] - LIGHT_SURFACE[0]), abs(p[1] - LIGHT_SURFACE[1]),
                   abs(p[2] - LIGHT_SURFACE[2])) <= 6:
                xs.append(x)
                ys.append(y)
    card = (region[0] + min(xs), region[1] + min(ys), region[0] + max(xs), region[1] + max(ys))
    # 左右各收 30px：18 的圆角在卡顶那几行还是页底色，会把它当成墨迹
    inner = (card[0] + 30, card[1] + 2, card[2] - 29, card[3] - 1)
    ink, _ = ink_bbox(im, inner, thresh=24)
    return ink[1] - card[1], card[3] - (ink[3] - 1), card


def measure_label(path: str) -> tuple[int, int, tuple[int, int, int, int]]:
    """纸张卡左上中文小标：字面高 / 宽（像素）。"""
    im = Image.open(path).convert("RGB")
    page = find_paper_card(im, (290, 300, 1055, 900), LIGHT_SURFACE)
    if page is None:
        raise SystemExit(f"{path} 里找不到纸张卡")
    # 只取纸页左上角那一小块：下面 20px 就是标题，取样带放宽会把标题量进去
    band = (page[0] + 10, page[1] + 10, page[0] + 95, page[1] + 40)
    box, _ = ink_bbox(im, band, thresh=24)
    return box[3] - box[1], box[2] - box[0], box


def arc_bbox(path: str, region) -> tuple[int, int, int, int]:
    """环的绿色弧外接矩形：用来证明「环没挪位」。"""
    im = Image.open(path).convert("RGB")
    px = im.load()
    xs: list[int] = []
    ys: list[int] = []
    for y in range(region[1], region[3]):
        for x in range(region[0], region[2]):
            c = px[x, y]
            if abs(c[0] - 0x14) < 40 and abs(c[1] - 0x7A) < 40 and abs(c[2] - 0x62) < 40:
                xs.append(x)
                ys.append(y)
    return (min(xs), min(ys), max(xs), max(ys))


def border_rows(path: str, x: int, region) -> list[int]:
    """某一列上等于卡描边色 #D9D4C9 的行 = 项目卡的上下边框。"""
    im = Image.open(path).convert("RGB")
    px = im.load()
    line = (0xD9, 0xD4, 0xC9)
    return [
        y
        for y in range(region[0], region[1])
        if max(abs(px[x, y][i] - line[i]) for i in range(3)) < 12
    ]


def main() -> None:
    lines: list[str] = []

    def out(text: str = "") -> None:
        print(text)
        lines.append(text)

    pairs = [
        ("danger_text 深色「模拟解析失败」",
         os.path.join(V8, "06_intake_topbar_dark.png"),
         os.path.join(V9, "02_intake_dark.png"), BOXES["danger_text"]),
        ("danger_text 浅色「模拟解析失败」",
         os.path.join(V8, "02_intake_topbar.png"),
         os.path.join(V9, "02_intake_light.png"), BOXES["danger_text"]),
        ("tab_text 浅色未选中 tab",
         os.path.join(V8, "02_intake_topbar.png"),
         os.path.join(V9, "02_intake_light.png"), BOXES["tab_text"]),
        ("file_meta 浅色文件卡 meta",
         os.path.join(V8, "02_intake_topbar.png"),
         os.path.join(V9, "02_intake_light.png"), BOXES["file_meta"]),
        ("tab_text 深色未选中 tab",
         os.path.join(V8, "06_intake_topbar_dark.png"),
         os.path.join(V9, "02_intake_dark.png"), BOXES["tab_text"]),
        ("file_meta 深色文件卡 meta",
         os.path.join(V8, "06_intake_topbar_dark.png"),
         os.path.join(V9, "02_intake_dark.png"), BOXES["file_meta"]),
    ]
    out("== 对比度（WCAG，取样带固定；v8 = 改前，v9 = 改后） ==")
    out(f"{'元素':<28}{'改前':>8}{'改后':>8}   {'改前字/底':<20}{'改后字/底':<20}")
    for label, before_path, after_path, box in pairs:
        b, bg_f, bg_b = measure(before_path, box)
        a, ag_f, ag_b = measure(after_path, box)
        out(f"{label:<26}{b:>8.2f}{a:>8.2f}   {bg_f + ' on ' + bg_b:<20}{ag_f + ' on ' + ag_b:<20}")

    out("")
    out("== 01 工作台右卡「产品流程·三步」上下内边距（像素） ==")
    for tag, path in (
        ("改前 v8 01", os.path.join(V8, "01_workbench_topbar.png")),
        ("改后 v9 01", os.path.join(V9, "01_workbench_light.png")),
    ):
        top, bottom, card = measure_card_padding(path)
        out(f"{tag}: 卡 {card[0]},{card[1]}..{card[2]},{card[3]}  上 {top}px / 下 {bottom}px  差 {abs(top - bottom)}px")

    out("")
    out("== 01 工作台环旁「已确认 3/5」 ==")
    for tag, path in (
        ("浅色 v9", os.path.join(V9, "01_workbench_light.png")),
        ("深色 v9", os.path.join(V9, "01_workbench_dark.png")),
    ):
        r, fg, bg = measure(path, BOXES["ring_caption"])
        r_core, fg_core, _ = measure_core(path, BOXES["ring_caption"])
        out(
            f"{tag}: 字芯 {fg_core} on {bg} = {r_core:.2f}；"
            f"按审图尺子（深色像素 ≥12 个）取到抗锯齿色 {fg} = {r:.2f}"
        )
    cap_light = measure_core(os.path.join(V9, "01_workbench_light.png"), BOXES["ring_caption"])
    out(
        f"（交付页那句「已就绪 4/5（含 1 待确认）」在同一令牌上：11px · ink2Strong，"
        f"浅色字芯 {cap_light[1]}，与本行同色同字号）"
    )

    out("")
    out("== 01 项目卡：环的位置 / 卡上下边框（逐像素） ==")
    for tag, path in (
        ("改前 v8 01", os.path.join(V8, "01_workbench_topbar.png")),
        ("改后 v9 01", os.path.join(V9, "01_workbench_light.png")),
    ):
        arc = arc_bbox(path, (900, 440, 1010, 560))
        rows = border_rows(path, 500, (430, 700))
        out(f"{tag}: 环绿弧 {arc[0]},{arc[1]}..{arc[2]},{arc[3]}；卡边框行 {rows}")

    out("")
    out("== 05 纸张卡左上中文小标「结构压缩版」（字面像素高） ==")
    for tag, path in (
        ("改前 v6 03_light_模块工作区", os.path.join(V6, "03_light_模块工作区.png")),
        ("改后 v9 05_workspace_light", os.path.join(V9, "05_workspace_light.png")),
    ):
        h, w, box = measure_label(path)
        out(f"{tag}: 字面 {w}×{h}px @ {box}")

    out("")
    out("== 图与列的对应 ==")
    out("01_workbench_light/dark.png   → 环旁口径、右卡内边距")
    out("02_intake_light.png           → tab 未选中 / 文件卡 meta / 「模拟解析失败」浅色")
    out("02_intake_dark.png            → 「模拟解析失败」深色（本轮 P2）")
    out("05_workspace_light/dark.png   → 纸张卡左上中文小标")
    out("07~11_*_2x.png                → 上面四处的 2× / 10× 局部")

    with open(os.path.join(V9, "measurements.txt"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
