"""r6 出图：按住看修改前（press_*）+ 工作台左边界复拍 + 数字证明。

复用 tool/shoot_v9.py 的 CDP 手法（headless Chrome + Page.captureScreenshot）。
按住那一张是在「指针真的按着不动」的状态下截的（mousePressed 与 mouseReleased
分开发），不是摆出来的样式；松开那张把指针移开按钮再截，与悬浮态明显不同。

用法（仓库根目录，release 包已构建，静态服务指向本 worktree 的 build/web）：
    flutter build web --release
    cd build/web && python -m http.server 8123 --bind 127.0.0.1
    python tool/shoot_r6.py http://127.0.0.1:8123/index.html

输出 docs/screenshots_v9/：
    press_01_hover.png           悬停在「按住看修改前」上（画布仍是 v2，无提示）
    press_02_holding.png         按住不放（画布切 v1 + 顶部「正在看修改前」细胶囊）
    press_04_compare_modal.png   「前后对比」弹层（双栏并排）
    press_05_v1_title_2x.png     v1 态纸张卡标题 2×（验「两行、无孤字尾巴」）
    press_diff.txt               01↔02 / 01↔03 差异像素、胶囊与卡顶间隙、左边界基准
    01_workbench_light.png       复拍：虚线入口左边界与卡边框对齐（P2-②）
    01_workbench_dark.png        同上，深色
"""

from __future__ import annotations

import hashlib
import io
import json
import os
import sys
import time
import urllib.request

from PIL import Image, ImageChops

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shoot_v9 import (  # noqa: E402
    CDP,
    FIND_RECT,
    OUT,
    PORT,
    click_label,
    enable_semantics,
    route,
    start_chrome,
)

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8123/index.html"
HOLD_LABEL = "按住看修改前"
HINT_LABEL = "正在看修改前"

WORKBENCH_BG = (246, 242, 233)   # 浅色 bg
ACCENT_SOFT = (223, 240, 233)    # 胶囊底 accentSoft
DECK_COVER = (23, 33, 31)        # 封面卡 deckCover
LINE_STRONG = (185, 179, 166)    # 浅色 lineStrong（虚线入口描边）
LINE = (217, 212, 201)           # 浅色 line（项目卡边框）
INK = (23, 33, 31)               # 浅色 ink（大标题字芯）


def rect_of(cdp: CDP, label: str) -> dict:
    rect = cdp.eval(FIND_RECT % json.dumps(label, ensure_ascii=False))
    if not rect:
        raise SystemExit(f"语义树里找不到「{label}」")
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


def to_image(png: bytes) -> Image.Image:
    return Image.open(io.BytesIO(png)).convert("RGB")


def diff_pixels(a: Image.Image, b: Image.Image) -> tuple[int, tuple[int, int, int, int] | None]:
    diff = ImageChops.difference(a, b).convert("L")
    bbox = diff.getbbox()
    hist = diff.histogram()
    pixels = sum(hist[9:])
    return pixels, bbox


def save(name: str, data: bytes) -> bytes:
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "wb") as fh:
        fh.write(data)
    print(f"{name}  md5={hashlib.md5(data).hexdigest()[:12]}  {len(data) // 1024}KB")
    return data


def crop_zoom(png: bytes, box: tuple[int, int, int, int], factor: int, name: str) -> None:
    im = to_image(png).crop(box)
    im = im.resize((im.width * factor, im.height * factor), Image.NEAREST)
    buf = io.BytesIO()
    im.save(buf, format="PNG")
    save(name, buf.getvalue())


def close_to(px: tuple[int, int, int], target: tuple[int, int, int], tol: int = 6) -> bool:
    return all(abs(px[i] - target[i]) <= tol for i in range(3))


def pill_and_card_gap(im: Image.Image) -> dict:
    """量「正在看修改前」胶囊与封面卡上边框之间的间隙（胶囊底 → 卡顶，单位 px）

    轴向：胶囊在画布顶部居中（x 600..760），封面卡在 x=800 这一列上一定能采到。
    """
    pill_rows = [
        y for y in range(150, 260)
        if any(close_to(im.getpixel((x, y)), ACCENT_SOFT) for x in range(600, 760))
    ]
    card_rows = [y for y in range(150, 400) if close_to(im.getpixel((800, y)), DECK_COVER)]
    if not pill_rows or not card_rows:
        return {"pill_top": None, "pill_bottom": None, "card_top": None, "gap": None}
    return {
        "pill_top": pill_rows[0],
        "pill_bottom": pill_rows[-1],
        "card_top": card_rows[0],
        "gap": card_rows[0] - pill_rows[-1] - 1,
    }


def workbench_left_edges(im: Image.Image) -> dict:
    """量工作台左边界：虚线入口描边 x / 项目卡左边框 x / 大标题起笔 x

    按颜色认边界，不按「非底色」认 —— 页面底色上还叠着一层极淡网格线。
    """
    def first_of(y0: int, y1: int, color: tuple[int, int, int], tol: int = 6) -> int | None:
        best: int | None = None
        for y in range(y0, y1):
            for x in range(0, 400):
                if close_to(im.getpixel((x, y)), color, tol):
                    best = x if best is None else min(best, x)
                    break
        return best

    return {
        "dashed_x": first_of(660, 790, LINE_STRONG),   # 虚线入口描边
        "card_x": first_of(440, 560, LINE),           # 项目卡左边框
        "headline_x": first_of(200, 260, INK),        # 大标题起笔（含抗锯齿）
    }


def dark_grid_contrast(im: Image.Image) -> str:
    """深色底纹可见性：取页面空白区里出现最多的两种颜色（底 + 网格），报差值/255"""
    from collections import Counter

    counter: Counter[tuple[int, int, int]] = Counter()
    for y in range(760, 890, 2):
        for x in range(40, 300, 2):
            counter[im.getpixel((x, y))] += 1
    common = counter.most_common(2)
    if len(common) < 2:
        return "采样不足"
    (c0, _), (c1, _) = common
    delta = [abs(a - b) for a, b in zip(c0, c1)]
    return f"底 #{c0[0]:02X}{c0[1]:02X}{c0[2]:02X} / 网格 #{c1[0]:02X}{c1[1]:02X}{c1[2]:02X} 差 {max(delta)}/255"


def check_served_matches_disk() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    disk = os.path.join(root, "build", "web", "main.dart.js")
    if not os.path.exists(disk):
        return
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
    proc, _info = start_chrome()
    lines: list[str] = []
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json/list", timeout=5) as r:
            targets = [t for t in json.load(r) if t.get("type") == "page"]
        cdp = CDP(targets[0]["webSocketDebuggerUrl"])
        cdp.open_page("about:blank")

        # ---------------------------------------------------------- 05 工作区 · 按住
        cdp.navigate(route(BASE, "workspace"))
        cdp.assert_app()
        print("语义树：", enable_semantics(cdp))

        rect = rect_of(cdp, HOLD_LABEL)
        cx, cy = rect["x"] + rect["w"] / 2, rect["y"] + rect["h"] / 2
        print(f"按住按钮 @ {cx:.1f},{cy:.1f} ({rect['w']:.0f}x{rect['h']:.0f})")

        cdp.move(cx, cy)
        time.sleep(1.2)
        hover_png = save("press_01_hover.png", cdp.shot_bytes())
        hover = to_image(hover_png)
        hint_before = cdp.eval(FIND_RECT % json.dumps(HINT_LABEL, ensure_ascii=False))
        lines.append(f"悬浮时「{HINT_LABEL}」提示：{'出现（错）' if hint_before else '没有（对）'}")

        press(cdp, cx, cy)
        time.sleep(0.45)
        holding_png = cdp.shot_bytes()
        holding = to_image(save("press_02_holding.png", holding_png))
        hint_holding = cdp.eval(FIND_RECT % json.dumps(HINT_LABEL, ensure_ascii=False))
        lines.append(f"按住时「{HINT_LABEL}」提示：{'出现（对）' if hint_holding else '没有（错）'}")
        gap = pill_and_card_gap(holding)
        lines.append(
            f"胶囊/封面卡间隙：胶囊 {gap.get('pill_top')}..{gap.get('pill_bottom')}，"
            f"卡顶 {gap.get('card_top')}，间隙 {gap.get('gap')}px（要求 ≥8）"
        )
        crop_zoom(holding_png, (376, 554, 966, 700), 2, "press_05_v1_title_2x.png")

        # 松开后把指针移开按钮：这一帧不单独出图 —— 按钮没有 hover 视觉态，
        # 「松开」与「悬浮」本来就该逐像素相同（审图 P2：不能拿同一张图当两种状态的证据）。
        # 这里只留数字：松开后的 md5 回到 press_01 那一张，证明画布真的复位了。
        release(cdp, cx, cy)
        time.sleep(0.35)
        cdp.move(700, 880)
        time.sleep(0.35)
        released_png = cdp.shot_bytes()
        released = to_image(released_png)
        lines.append(
            "松开后 md5="
            f"{hashlib.md5(released_png).hexdigest()[:12]}，"
            f"press_01 md5={hashlib.md5(hover_png).hexdigest()[:12]}，"
            f"{'复位一致（画布回到 v2）' if released_png == hover_png else '不一致（有问题）'}"
        )

        click_label(cdp, "前后对比")
        time.sleep(0.9)
        save("press_04_compare_modal.png", cdp.shot_bytes())

        hold_px, hold_box = diff_pixels(hover, holding)
        rel_px, rel_box = diff_pixels(hover, released)
        lines.append(f"press_01 vs press_02 差异像素 {hold_px}（bbox={hold_box}）")
        lines.append(f"press_01 vs 松开后 差异像素 {rel_px}（bbox={rel_box}，期望 0）")
        lines.append(f"画面尺寸 {hover.size[0]}x{hover.size[1]}")

        # ---------------------------------------------------------- 01 工作台 · 左边界
        for dark, name in ((False, "01_workbench_light.png"), (True, "01_workbench_dark.png")):
            cdp.navigate(route(BASE, "workbench"))
            cdp.assert_app()
            if dark:
                enable_semantics(cdp)
                cdp.click(1346, 36)
                time.sleep(1.4)
                cdp.move(1435, 895)
                time.sleep(0.4)
            else:
                enable_semantics(cdp)
            png = save(name, cdp.shot_bytes())
            if dark:
                lines.append("深色底纹：" + dark_grid_contrast(to_image(png)))
            if not dark:
                # 只量浅色：深色的 line / lineStrong 是另一组色值，版面走同一段代码
                edges = workbench_left_edges(to_image(png))
                lines.append(
                    f"工作台左边界（浅色）：虚线入口 x={edges['dashed_x']}，"
                    f"项目卡 x={edges['card_x']}，大标题起笔 x={edges['headline_x']}"
                )

        text = "\n".join(lines)
        print(text)
        with open(os.path.join(OUT, "press_diff.txt"), "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
    finally:
        proc.kill()


if __name__ == "__main__":
    main()
