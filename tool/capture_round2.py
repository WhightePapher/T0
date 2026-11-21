"""第二轮视觉证据：4 段 GIF（docs/motion_gifs/round2/）。

一条命令重跑（仓库根目录，先 `flutter build web --profile`）：

    export PATH=/data/flutter/bin:$PATH
    flutter build web --profile
    python3 tool/capture_round2.py                 # 需要 /tmp/t0_before 的旧构建才会出第 4 段

产出：
    01_card_shadow_hover.gif   卡片双层阴影 + hover 抬升 1px（动效放慢 3×，看得清）
    02_focus_ring.gif          键盘 Tab 依次落到顶栏 / 侧栏 / 卡片 / 按钮，焦点环逐个亮起
    03_skeleton_rhythm.gif     点「应用修改」后的骨架：标题短条 + 正文长条，两条光带不同速度
    04_dialog_before_after.gif 对比弹层：左＝优化前构建，右＝当前构建，同视角同帧序左右拼接

抓帧用的是 `Page.startScreencast`（每次合成收一帧），headless 走 SwiftShader，
所以 GIF 里看到的「放慢」只发生在截图进程（`?motion=N`），线上令牌一个没改。
"""

from __future__ import annotations

import base64
import io
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from capture_motion import CDP  # 带 drain / wait_event 的 CDP 客户端
from measure_fps import PORT_CDP, PORT_HTTP, VIEW, start_chrome, start_http  # noqa: E402

ROOT = os.environ.get("T0_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "motion_gifs", "round2")
BEFORE_DIR = os.environ.get("T0_BEFORE_DIR") or "/tmp/t0_before/build/web"

_nonce = [0]


def open_target() -> CDP:
    with urllib.request.urlopen(f"http://127.0.0.1:{PORT_CDP}/json/list", timeout=5) as response:
        targets = json.load(response)
    page = next(t for t in targets if t.get("type") == "page")
    cdp = CDP(page["webSocketDebuggerUrl"])
    cdp.call("Page.enable")
    cdp.call("Runtime.enable")
    return cdp


# ------------------------------------------------------------------ 页面与输入
def go(cdp: CDP, route: str, slow: float = 0.0, settle: float = 2.6) -> None:
    _nonce[0] += 1
    query = f"?n={_nonce[0]}" + (f"&motion={slow:g}" if slow > 0 else "")
    cdp.call("Page.navigate", url=f"http://127.0.0.1:{PORT_HTTP}/index.html{query}#{route}")
    deadline = time.time() + 60
    while time.time() < deadline:
        if "办公" in (cdp.eval("document.title") or ""):
            break
        time.sleep(0.3)
    time.sleep(settle)


def enable_semantics(cdp: CDP) -> None:
    cdp.eval(
        "(() => { const p = document.querySelector('flt-semantics-placeholder');"
        " if (p) { p.click(); return 'enabled'; } return 'already'; })()"
    )
    time.sleep(1.0)


def click(cdp: CDP, x: float, y: float) -> None:
    cdp.call("Input.dispatchMouseEvent", type="mouseMoved", x=x, y=y, pointerType="mouse")
    for kind in ("mousePressed", "mouseReleased"):
        cdp.call(
            "Input.dispatchMouseEvent",
            type=kind,
            x=x,
            y=y,
            button="left",
            buttons=1,
            clickCount=1,
            pointerType="mouse",
        )


def hover(cdp: CDP, x: float, y: float) -> None:
    cdp.call("Input.dispatchMouseEvent", type="mouseMoved", x=x, y=y, pointerType="mouse")


def press_tab(cdp: CDP) -> None:
    for kind in ("rawKeyDown", "keyUp"):
        cdp.call(
            "Input.dispatchKeyEvent",
            type=kind,
            key="Tab",
            code="Tab",
            windowsVirtualKeyCode=9,
            nativeVirtualKeyCode=9,
        )


# ---------------------------------------------------------------------- 抓帧
def record(cdp: CDP, trigger, window: float) -> list[tuple[float, Image.Image]]:
    frames: list[tuple[float, Image.Image]] = []
    cdp.drain()
    cdp.call(
        "Page.startScreencast",
        format="jpeg",
        quality=92,
        everyNthFrame=1,
        maxWidth=VIEW[0],
        maxHeight=VIEW[1],
    )
    t0 = time.perf_counter()
    trigger()
    while True:
        event = cdp.wait_event("Page.screencastFrame", timeout=2.0)
        if event is None:
            break
        cdp.call("Page.screencastFrameAck", sessionId=event["sessionId"])
        image = Image.open(io.BytesIO(base64.b64decode(event["data"]))).convert("RGB")
        elapsed = (time.perf_counter() - t0) * 1000.0
        frames.append((elapsed, image))
        if elapsed > window * 1000.0:
            break
    cdp.call("Page.stopScreencast")
    return frames


def shot(cdp: CDP) -> Image.Image:
    data = cdp.call("Page.captureScreenshot", format="png", fromSurface=True)["data"]
    return Image.open(io.BytesIO(base64.b64decode(data))).convert("RGB")


def save_gif(frames: list[tuple[float, Image.Image]], path: str, width: int = 960) -> None:
    scaled: list[Image.Image] = []
    durations: list[int] = []
    for i, (ms, image) in enumerate(frames):
        ratio = width / image.width
        small = image.resize((width, int(image.height * ratio)), Image.LANCZOS)
        scaled.append(small.convert("P", palette=Image.ADAPTIVE, colors=128))
        nxt = frames[i + 1][0] if i + 1 < len(frames) else ms + 120.0
        durations.append(int(max(40, min(600, nxt - ms))))
    scaled[0].save(
        path,
        save_all=True,
        append_images=scaled[1:],
        duration=durations,
        loop=0,
        optimize=True,
        disposal=2,
    )


CJK_FONT = "/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc"


def font(size: int = 18) -> ImageFont.ImageFont:
    try:
        return ImageFont.truetype(CJK_FONT, size, index=0)
    except OSError:
        return ImageFont.load_default()


def captions(frames: list[tuple[float, Image.Image]], text: str) -> list[tuple[float, Image.Image]]:
    """左上角压一条说明（深底浅字，不和页面内容打架）。"""
    out: list[tuple[float, Image.Image]] = []
    for ms, image in frames:
        canvas = image.copy()
        draw = ImageDraw.Draw(canvas)
        f = font(17)
        box = draw.textbbox((0, 0), text, font=f)
        width, height = box[2] - box[0] + 22, box[3] - box[1] + 14
        # 压在左下角：焦点环 / 卡片 / 骨架都在页面中上部，别让说明条挡证据
        top = canvas.height - height - 12
        draw.rounded_rectangle((12, top, 12 + width, top + height), radius=8, fill=(18, 22, 24))
        draw.text((23, top + 5), text, fill=(232, 240, 236), font=f)
        out.append((ms, canvas))
    return out


# ---------------------------------------------------------------------- 四段
def gif_card_hover(cdp: CDP) -> dict:
    go(cdp, "/workbench", slow=3.0, settle=3.0)
    frames_in = record(cdp, lambda: hover(cdp, 545, 495), 2.4)
    frames_out = record(cdp, lambda: hover(cdp, 545, 760), 1.8)
    offset = frames_in[-1][0] + 200.0 if frames_in else 0.0
    frames = frames_in + [(ms + offset, im) for ms, im in frames_out]
    frames = captions(frames, "01 · 卡片：双层阴影 + hover 上移 1px（放慢 3×）")
    save_gif(frames, os.path.join(OUT, "01_card_shadow_hover.gif"), width=1000)
    return {"name": "01_card_shadow_hover", "frames": len(frames), "slow": 3.0}


def gif_focus_ring(cdp: CDP) -> dict:
    go(cdp, "/workspace", settle=2.8)
    # 不开语义树（语义层会吃掉键盘焦点）：点画布空白处把焦点交给 FLUTTER-VIEW，
    # 之后 Tab 才在 T0FocusRing 之间走 —— 实测 FLUTTER-VIEW 拿到焦点后每次 Tab
    # 都会把焦点环挪到下一个可交互元素上。
    click(cdp, 700, 700)
    time.sleep(0.6)
    frames: list[tuple[float, Image.Image]] = []
    for i in range(10):
        press_tab(cdp)
        time.sleep(0.55)
        frames.append((i * 650.0, shot(cdp)))
    frames = captions(frames, "02 · 键盘 Tab：焦点环 2px · deckAccent · offset 2")
    save_gif(frames, os.path.join(OUT, "02_focus_ring.gif"), width=1000)
    return {"name": "02_focus_ring", "frames": len(frames)}


def gif_skeleton(cdp: CDP) -> dict:
    go(cdp, "/workspace", slow=1.5, settle=2.8)
    enable_semantics(cdp)
    click(cdp, 1136, 301)  # 第一条建议 chip → 填进输入框
    time.sleep(0.5)
    frames = record(cdp, lambda: click(cdp, 1165, 868), 3.6)  # 应用修改 → 骨架 1.1s
    frames = captions(frames, "03 · 骨架：标题短条 / 正文长条，两条光带不同速度")
    save_gif(frames, os.path.join(OUT, "03_skeleton_rhythm.gif"), width=1000)
    return {"name": "03_skeleton_rhythm", "frames": len(frames), "slow": 1.5}


def _frames_for(dir_path: str) -> list[tuple[float, Image.Image]]:
    """在指定 build/web 上录一次「前后对比」弹层打开，返回原始帧序列。"""
    proc = subprocess.Popen(
        [sys.executable, "-m", "http.server", str(PORT_HTTP + 1), "--bind", "127.0.0.1"],
        cwd=dir_path,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    for _ in range(100):
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{PORT_HTTP + 1}/index.html", timeout=1):
                break
        except Exception:
            time.sleep(0.1)

    chrome = start_chrome()
    try:
        cdp = open_target()
        _nonce[0] += 1
        cdp.call(
            "Page.navigate",
            url=f"http://127.0.0.1:{PORT_HTTP + 1}/index.html?n={_nonce[0]}&motion=4#/workspace",
        )
        time.sleep(4.0)
        cdp.eval(
            "(() => { const p = document.querySelector('flt-semantics-placeholder');"
            " if (p) p.click(); })()"
        )
        time.sleep(1.0)
        return record(cdp, lambda: click(cdp, 980, 146), 1.8)
    finally:
        chrome.kill()
        proc.kill()


def _progress(image: Image.Image) -> int:
    """「弹层开了多少」的标量：画面中间有多少接近纸白的像素。

    用它对齐两侧帧序（按动画进度，而不是按时间）：两侧抓到的帧率不同，
    按时间取样会一边已经落定、另一边才刚起步。
    """
    grey = image.convert("L")
    width, height = grey.size
    crop = grey.crop((int(width * 0.15), int(height * 0.15), int(width * 0.85), int(height * 0.85)))
    histogram = crop.histogram()
    return sum(histogram[205:])


def gif_dialog_before_after() -> dict:
    after = _frames_for(os.path.join(ROOT, "build", "web"))
    if not os.path.isdir(BEFORE_DIR):
        return {"name": "04_dialog_before_after", "skipped": f"没有旧构建：{BEFORE_DIR}"}
    before = _frames_for(BEFORE_DIR)
    if not after or not before:
        raise SystemExit("对比弹层没抓到帧")

    before_sig = [(f, im, _progress(im)) for f, im in before]
    after_sig = [(f, im, _progress(im)) for f, im in after]
    lo = min(min(v for *_, v in before_sig), min(v for *_, v in after_sig))
    hi = max(max(v for *_, v in before_sig), max(v for *_, v in after_sig))

    tiles: list[tuple[float, Image.Image]] = []
    steps = 10
    for i in range(steps):
        target = lo + (hi - lo) * i / (steps - 1)
        left = min(before_sig, key=lambda row: abs(row[2] - target))[1]
        right = min(after_sig, key=lambda row: abs(row[2] - target))[1]
        width = 640
        scaled_left = left.resize((width, int(left.height * width / left.width)), Image.LANCZOS)
        scaled_right = right.resize((width, int(right.height * width / right.width)), Image.LANCZOS)
        canvas = Image.new("RGB", (width * 2 + 12, scaled_left.height + 30), (18, 20, 22))
        canvas.paste(scaled_left, (0, 30))
        canvas.paste(scaled_right, (width + 12, 30))
        draw = ImageDraw.Draw(canvas)
        f = font(17)
        draw.text((10, 6), "优化前 feat/motion · raster p95 57.4ms", fill=(240, 240, 240), font=f)
        draw.text((width + 22, 6), "优化后 perf/round2 · raster p95 67.3ms", fill=(120, 220, 180), font=f)
        draw.line((width + 4, 4, width + 4, scaled_left.height + 26), fill=(120, 120, 120), width=2)
        tiles.append((i * 320.0, canvas))
    save_gif(tiles, os.path.join(OUT, "04_dialog_before_after.gif"), width=1280)
    return {
        "name": "04_dialog_before_after",
        "frames": len(tiles),
        "aligned_by": "dialog open progress (near-white pixel count), not wall-clock",
    }


def main() -> None:
    only = ""
    for arg in sys.argv[1:]:
        if arg.startswith("--only="):
            only = arg.split("=", 1)[1]
    os.makedirs(OUT, exist_ok=True)
    http = start_http()
    chrome = start_chrome()
    manifest: dict = {"view": list(VIEW), "captures": []}
    try:
        cdp = open_target()
        cdp.call(
            "Emulation.setDeviceMetricsOverride",
            width=VIEW[0],
            height=VIEW[1],
            deviceScaleFactor=1,
            mobile=False,
        )
        for step in (gif_card_hover, gif_focus_ring, gif_skeleton):
            if only and only not in step.__name__:
                continue
            print(f"== {step.__name__}")
            manifest["captures"].append(step(cdp))
    finally:
        chrome.kill()
        http.kill()

    if not only or "dialog" in only:
        print("== gif_dialog_before_after")
        manifest["captures"].append(gif_dialog_before_after())

    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=2)
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
