"""r8 收官出图：幻灯片页眉页码统一 + 05 纸卡首条分隔线间距。

复用 tool/shoot_v9.py 的 CDP 手法（headless Chrome + Page.captureScreenshot）与
tool/shoot_v11.py 的版面量尺。这批只有两件事要证：

  · 页码：同一张幻灯片右上角在舞台（纸卡）、深绿封面页、对比弹层缩略图三处
    都是 `t0 / 04`。文字直接从 Flutter 语义树读出来贴进 measurements.txt，
    像素上再用墨迹 bbox 宽度和 v11 基线（只有 `04`）对照。
  · 三条分隔线到各自条目标题的距离：v11 是 16 / 7 / 7，现在要求一致。

press_01_light.png 这张按任务书重拍：点「撤销」后等 toast（2400ms）彻底消失
再悬停截图，并且用像素证明 toast 带里一个深色像素都没有——同时那张图里按钮
确实是悬浮态（胶囊量得到），所以「hover 高亮 + toast 并存」不会再有。

用法（仓库根目录，release 包已构建，静态服务指向本 worktree 的 build/web）：
    flutter build web --release
    cd build/web && python -m http.server 8130 --bind 127.0.0.1
    python tool/shoot_v12.py http://127.0.0.1:8130/index.html

输出：先写 docs/screenshots_v12_tmp/，全部成功后再整目录替换 docs/screenshots_v12/
    05_workspace_light.png       05 浅色（默认 71%）：三条分隔线 + 三行标题
    05_dividers_2x.png           上面那张的列表区 2×（三线三行）
    header_stage_2x.png          舞台纸卡右上角页码 2×
    header_cover_2x.png          深绿封面页右上角页码 2×（同一套写法的第三处）
    modal_compare.png            前后对比弹层整屏（两张缩略图都在）
    header_modal_2x.png          弹层两张缩略图的页眉 2× 上下对照
    press_01_light.png           v1 纸卡 · 悬浮（toast 已消失，像素验证）
    BUILD_HASH                   build/web/main.dart.js 的 md5
    measurements.txt / positions.json
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
from shoot_v9 import (  # noqa: E402
    CDP,
    PORT,
    click_label,
    enable_semantics,
    ink_bbox,
    route,
    start_chrome,
    to_image,
)
from shoot_v11 import (  # noqa: E402
    bands_union,
    cover_bounds,
    groups_of,
    near,
    row_counts,
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "screenshots_v12_tmp")
FINAL = os.path.join(ROOT, "docs", "screenshots_v12")
BASE_SETS = os.path.join(ROOT, "docs", "screenshots_v11")
BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8130/index.html"

IDLE_POINT = (1435, 895)
PAPER = (0xFF, 0xFD, 0xF8)
DECK_BG = (0xEB, 0xE6, 0xDB)

# toast 是一条 pal.ink 深色胶囊（浅色主题下 #17211F），Positioned bottom:36、
# 左右各 16 后水平居中。v11 审图实测它落在 x≈608–834 / y≈818–862。
# 取样带避开页脚左侧文字（x≤570）与右侧两个按钮（x≥870）。
TOAST_BAND = (590, 812, 860, 868)

SEM_TEXT = """(() => Array.from(document.querySelectorAll('flt-semantics'))
  .map(e => (e.innerText || '').trim().replace(/\\s+/g, ' '))
  .filter(t => t.indexOf('t0 /') >= 0 && t.length < 40))()"""


# ---------------------------------------------------------------- 落盘
def save(name: str, data: bytes) -> bytes:
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "wb") as fh:
        fh.write(data)
    print(f"{name}  md5={hashlib.md5(data).hexdigest()[:12]}  {len(data) // 1024}KB")
    return data


def crop_zoom(png, box, factor: int) -> bytes:
    im = to_image(png).crop(tuple(int(v) for v in box))
    im = im.resize((im.width * factor, im.height * factor), Image.NEAREST)
    buf = io.BytesIO()
    im.save(buf, format="PNG")
    return buf.getvalue()


def publish() -> None:
    """整目录替换；文档不进临时目录，替换时把上一版的两份 .md 带过来。"""
    if os.path.isdir(FINAL):
        for name in ("README.md", "REVIEW_REQUEST.md"):
            src = os.path.join(FINAL, name)
            if os.path.exists(src):
                shutil.copy2(src, os.path.join(OUT, name))
        shutil.rmtree(FINAL)
    shutil.move(OUT, FINAL)
    print(f"已整目录替换 → {FINAL}")


def check_served_matches_disk() -> str:
    disk = os.path.join(ROOT, "build", "web", "main.dart.js")
    with urllib.request.urlopen(BASE.rsplit("/", 1)[0] + "/main.dart.js", timeout=30) as r:
        served = r.read()
    with open(disk, "rb") as fh:
        local = fh.read()
    a, b = hashlib.md5(local).hexdigest(), hashlib.md5(served).hexdigest()
    print(f"main.dart.js  disk={a[:12]} http={b[:12]} {'OK' if a == b else '不一致!'}")
    if a != b:
        raise SystemExit("静态服务指向的不是本 worktree 的 build/web，拒绝落盘")
    return a


# ---------------------------------------------------------------- 量尺
def _dist(p, ref=PAPER) -> int:
    return max(abs(p[i] - ref[i]) for i in range(3))


def paper_card(im: Image.Image) -> dict:
    card = cover_bounds(im)
    if card is None:
        raise SystemExit("找不到封面卡，版面已经变了")
    bands = bands_union(im, card)
    if not bands:
        raise SystemExit("找不到内容纸卡")
    return {"card": card, "band": bands[0], "bands": bands}


def list_geometry(im: Image.Image) -> dict:
    """05 列表：三条分隔线 + 三行标题的墨迹顶边 → 间距。

    分隔线不是纯 deckLine：#D9D4C9 的 1px 线在 71% 缩放下只覆盖半行像素，
    落屏是 #D9D4C9 与纸色各半（实测 #E6E2D9）。所以判据用「离纸色 8–60 的像素
    占满一行」——文字行是 ≥60 的深墨，纸面是 0，只有分隔线落在这个区间。
    """
    info = paper_card(im)
    card, band = info["card"], info["band"]
    x0, x1 = card["x0"], card["x1"]
    px = im.load()
    line_rows = [
        y for y in range(band[0] + 40, band[1])
        if sum(1 for x in range(x0 + 50, x1 - 50) if 8 < _dist(px[x, y]) < 60) > 300
    ]
    lines = [g[0] for g in groups_of(line_rows, max_gap=0)]
    if len(lines) < 3:
        raise SystemExit(f"纸卡里只找到 {len(lines)} 条分隔线：{lines}")
    titles: list[int] = []
    for ly in lines[:3]:
        top = None
        for y in range(ly + 1, min(ly + 40, band[1])):
            if sum(1 for x in range(x0 + 52, x0 + 280) if _dist(px[x, y]) > 60) >= 3:
                top = y
                break
        if top is None:
            raise SystemExit(f"分隔线 y={ly} 下面找不到条目标题")
        titles.append(top)
    return {
        "card": card,
        "band": band,
        "lines": lines[:3],
        "titles": titles,
        "gaps": [t - l for t, l in zip(titles, lines[:3])],
        "title_spacing": [b - a for a, b in zip(titles, titles[1:])],
        "line_spacing": [b - a for a, b in zip(lines[:3], lines[1:3])],
    }


def header_right_ink(im: Image.Image, x1: int, y_top: int, height: int = 40, dark: bool = False):
    """封面/纸卡右上角的页码墨迹 bbox（取右上角那一小块，避开左侧小标）。"""
    try:
        bbox, _bg = ink_bbox(im, (x1 - 150, y_top + 6, x1 - 4, y_top + 6 + height), thresh=25 if dark else 18)
    except SystemExit:
        return None
    return bbox


def dialog_box(im: Image.Image) -> tuple[int, int, int, int]:
    """弹层（Dialog）的矩形：画面上唯一没被 scrim 压暗的纸色区域。"""
    px = im.load()
    ax = ay = None
    for y in range(im.height):
        for x in range(im.width):
            if near(px[x, y], PAPER, 2):
                ax, ay = x, y
                break
        if ax is not None:
            break
    if ax is None:
        raise SystemExit("找不到弹层")
    x_end = ax
    while x_end < im.width and _dist(px[x_end, ay + 6]) < 4:
        x_end += 1
    y_end = ay
    while y_end < im.height and _dist(px[ax + 6, y_end]) < 4:
        y_end += 1
    return ax, ay, x_end, y_end


def modal_headers(im: Image.Image) -> dict:
    """弹层两张缩略图页眉行里的墨迹分组 → 左边小标 + 右边页码。

    页眉行是弹层里第一条「窄幅多段」的墨迹带：标题「修改前后对比」在 y≈250，
    「修改前 版本 1」在 y≈325，缩略图页眉在 y≈366。这里按 x 分组取左右两端。
    """
    ax, ay, ax1, ay1 = dialog_box(im)
    px = im.load()
    rows = [
        y for y in range(ay + 100, ay + 260)
        if sum(1 for x in range(ax, min(ax1, ax + 900)) if _dist(px[x, y]) > 60) > 3
    ]
    bands = groups_of(rows, max_gap=1)
    if not bands:
        raise SystemExit("弹层里找不到缩略图页眉")
    # 「修改前 版本 1」那一行也有 4 段墨迹，但全在左半边；缩略图页眉的页码一直顶到
    # 右缩略图右边（x > ax+700），用它把两条带区分开。
    mid = (ax + ax1) // 2
    band = groups = None
    for b in bands:
        yy = (b[0] + b[1]) // 2
        xs = [x for x in range(ax, min(ax1, ax + 920)) if _dist(px[x, yy]) > 60]
        g = groups_of(xs, max_gap=20)
        if len(g) >= 4 and g[-1][1] > ax + 700:
            band, groups = b, g
            break
    if band is None or groups is None:
        raise SystemExit(f"弹层里没找到带页码的缩略图页眉：{bands}")
    left = [g for g in groups if g[1] <= mid]
    right = [g for g in groups if g[0] > mid]
    if not left or not right:
        raise SystemExit(f"弹层两张缩略图没分到左右两半：{groups}")
    return {
        "dialog": [ax, ay, ax1, ay1],
        "header_band": [band[0], band[1]],
        "before": {"label": left[0], "number": left[-1]},
        "after": {"label": right[0], "number": right[-1]},
    }


def toast_dark(im: Image.Image) -> int:
    x0, y0, x1, y1 = TOAST_BAND
    px = im.load()
    return sum(
        1
        for y in range(y0, y1)
        for x in range(x0, x1)
        if _dist(px[x, y]) > 100
    )


def pill_span(im: Image.Image, y: int, cx: float, x0: int = 740, x1: int = 1040) -> tuple[int, int] | None:
    px = im.load()
    xs = [x for x in range(x0, x1) if _dist(px[x, y]) > 6]
    for a, b in groups_of(xs, max_gap=6):
        if a <= cx < b:
            return a, b
    return None


# ---------------------------------------------------------------- main
def main() -> None:
    build_md5 = check_served_matches_disk()
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "BUILD_HASH"), "w", encoding="utf-8") as fh:
        fh.write(build_md5 + "\n")

    proc, _info = start_chrome()
    lines: list[str] = []
    positions: dict[str, list[float]] = {}
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json/list", timeout=5) as r:
            targets = [t for t in json.load(r) if t.get("type") == "page"]
        cdp = CDP(targets[0]["webSocketDebuggerUrl"])
        cdp.open_page("about:blank")

        # ------------------------------------------------ ① 05 浅色 · 默认缩放（版本 2 列表）
        cdp.navigate(route(BASE, "workspace"))
        cdp.assert_app()
        print("语义树：", enable_semantics(cdp))
        time.sleep(1.0)
        sem = cdp.eval(SEM_TEXT)
        page_labels = [t for t in (sem or []) if t.startswith("t0 / ")]
        lines.append(
            "语义树里读到的页码节点（源码只有 _deckPageLabel 一处拼字符串）："
            + "；".join(f"「{t}」" for t in page_labels)
        )
        cdp.move(*IDLE_POINT)
        time.sleep(0.8)
        light_png = save("05_workspace_light.png", cdp.shot_bytes())
        light = to_image(light_png)
        geo = list_geometry(light)
        positions["05:card"] = [geo["card"]["x0"], geo["card"]["x1"], geo["band"][0], geo["band"][1]]
        positions["05:lines"] = geo["lines"]
        positions["05:titles"] = geo["titles"]
        lines.append(
            f"05 纸卡列表（{geo['card']['x1'] - geo['card']['x0']}px 宽，卡 y={geo['band'][0]}..{geo['band'][1]}）："
            f"三条分隔线 y={geo['lines']}（线间距 {geo['line_spacing']}），"
            f"三行标题墨迹顶边 y={geo['titles']}（行距 {geo['title_spacing']}）"
        )
        lines.append(
            f"线 → 标题的间距 = {geo['gaps']} px（要求三条一致且 7±1；v11 基线是 16 / 7 / 7）"
        )
        # 卡底 → 页脚分隔线仍然 ≥20（r7 的基线，顺手回归一次）
        bg = row_counts(light, DECK_BG, geo["card"]["x0"], geo["card"]["x1"])
        width = geo["card"]["x1"] - geo["card"]["x0"]
        y = geo["band"][1]
        gap = 0
        while y < light.height and bg[y] >= width * 0.8:
            gap += 1
            y += 1
        lines.append(
            f"回归 r7：纸卡底边 y={geo['band'][1]} → 页脚上边框 y={y}，间距 {gap}px（要求 ≥20，v11 是 34）"
        )
        save("05_dividers_2x.png", crop_zoom(light_png, (
            geo["card"]["x0"], geo["lines"][0] - 18,
            geo["card"]["x1"], geo["titles"][-1] + 34,
        ), 2))

        # 页眉页码：舞台纸卡右上角
        stage_ink = header_right_ink(light, geo["card"]["x1"], geo["band"][0])
        if stage_ink is None:
            raise SystemExit("纸卡右上角找不到页码墨迹")
        positions["header_stage"] = list(stage_ink)
        save("header_stage_2x.png", crop_zoom(light_png, (
            stage_ink[0] - 26, stage_ink[1] - 10, geo["card"]["x1"] + 6, stage_ink[3] + 10,
        ), 2))
        lines.append(
            f"舞台纸卡右上角页码墨迹 bbox={list(stage_ink)}，"
            f"宽 {stage_ink[2] - stage_ink[0]}px / 高 {stage_ink[3] - stage_ink[1]}px"
            f"（v11 基线同位置宽 30px，本来就写着 `t0 / 04`）"
        )
        # 深色封面页右上角（同一套写法的第三处）
        crows = row_counts(light, (0x17, 0x21, 0x1F), geo["card"]["x0"], geo["card"]["x1"])
        cover_rows = [yy for yy, n in enumerate(crows) if n >= width * 0.8]
        cover_ink = header_right_ink(light, geo["card"]["x1"], cover_rows[0], dark=True)
        if cover_ink is None:
            raise SystemExit("封面页右上角找不到页码墨迹")
        positions["header_cover"] = list(cover_ink)
        save("header_cover_2x.png", crop_zoom(light_png, (
            cover_ink[0] - 26, cover_ink[1] - 10, geo["card"]["x1"] + 6, cover_ink[3] + 10,
        ), 2))
        lines.append(
            f"深绿封面页右上角页码墨迹 bbox={list(cover_ink)}，"
            f"宽 {cover_ink[2] - cover_ink[0]}px（v11 基线同位置只有 `04`，宽 11px）"
        )

        # ------------------------------------------------ ② 对比弹层：两张缩略图页眉
        click_label(cdp, "前后对比")
        time.sleep(1.2)
        modal_png = save("modal_compare.png", cdp.shot_bytes())
        modal = to_image(modal_png)
        mh = modal_headers(modal)
        positions["modal:before_number"] = list(mh["before"]["number"])
        positions["modal:after_number"] = list(mh["after"]["number"])
        lines.append(
            f"弹层页眉行 y={mh['header_band']}：修改前缩略图页码 x={mh['before']['number']}"
            f"（宽 {mh['before']['number'][1] - mh['before']['number'][0]}px），"
            f"修改后缩略图页码 x={mh['after']['number']}"
            f"（宽 {mh['after']['number'][1] - mh['after']['number'][0]}px）"
        )
        strips = []
        for side in ("before", "after"):
            num = mh[side]["number"]
            lab = mh[side]["label"]
            strips.append(to_image(modal_png).crop((
                lab[0] - 6, mh["header_band"][0] - 8, num[1] + 10, mh["header_band"][1] + 8,
            )))
        pad = 6
        combo = Image.new(
            "RGB",
            (max(s.width for s in strips), sum(s.height for s in strips) + pad * (len(strips) - 1)),
            DECK_BG,
        )
        y_at = 0
        for s in strips:
            combo.paste(s, (0, y_at))
            y_at += s.height + pad
        combo = combo.resize((combo.width * 2, combo.height * 2), Image.NEAREST)
        buf = io.BytesIO()
        combo.save(buf, format="PNG")
        save("header_modal_2x.png", buf.getvalue())
        cdp.call(
            "Input.dispatchKeyEvent", type="keyDown", key="Escape", code="Escape", windowsVirtualKeyCode=27
        )
        cdp.call(
            "Input.dispatchKeyEvent", type="keyUp", key="Escape", code="Escape", windowsVirtualKeyCode=27
        )
        time.sleep(0.8)

        # ------------------------------------------------ ③ press_01：v1 纸卡 · 悬浮（无 toast）
        cdp.navigate(route(BASE, "workspace"))
        cdp.assert_app()
        enable_semantics(cdp)
        time.sleep(0.6)
        t_click = time.time()
        click_label(cdp, "撤销")          # 模块 4 回到 v1（三栏），会弹一条 toast
        time.sleep(0.35)
        ctrl = to_image(cdp.shot_bytes())
        ctrl_dark = toast_dark(ctrl)
        lines.append(
            f"点「撤销」后 0.35s：toast 取样带 {TOAST_BAND} 里深色像素 {ctrl_dark} 个"
            f"（正对照：证明这条检测认得出 toast）"
        )
        # toast 是 2400ms 后移除，这里按 3.2s 等，宁多不少
        remain = 3.2 - (time.time() - t_click)
        if remain > 0:
            time.sleep(remain)
        sem_after = [t for t in (cdp.eval(SEM_TEXT) or []) if t.startswith("t0 / ")]
        state = cdp.eval("""(() => Array.from(document.querySelectorAll('flt-semantics'))
          .map(e => (e.innerText || '').trim().replace(/\\s+/g, ' '))
          .filter(t => t.indexOf('当前为版本') === 0))()""")
        lines.append(f"点「撤销」后状态：语义树「当前为版本…」节点 = {state}；页码节点 {sem_after}")
        rect = cdp.eval(
            """(() => { for (const el of document.querySelectorAll('flt-semantics')) {
                 const t = (el.innerText || '').trim().replace(/\\s+/g, ' ');
                 if (t === '按住看修改前') { const r = el.getBoundingClientRect();
                   return {x: r.x, y: r.y, w: r.width, h: r.height}; } } return null; })()"""
        )
        if not rect:
            raise SystemExit("语义树里找不到「按住看修改前」")
        bx, by = rect["x"] + rect["w"] / 2, rect["y"] + rect["h"] / 2
        positions["press:idle_button"] = [rect["x"], rect["y"], rect["w"], rect["h"]]
        cdp.move(bx, by)
        time.sleep(1.0)
        hover_png = save("press_01_light.png", cdp.shot_bytes())
        hover = to_image(hover_png)
        pill = pill_span(hover, int(rect["y"] + rect["h"] / 2), bx)
        gone_dark = toast_dark(hover)
        if gone_dark:
            raise SystemExit(f"press_01 里 toast 还在：取样带深色像素 {gone_dark} 个")
        if not pill:
            raise SystemExit("press_01 里量不到悬浮胶囊，hover 没生效")
        lines.append(
            f"press_01_light.png：悬停「按住看修改前」胶囊 x={pill[0]}..{pill[1]}"
            f"（宽 {pill[1] - pill[0]}px，hover 生效）；同一取样带深色像素 {gone_dark} 个 → toast 已消失"
        )

        # ------------------------------------------------ ④ 改前基线（v11 同法复量）
        base_ws = os.path.join(BASE_SETS, "05_workspace_light.png")
        if os.path.exists(base_ws):
            bim = to_image(base_ws)
            bgeo = list_geometry(bim)
            lines.append(
                f"改前基线 docs/screenshots_v11/05_workspace_light.png：三条线 y={bgeo['lines']}"
                f"（线间距 {bgeo['line_spacing']}），标题 y={bgeo['titles']}，"
                f"线→标题 = {bgeo['gaps']}"
            )
            bcrows = row_counts(bim, (0x17, 0x21, 0x1F), bgeo["card"]["x0"], bgeo["card"]["x1"])
            bcover_top = [yy for yy, n in enumerate(bcrows)
                          if n >= (bgeo["card"]["x1"] - bgeo["card"]["x0"]) * 0.8][0]
            bcover = header_right_ink(bim, bgeo["card"]["x1"], bcover_top, dark=True)
            if bcover:
                lines.append(
                    f"改前基线 封面页右上角墨迹 bbox={list(bcover)}，宽 {bcover[2] - bcover[0]}px"
                    f"（只有 `04`）→ 现在 {cover_ink[2] - cover_ink[0]}px（`t0 / 04`）"
                )
        base_modal = os.path.join(BASE_SETS, "press_03_compare_modal.png")
        if os.path.exists(base_modal):
            bmh = modal_headers(to_image(base_modal))
            lines.append(
                f"改前基线 docs/screenshots_v11/press_03_compare_modal.png：修改前缩略图页码"
                f" x={bmh['before']['number']}（宽 {bmh['before']['number'][1] - bmh['before']['number'][0]}px，"
                f"只有 `04`）→ 现在 {mh['before']['number'][1] - mh['before']['number'][0]}px"
            )

        text = "\n".join("- " + line for line in lines)
        print("\n" + text)
        with open(os.path.join(OUT, "measurements.txt"), "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
        with open(os.path.join(OUT, "positions.json"), "w", encoding="utf-8") as fh:
            json.dump(positions, fh, ensure_ascii=False, indent=2)
        publish()
    except BaseException as exc:
        print(f"[失败] {type(exc).__name__}: {exc}")
        text = "\n".join("- " + line for line in lines)
        print(text)
        os.makedirs(OUT, exist_ok=True)
        with open(os.path.join(OUT, "measurements.txt"), "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
        raise
    finally:
        proc.kill()


if __name__ == "__main__":
    main()
