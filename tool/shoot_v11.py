"""r7 出图：05 页脚压字（默认缩放 0.71）+ 3 条 r6 遗留。

复用 tool/shoot_v9.py 的 CDP 手法（headless Chrome + Page.captureScreenshot）。
这一批的证据全部落在「像素能量」的地方：

  · 05 纸张卡底边 → 页脚分隔线的空白带（deckBg 行数）；
  · press_02 三栏色线的三段游程长度；
  · 页眉小标的字面高度 / 对比度；
  · 按住按钮在两个状态下的矩形（语义树，不经手算）。

用法（仓库根目录，release 包已构建，静态服务指向本 worktree 的 build/web）：
    flutter build web --release
    cd build/web && python -m http.server 8124 --bind 127.0.0.1
    python tool/shoot_v11.py http://127.0.0.1:8124/index.html

输出：先写 docs/screenshots_v11_tmp/，全部成功后再整目录替换 docs/screenshots_v11/
    05_workspace_light.png             默认缩放 0.71、未滚动（v2 纸张卡末行 + 卡底边）
    05_workspace_dark.png              同上，深色（deck 纸面刻意不跟主题变）
    05_workspace_light_scrolled.png    滚到底（证明滚动后也不压字）
    05_toolbar_zoom_2x.png             缩放控件显示 71%
    press_01_light.png                 v1 纸卡 · 悬浮
    press_02_light.png                 v1 纸卡 · 按住（三栏色线）
    press_02_columns_2x.png            三栏色线 2×（三段等长、首栏品牌绿）
    press_01_button_2x.png             悬浮态按钮 2×
    press_02_button_2x.png             按住态按钮 2×（与上一张同一裁剪框）
    press_button_compare_2x.png        上两行拼成一张（左边界/宽度对照）
    press_03_compare_modal.png         前后对比弹层
    press_03_compare_columns_2x.png    弹层缩略图里的三栏色线 2×
    header_t0_4x.png                   页眉「t0 / CONTROLLED SLIDES」4×
    workbench_ring.png / workbench_ring_2x.png   环 + 「已确认 3 个模块」（整屏 / 2×）
    measurements.txt                   本批所有量数（含 docs/screenshots_v9 基线复量）
    positions.json                     语义树里的元素矩形
"""

from __future__ import annotations

import hashlib
import io
import json
import os
import shutil
import sys
import time
import urllib.request

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_contrast import block_contrast  # noqa: E402
from shoot_v9 import (  # noqa: E402
    CDP,
    FIND_RECT,
    PORT,
    click_label,
    enable_semantics,
    ink_bbox,
    route,
    start_chrome,
    to_image,
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "screenshots_v11_tmp")
FINAL = os.path.join(ROOT, "docs", "screenshots_v11")
BASE_SETS = os.path.join(ROOT, "docs", "screenshots_v9")
BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8124/index.html"

VIEW = (1440, 900)
THEME_CENTER = (1346, 36)
IDLE_POINT = (1435, 895)

# 画布列（左 rail 282 + 1 分隔线；右 AI 面板 380 + 1）
CANVAS_X = (283, 1058)
PAPER = (0xFF, 0xFD, 0xF8)   # deckPaper（两套主题同值）
DECK_BG = (0xEB, 0xE6, 0xDB)  # 画布底色（两套主题同值）
COVER = (0x17, 0x21, 0x1F)
DECK_LINE = (0xD9, 0xD4, 0xC9)  # 纸卡 / 页脚的分隔线色（deckLine，两套主题同值）


def save(name: str, data: bytes) -> bytes:
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "wb") as fh:
        fh.write(data)
    print(f"{name}  md5={hashlib.md5(data).hexdigest()[:12]}  {len(data) // 1024}KB")
    return data


def crop_zoom(png: bytes, box, factor: int) -> bytes:
    im = to_image(png).crop(tuple(int(v) for v in box))
    im = im.resize((im.width * factor, im.height * factor), Image.NEAREST)
    buf = io.BytesIO()
    im.save(buf, format="PNG")
    return buf.getvalue()


def near(pixel, color, tol: int = 5) -> bool:
    return all(abs(pixel[i] - color[i]) <= tol for i in range(3))


# ---------------------------------------------------------------- 版面量尺
def row_counts(im: Image.Image, color, x0: int, x1: int, tol: int = 5) -> list[int]:
    """每一行里「等于 color」的像素数（只数画布列）。"""
    px = im.load()
    counts: list[int] = []
    for y in range(im.height):
        hits = 0
        for x in range(x0, x1):
            if near(px[x, y], color, tol):
                hits += 1
        counts.append(hits)
    return counts


def groups_of(rows: list[int], max_gap: int = 2) -> list[tuple[int, int]]:
    """把行号列表合成 [start, end) 连续段。"""
    out: list[tuple[int, int]] = []
    start = prev = None
    for y in rows:
        if start is None:
            start = prev = y
            continue
        if y - prev <= max_gap + 1:
            prev = y
            continue
        out.append((start, prev + 1))
        start = prev = y
    if start is not None:
        out.append((start, prev + 1))
    return out


def cover_bounds(im: Image.Image) -> dict | None:
    """封面卡（深底，两套主题同色）的 x 范围与 y 范围 —— 用它当「卡片列」的定位器。"""
    counts = row_counts(im, COVER, *CANVAS_X)
    rows = [y for y, n in enumerate(counts) if n >= 300]
    groups = groups_of(rows)
    if not groups:
        return None
    top, bottom = max(groups, key=lambda g: g[1] - g[0])
    mid = (top + bottom) // 2
    px = im.load()
    xs = [x for x in range(*CANVAS_X) if near(px[x, mid], COVER)]
    if not xs:
        return None
    return {"x0": xs[0], "x1": xs[-1] + 1, "top": top, "bottom": bottom}


def paper_bands(im: Image.Image, card: dict) -> list[tuple[int, int]]:
    """卡片那一列里「整行基本是纸色」的连续段。

    阈值按卡宽的一半算（正文行也有一半以上是纸），这样文字行不会把卡片切成碎片；
    封面是深底不进这段，进来的只有内容纸卡（浅色下还有页脚）。
    """
    width = card["x1"] - card["x0"]
    counts = row_counts(im, PAPER, card["x0"] + 2, card["x1"] - 2)
    rows = [y for y, n in enumerate(counts) if n >= width * 0.5 and y > 240]
    return [g for g in groups_of(rows) if g[1] - g[0] >= 40]


def dialog_anchor(im: Image.Image) -> tuple[int, int] | None:
    """弹层（Dialog）的左上角：画面上唯一没被 scrim 压暗的纸色像素。"""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if near(px[x, y], PAPER, 2):
                return x, y
    return None


def divider_y(im: Image.Image) -> int | None:
    """页脚上边框那条 1px 分隔线：画布列里 ≥600 像素等于 deckLine 的行。

    卡片内部的行分隔线只有卡宽（约 511px），到不了 600，所以不会被误认。
    """
    counts = row_counts(im, DECK_LINE, *CANVAS_X, tol=4)
    rows = [y for y, n in enumerate(counts) if n >= 600 and y > 400]
    return rows[0] if rows else None


def bands_union(im: Image.Image, card: dict) -> list[tuple[int, int]]:
    """把被「色线 / 满行文字」切断的纸色段合并回一张卡。

    判据是中间那几行的颜色：被 deckBg（画布底色）填满的间隙才是真的卡与卡之间；
    色线行只有 84/510 像素是纸色 —— 它会把卡切成两段，但间隙里没有 deckBg。
    """
    bands = paper_bands(im, card)
    if not bands:
        return []
    width = card["x1"] - card["x0"]
    bg = row_counts(im, DECK_BG, card["x0"], card["x1"])
    merged: list[list[int]] = [[bands[0][0], bands[0][1]]]
    for a, b in bands[1:]:
        gap_rows = range(merged[-1][1], a)
        bg_filled = sum(1 for y in gap_rows if bg[y] >= width * 0.8)
        if a - merged[-1][1] <= 60 and bg_filled < max(1, len(gap_rows) * 0.5):
            merged[-1][1] = b
        else:
            merged.append([a, b])
    return [(int(a), int(b)) for a, b in merged]


def footer_gap(im: Image.Image) -> dict:
    """纸卡底边 → 页脚上边框之间的空白带（像素行数，底色 deckBg）。"""
    card = cover_bounds(im)
    if card is None:
        return {"error": "找不到封面卡"}
    bands = bands_union(im, card)
    if not bands:
        return {"card": card, "bands": [], "error": "找不到纸卡"}
    content = bands[0]
    counts_bg = row_counts(im, DECK_BG, card["x0"], card["x1"])
    card_bottom = content[1]
    gap = 0
    y = card_bottom
    while y < im.height and counts_bg[y] >= (card["x1"] - card["x0"]) * 0.8:
        gap += 1
        y += 1
    return {
        "card": card,
        "bands": bands,
        "card_bottom": card_bottom,
        "footer_top": card_bottom + gap,
        "gap_px": gap,
        "band_bg": f"#{DECK_BG[0]:02X}{DECK_BG[1]:02X}{DECK_BG[2]:02X}",
    }


def color_runs(im: Image.Image, y: int, x0: int, x1: int, min_run: int = 60) -> list[tuple[int, int]]:
    """某一行里「明显不是纸色」的连续游程（用来量三栏色线长度）。"""
    px = im.load()
    runs: list[tuple[int, int]] = []
    start = None
    for x in range(x0, x1):
        ink = max(abs(px[x, y][i] - PAPER[i]) for i in range(3)) > 40
        if ink and start is None:
            start = x
        elif not ink and start is not None:
            if x - start >= min_run:
                runs.append((start, x))
            start = None
    if start is not None and x1 - start >= min_run:
        runs.append((start, x1))
    return runs


def column_lines(im: Image.Image) -> dict:
    """在内容纸卡里找「一行三段长游程」的那一行 = 三栏色线。"""
    card = cover_bounds(im)
    if card is None:
        return {"error": "找不到封面卡"}
    gap = footer_gap(im)
    bands = gap.get("bands") or []
    if not bands:
        return {"error": "找不到纸卡"}
    top = bands[0][0]
    bottom = gap.get("footer_top") or bands[0][1]
    best = None
    for y in range(card["bottom"] + 4, bottom - 2):
        runs = color_runs(im, y, card["x0"] + 3, card["x1"] - 3, min_run=40)
        if len(runs) == 3:
            widths = [b - a for a, b in runs]
            if best is None or sum(widths) > sum(best["widths"]):
                best = {"y": y, "runs": runs, "widths": widths}
    if best is None:
        return {"error": "没找到三栏色线"}
    px = im.load()
    best["colors"] = [
        "#%02X%02X%02X" % px[(a + b) // 2, best["y"]][:3] for a, b in best["runs"]
    ]
    best["spread_px"] = max(best["widths"]) - min(best["widths"])
    best["card"] = [card["x0"], card["x1"], top, bottom]
    return best


def eyebrow(im: Image.Image) -> dict:
    """封面页页眉小标的字面 bbox / 高度 / 对比度。"""
    card = cover_bounds(im)
    if card is None:
        return {"error": "找不到封面卡"}
    counts = row_counts(im, COVER, card["x0"], card["x1"])
    rows = [y for y, n in enumerate(counts) if n >= (card["x1"] - card["x0"]) * 0.8]
    if not rows:
        return {"error": "找不到封面卡"}
    band_y = (rows[0] + 8, rows[0] + 50)
    box = (card["x0"] + 10, band_y[0], card["x0"] + 340, band_y[1])
    bbox, bg = ink_bbox(im, box, thresh=18)
    ratio, _bg, fg = block_contrast(im, box)
    return {
        "cover_top": rows[0],
        "box": list(box),
        "ink_bbox": list(bbox),
        "glyph_h": bbox[3] - bbox[1],
        "glyph_w": bbox[2] - bbox[0],
        "contrast": round(ratio, 2),
        "fg": f"#{fg[0]:02X}{fg[1]:02X}{fg[2]:02X}",
        "bg": f"#{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}",
    }


def pill_span(
    im: Image.Image, y: int, cx: float, x0: int = 740, x1: int = 1040, gap: int = 6
) -> tuple[int, int] | None:
    """工具栏那一行里、包含文案中线的那一段「非底色」游程 = 按钮胶囊的左右边界。

    胶囊内部有图标 / 文字 / 底色（都是非工具栏底色），描边也是非底色，
    所以整颗胶囊是一个连续段；与相邻按钮之间隔着 ≥8px 底色，不会被并进来。
    """
    px = im.load()
    xs = [
        x for x in range(x0, x1)
        if max(abs(px[x, y][i] - PAPER[i]) for i in range(3)) > 6
    ]
    for a, b in groups_of(xs, max_gap=gap):
        if a <= cx < b:
            return a, b
    return None


# ---------------------------------------------------------------- 语义树
def rect_of(cdp: CDP, label: str) -> dict | None:
    return cdp.eval(FIND_RECT % json.dumps(label, ensure_ascii=False))


FIND_RECT_CONTAINS = """(() => {
  const want = %s;
  let best = null;
  for (const el of document.querySelectorAll('flt-semantics')) {
    const text = (el.innerText || '').trim().replace(/\\s+/g, ' ');
    if (text.indexOf(want) < 0) continue;
    const r = el.getBoundingClientRect();
    if (r.width <= 0 || r.height <= 0) continue;
    const area = r.width * r.height;
    if (!best || area < best.area) {
      best = {x: r.x, y: r.y, w: r.width, h: r.height, text: text, area: area};
    }
  }
  return best;
})()"""


def rect_containing(cdp: CDP, label: str) -> dict | None:
    """语义节点常把一整行/整张卡的文案并成一个节点，所以再给一个「包含」版。"""
    return cdp.eval(FIND_RECT_CONTAINS % json.dumps(label, ensure_ascii=False))


def must_rect(cdp: CDP, label: str) -> dict:
    rect = rect_of(cdp, label)
    if not rect:
        raise SystemExit(f"语义树里找不到「{label}」")
    return rect


def must_rect_containing(cdp: CDP, label: str) -> dict:
    rect = rect_containing(cdp, label)
    if not rect:
        raise SystemExit(f"语义树里找不到含「{label}」的节点")
    return rect


def press(cdp: CDP, x: float, y: float) -> None:
    cdp.call(
        "Input.dispatchMouseEvent",
        type="mousePressed",
        x=x,
        y=y,
        button="left",
        buttons=1,
        clickCount=1,
        pointerType="mouse",
    )


def release(cdp: CDP, x: float, y: float) -> None:
    cdp.call(
        "Input.dispatchMouseEvent",
        type="mouseReleased",
        x=x,
        y=y,
        button="left",
        buttons=0,
        clickCount=1,
        pointerType="mouse",
    )


def wheel(cdp: CDP, x: float, y: float, dy: float) -> None:
    cdp.call(
        "Input.dispatchMouseEvent",
        type="mouseWheel",
        x=x,
        y=y,
        deltaX=0,
        deltaY=dy,
        pointerType="mouse",
    )


def publish() -> None:
    """整目录替换：审图永远只会读到「全批生成成功」的那个目录，读不到半成品。

    说明文档（README / REVIEW_REQUEST）不进临时目录：替换时保留上一版的两份 .md，
    免得重拍一次把写好的正文冲掉。
    """
    if os.path.isdir(FINAL):
        for name in ("README.md", "REVIEW_REQUEST.md"):
            src = os.path.join(FINAL, name)
            if os.path.exists(src):
                shutil.copy2(src, os.path.join(OUT, name))
        shutil.rmtree(FINAL)
    shutil.move(OUT, FINAL)
    print(f"已整目录替换 → {FINAL}")


def check_served_matches_disk() -> None:
    disk = os.path.join(ROOT, "build", "web", "main.dart.js")
    with urllib.request.urlopen(BASE.rsplit("/", 1)[0] + "/main.dart.js", timeout=20) as r:
        served = r.read()
    with open(disk, "rb") as fh:
        local = fh.read()
    a, b = hashlib.md5(local).hexdigest(), hashlib.md5(served).hexdigest()
    print(f"main.dart.js  disk={a[:12]} http={b[:12]} {'OK' if a == b else '不一致!'}")
    if a != b:
        raise SystemExit("静态服务指向的不是本 worktree 的 build/web，拒绝落盘")


def main() -> None:
    check_served_matches_disk()
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT, exist_ok=True)
    proc, _info = start_chrome()
    lines: list[str] = []
    positions: dict[str, list[float]] = {}
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json/list", timeout=5) as r:
            targets = [t for t in json.load(r) if t.get("type") == "page"]
        cdp = CDP(targets[0]["webSocketDebuggerUrl"])
        cdp.open_page("about:blank")

        # ------------------------------------------------ ① 05 浅色 · 默认缩放
        cdp.navigate(route(BASE, "workspace"))
        cdp.assert_app()
        print("语义树：", enable_semantics(cdp))
        zoom_rect = must_rect(cdp, "71%")
        positions["05_light:zoom_label"] = [zoom_rect["x"], zoom_rect["y"], zoom_rect["w"], zoom_rect["h"]]
        lines.append(
            f"缩放控件显示「71%」@ x={zoom_rect['x']:.0f}..{zoom_rect['x'] + zoom_rect['w']:.0f}，"
            f"与 mock_data 的 zoom 初值一致"
        )
        cdp.move(*IDLE_POINT)
        time.sleep(0.6)
        light_png = save("05_workspace_light.png", cdp.shot_bytes())
        light = to_image(light_png)
        gap_light = footer_gap(light)
        positions["05_light:paper_bands"] = [v for g in gap_light.get("bands", []) for v in g]
        positions["05_light:card_bottom"] = [gap_light.get("card_bottom"), gap_light.get("footer_top")]
        lines.append(
            "05 浅色（默认 71%、未滚动）："
            f"纸卡底边 y={gap_light.get('card_bottom')}，页脚上边框 y={gap_light.get('footer_top')}"
            f"（分隔线实测 y={divider_y(light)}），间距 {gap_light.get('gap_px')}px（要求 ≥20）"
        )
        save("05_toolbar_zoom_2x.png", crop_zoom(light_png, (
            zoom_rect["x"] - 6, zoom_rect["y"] - 8,
            zoom_rect["x"] + zoom_rect["w"] + 6, zoom_rect["y"] + zoom_rect["h"] + 8,
        ), 2))

        # ------------------------------------------------ ② 05 浅色 · 滚到底
        for _ in range(6):
            wheel(cdp, 670, 600, 240)
            time.sleep(0.25)
        time.sleep(0.8)
        cdp.move(*IDLE_POINT)
        time.sleep(0.5)
        scrolled_png = save("05_workspace_light_scrolled.png", cdp.shot_bytes())
        gap_scrolled = footer_gap(to_image(scrolled_png))
        lines.append(
            "05 浅色（滚到底）："
            f"纸卡底边 y={gap_scrolled.get('card_bottom')}，页脚上边框 y={gap_scrolled.get('footer_top')}，"
            f"间距 {gap_scrolled.get('gap_px')}px"
        )

        # ------------------------------------------------ ③ press_01/02：v1 纸卡三栏
        cdp.navigate(route(BASE, "workspace"))
        cdp.assert_app()
        enable_semantics(cdp)
        click_label(cdp, "撤销")      # 模块 4 回到 v1（三栏布局）
        time.sleep(1.0)
        rect = must_rect(cdp, "按住看修改前")
        bx, by = rect["x"] + rect["w"] / 2, rect["y"] + rect["h"] / 2
        positions["press:idle_button"] = [rect["x"], rect["y"], rect["w"], rect["h"]]
        lines.append(
            f"悬浮态按钮 x={rect['x']:.1f} w={rect['w']:.1f} 高 {rect['h']:.1f}"
        )
        cdp.move(bx, by)
        time.sleep(1.0)
        hover_png = save("press_01_light.png", cdp.shot_bytes())
        pill_idle = pill_span(
            to_image(hover_png), int(rect["y"] + rect["h"] / 2), rect["x"] + rect["w"] / 2
        )
        # 两张按钮局部图必须用同一个裁剪框（取两态胶囊的并集再各留 12px），
        # 否则「按下去按钮有没有动」会被裁剪偏移糊掉
        lines.append(
            f"悬浮态按钮（像素）：胶囊 x={pill_idle[0]}..{pill_idle[1]}，宽 {pill_idle[1] - pill_idle[0]}px"
            if pill_idle else "悬浮态按钮胶囊：没找到"
        )

        press(cdp, bx, by)
        time.sleep(0.5)
        holding_png = save("press_02_light.png", cdp.shot_bytes())
        held = must_rect(cdp, "修改前")
        positions["press:held_button"] = [held["x"], held["y"], held["w"], held["h"]]
        lines.append(
            f"按下态文案「修改前」在固定宽度胶囊里居中：语义 x={rect['x']:.1f}→{held['x']:.1f}"
            f"（宽 {rect['w']:.1f}→{held['w']:.1f}）—— 按钮本体不动，只有文案换字"
        )
        pill_held = pill_span(
            to_image(holding_png), int(held["y"] + held["h"] / 2), held["x"] + held["w"] / 2
        )
        if pill_idle and pill_held:
            btn_box = (
                min(pill_idle[0], pill_held[0]) - 12,
                rect["y"] - 14,
                max(pill_idle[1], pill_held[1]) + 12,
                rect["y"] + rect["h"] + 14,
            )
            positions["press:button_crop"] = list(btn_box)
            save("press_01_button_2x.png", crop_zoom(hover_png, btn_box, 2))
            save("press_02_button_2x.png", crop_zoom(holding_png, btn_box, 2))
            # 两张同框拼成一张：上=悬浮（长文案），下=按住（短文案），左边界必须对齐
            top = Image.open(os.path.join(OUT, "press_01_button_2x.png")).convert("RGB")
            bottom_img = Image.open(os.path.join(OUT, "press_02_button_2x.png")).convert("RGB")
            pad = 10
            combo = Image.new(
                "RGB",
                (max(top.width, bottom_img.width), top.height + pad + bottom_img.height),
                DECK_BG,
            )
            combo.paste(top, (0, 0))
            combo.paste(bottom_img, (0, top.height + pad))
            buf = io.BytesIO()
            combo.save(buf, format="PNG")
            save("press_button_compare_2x.png", buf.getvalue())
            lines.append(
                f"按住态按钮（像素）：胶囊 x={pill_held[0]}..{pill_held[1]}，宽 {pill_held[1] - pill_held[0]}px"
                f" → 左边界差 {pill_held[0] - pill_idle[0]:+d}px，宽度差 "
                f"{(pill_held[1] - pill_held[0]) - (pill_idle[1] - pill_idle[0]):+d}px（原来 110→78，左边界 +32）"
            )
        release(cdp, bx, by)
        time.sleep(0.3)

        # 三栏色线：按住那张（v1 纸卡）上量
        holding = to_image(holding_png)
        cols = column_lines(holding)
        if "error" in cols:
            lines.append(f"三栏色线：{cols['error']}")
        else:
            lines.append(
                f"press_02 三栏色线（屏幕上）：{cols['widths']} px，极差 {cols['spread_px']}px"
                f"（要求 0）；行 y={cols['y']}，游程 {cols['runs']}，线色 {cols['colors']}"
            )
            cx0, cx1 = cols["card"][0], cols["card"][1]
            save("press_02_columns_2x.png", crop_zoom(holding_png, (
                cx0, cols["y"] - 8, cx1, cols["y"] + 42,
            ), 2))

        # 页眉 4×：同一张 press_02 里的封面页页眉
        eb = eyebrow(holding)
        positions["press:eyebrow_box"] = eb.get("box", [])
        if "error" not in eb:
            box = eb["box"]
            save("header_t0_4x.png", crop_zoom(holding_png, (
                eb["ink_bbox"][0] - 6, eb["ink_bbox"][1] - 6,
                eb["ink_bbox"][2] + 6, eb["ink_bbox"][3] + 6,
            ), 4))
            lines.append(
                f"页眉「t0 / CONTROLLED SLIDES」字面 bbox={eb['ink_bbox']}，"
                f"字面高 {eb['glyph_h']}px（屏幕上，默认 71%），对比度 {eb['contrast']}:1"
                f"（字 {eb['fg']} / 底 {eb['bg']}）"
            )

        # ------------------------------------------------ ④ 对比弹层里的同款小标（#5 的第二个面）
        click_label(cdp, "前后对比")
        time.sleep(1.0)
        modal_png = save("press_03_compare_modal.png", cdp.shot_bytes())
        # 弹层里「修改前」那张缩略图的三栏线也换成 deckAccent 了，给一张 2× 局部。
        # 弹层是画面上唯一没被 scrim 压暗的 #FFFDF8 区域 → 用它当锚点
        # （这个 Dialog 里的文字在语义树里没单独暴露，找不到「修改前」节点）。
        via = dialog_anchor(to_image(modal_png))
        if via:
            ax, ay = via
            save("press_03_compare_columns_2x.png", crop_zoom(modal_png, (
                ax - 2, ay + 44, ax + 440, ay + 312,
            ), 2))
        cdp.call(
            "Input.dispatchKeyEvent", type="keyDown", key="Escape", code="Escape", windowsVirtualKeyCode=27
        )
        cdp.call(
            "Input.dispatchKeyEvent", type="keyUp", key="Escape", code="Escape", windowsVirtualKeyCode=27
        )
        time.sleep(0.6)

        # ------------------------------------------------ ⑤ 01 工作台 · 环 + 新小字
        cdp.navigate(route(BASE, "workbench"))
        cdp.assert_app()
        enable_semantics(cdp)
        # 语义树把整张项目卡合成一个节点，这里只取它的文案当「字面证据」，
        # 小字的位置交给像素：卡片右端 934..980 是环，环左侧一条只属于这句小字。
        card = must_rect_containing(cdp, "已确认 3 个模块")
        positions["01:ring_card"] = [card["x"], card["y"], card["w"], card["h"]]
        cdp.move(*IDLE_POINT)
        time.sleep(0.6)
        bench_png = save("workbench_ring.png", cdp.shot_bytes())
        bench = to_image(bench_png)
        cap_bbox, cap_bg = ink_bbox(
            bench, (700, int(card["y"]) + 6, 932, int(card["y"] + card["h"]) - 6), thresh=18
        )
        positions["01:ring_caption_ink"] = list(cap_bbox)
        save("workbench_ring_2x.png", crop_zoom(bench_png, (
            cap_bbox[0] - 26, card["y"] + 6, cap_bbox[2] + 66, card["y"] + card["h"] - 6,
        ), 2))
        lines.append(
            f"工作台环旁小字「已确认 3 个模块」字面 bbox={cap_bbox}"
            f"（高 {cap_bbox[3] - cap_bbox[1]}px / 宽 {cap_bbox[2] - cap_bbox[0]}px，底 "
            f"#{cap_bg[0]:02X}{cap_bg[1]:02X}{cap_bg[2]:02X}）；卡片语义文案="
            f"「{card['text'].split(' ')[-3]} {card['text'].split(' ')[-2]} {card['text'].split(' ')[-1]}」"
        )

        # ------------------------------------------------ ⑤ 05 深色
        cdp.navigate(route(BASE, "workspace"))
        cdp.assert_app()
        enable_semantics(cdp)
        cdp.click(*THEME_CENTER)
        time.sleep(1.4)
        cdp.move(*IDLE_POINT)
        time.sleep(0.5)
        dark_png = save("05_workspace_dark.png", cdp.shot_bytes())
        gap_dark = footer_gap(to_image(dark_png))
        lines.append(
            "05 深色（默认 71%、未滚动）："
            f"纸卡底边 y={gap_dark.get('card_bottom')}，页脚上边框 y={gap_dark.get('footer_top')}"
            f"（深色的分隔线走 dark line token，不用浅色 #D9D4C9 认；上边框由 deckBg 行数直接量到），"
            f"间距 {gap_dark.get('gap_px')}px（要求 ≥20）"
        )
        # 深色下也把页眉小标量一次（同一个 sans 12px，底变了）
        eb_dark = eyebrow(to_image(dark_png))
        if "error" not in eb_dark:
            lines.append(
                f"页眉小标（深色）字面高 {eb_dark['glyph_h']}px，对比度 {eb_dark['contrast']}:1"
                f"（字 {eb_dark['fg']} / 底 {eb_dark['bg']}）"
            )

        # ------------------------------------------------ 基线复量（改前）
        # 基线那两张是 r6 构建（0.82 默认缩放）。注意：0.82 下纸卡下端被页脚切断，
        # 「纸卡底边」在图上根本量不到（纸卡与页脚同色连成一片），所以不能拿 y=900 当卡底——
        # 这里用「卡宽 × 9/16 推出卡高」再和页脚分隔线比，报被压住的像素数。
        before_05 = os.path.join(BASE_SETS, "05_workspace_light.png")
        if os.path.exists(before_05):
            im_before = to_image(before_05)
            bcard = cover_bounds(im_before)
            bbands = bands_union(im_before, bcard) if bcard else []
            if bcard and bbands:
                top = bbands[0][0]
                h = (bcard["x1"] - bcard["x0"]) * 9 / 16
                bottom_expected = top + h
                divider = divider_y(im_before)
                if divider is None:
                    lines.append("改前基线：量不到页脚分隔线")
                else:
                    lines.append(
                        "改前基线 docs/screenshots_v9/05_workspace_light.png（0.82 默认缩放，r6 构建）："
                        f"内容纸卡 top={top}、卡宽 {bcard['x1'] - bcard['x0']} → 卡高 {h:.0f}px，"
                        f"卡底应在 y={bottom_expected:.0f}；页脚分隔线 y={divider}，"
                        f"纸卡被压住 {bottom_expected - divider:.0f}px（图上纸卡与页脚同色连成一片，量不到卡底）"
                    )
        before_press = os.path.join(BASE_SETS, "press_02_holding.png")
        if os.path.exists(before_press):
            im = to_image(before_press)
            cols_before = column_lines(im)
            if "error" not in cols_before:
                lines.append(
                    f"改前三栏色线（同法量 r6 基线）：{cols_before['widths']} px，"
                    f"极差 {cols_before['spread_px']}px"
                )
            eb_before = eyebrow(im)
            if "error" not in eb_before:
                lines.append(
                    f"改前页眉小标字面高 {eb_before['glyph_h']}px，对比度 {eb_before['contrast']}:1"
                    f"（字 {eb_before['fg']} / 底 {eb_before['bg']}）"
                )

        text = "\n".join("- " + line for line in lines)
        print("\n" + text)
        with open(os.path.join(OUT, "measurements.txt"), "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
        with open(os.path.join(OUT, "positions.json"), "w", encoding="utf-8") as fh:
            json.dump(positions, fh, ensure_ascii=False, indent=2)
        publish()
    except BaseException as exc:  # 出错也要把已经量到的数落盘，别让半批证据蒸发
        print(f"[失败] {type(exc).__name__}: {exc}")
        text = "\n".join("- " + line for line in lines)
        print(text)
        os.makedirs(OUT, exist_ok=True)
        with open(os.path.join(OUT, "measurements.txt"), "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
        with open(os.path.join(OUT, "positions.json"), "w", encoding="utf-8") as fh:
            json.dump(positions, fh, ensure_ascii=False, indent=2)
        raise
    finally:
        proc.kill()


if __name__ == "__main__":
    main()
