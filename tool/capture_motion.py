"""动效帧证据：release build/web + headless chromium（CDP 逐帧）+ PIL 拼 GIF。

一条命令重跑（仓库根目录，先构建一次）：

    flutter build web --release
    xvfb-run -a python3 tool/capture_motion.py

产出（docs/motion_gifs/）：
    01_workbench_cards.gif / .png       工作台项目卡错峰入场（fade + 上移 8px，i*45ms）
    02_workspace_crossfade.gif / .png   工作区「撤销」→ 画布 cross-fade 150ms + 4px 上移
    03_compare_dialog.gif / .png        前后对比弹层 scale 0.94→1 + 两页依次滑入
    04_delivery_check.gif / .png        交付检查逐条打勾（stagger 60ms）+ 导出成功弹层
    stills/{route}_{1440x900,500x900}.png  六个界面两档尺寸的静止态
    stills/drift.json                   每张静止态的「隔 400ms 再拍」像素差（0 = 不动）
    manifest.json                       每段抓帧的时间戳、帧数、放慢倍数、viewer 尺寸

两点说明：

1. 抓帧用 `Page.startScreencast`（每次合成出一帧就收一帧），比循环
   `Page.captureScreenshot` 快得多；拿不到帧时自动退回截图轮询。
2. 动画页用 `?motion=6` 打开 —— headless chromium 走 SwiftShader，一次合成要
   80–140ms，150ms 的 cross-fade 只够抓 1–2 帧，放慢 6 倍才够 8 帧 contact sheet。
   放慢只发生在截图进程里（`T0Motion.captureScale`），令牌值 / 曲线一行没改；
   GIF 的播放速度因此是真实速度的 1/6，清单里给出的是真实时长。
3. 静止态图拍完立刻用 `Emulation.setEmulatedMedia(prefers-reduced-motion: reduce)`
   再拍两张（间隔 400ms）比对像素差：0 就证明没有布局位移 / 1px 抖动，
   同时顺手在真实浏览器里验了「减弱动效」这条路。
"""

from __future__ import annotations

import base64
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
from collections import deque

from PIL import Image, ImageChops, ImageDraw
from websockets.sync.client import connect

ROOT = os.environ.get("T0_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.environ.get("T0_OUT") or os.path.join(ROOT, "docs", "motion_gifs")
STILLS = os.path.join(OUT, "stills")
PORT_HTTP = 8131
PORT_CDP = 9337
VIEW = (1440, 900)
MOBILE = (500, 900)

# 抓帧放慢倍数：见文件头第 2 条。headless 一次合成 120–200ms，
# 150ms 的 cross-fade 要放到 16 倍才够 8 帧，320ms 的入场 6 倍就够。
SLOW_CARDS = 6.0
SLOW_CROSSFADE = 16.0
SLOW_DIALOG = 10.0
SLOW_DELIVERY = 6.0

PAGES = ("/workbench", "/intake", "/outline", "/modules", "/workspace", "/delivery")


# --------------------------------------------------------------------------- CDP
class CDP:
    def __init__(self, ws_url: str) -> None:
        self.ws = connect(ws_url, max_size=None, open_timeout=30)
        self.events: deque = deque()
        self.next_id = 0

    def call(self, method: str, **params):
        self.next_id += 1
        mid = self.next_id
        self.ws.send(json.dumps({"id": mid, "method": method, "params": params}))
        while True:
            msg = json.loads(self.ws.recv(timeout=30))
            if msg.get("id") == mid:
                if "error" in msg:
                    raise RuntimeError(f"{method}: {msg['error']}")
                return msg.get("result", {})
            self.events.append(msg)

    def eval(self, expression: str):
        res = self.call("Runtime.evaluate", expression=expression, returnByValue=True)
        return (res.get("result") or {}).get("value")

    def wait_event(self, method: str, timeout: float):
        deadline = time.time() + timeout
        while True:
            for i, event in enumerate(self.events):
                if event.get("method") == method:
                    del self.events[i]
                    return event["params"]
            left = deadline - time.time()
            if left <= 0:
                return None
            try:
                msg = json.loads(self.ws.recv(timeout=left))
            except TimeoutError:
                return None
            if "id" in msg:
                continue
            self.events.append(msg)

    def drain(self) -> None:
        self.events.clear()


def start_http() -> subprocess.Popen:
    proc = subprocess.Popen(
        [sys.executable, "-m", "http.server", str(PORT_HTTP), "--bind", "127.0.0.1"],
        cwd=os.path.join(ROOT, "build", "web"),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    for _ in range(100):
        try:
            with urllib.request.urlopen(
                f"http://127.0.0.1:{PORT_HTTP}/index.html", timeout=1
            ) as r:
                if r.status == 200:
                    return proc
        except Exception:
            time.sleep(0.1)
    proc.kill()
    raise SystemExit("静态服务没起来（build/web 里没有 index.html？先 flutter build web --release）")


def find_chromium() -> str:
    for name in ("chromium", "chromium-browser", "google-chrome", "chrome"):
        path = shutil.which(name)
        if path:
            return path
    raise SystemExit("找不到 chromium（apt install chromium，或把 chrome 放进 PATH）")


def start_chrome() -> subprocess.Popen:
    profile = os.path.join(tempfile.gettempdir(), "t0-motion-chrome")
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
    return cdp


def set_view(cdp: CDP, size: tuple[int, int]) -> None:
    cdp.call(
        "Emulation.setDeviceMetricsOverride",
        width=size[0],
        height=size[1],
        deviceScaleFactor=1,
        mobile=False,
    )
    cdp.call("Emulation.setTouchEmulationEnabled", enabled=False)


def set_reduced_motion(cdp: CDP, on: bool) -> None:
    features = [{"name": "prefers-reduced-motion", "value": "reduce" if on else "no-preference"}]
    cdp.call("Emulation.setEmulatedMedia", features=features)


# ------------------------------------------------------------------ 页面与点击
_nonce = [0]


def go(cdp: CDP, route: str, settle: float = 2.6, slow: float = 0.0) -> None:
    """每次带不同查询串：只改 hash 是 same-document 跳转，Flutter 不会重启。"""
    _nonce[0] += 1
    query = f"?n={_nonce[0]}" + (f"&motion={slow:g}" if slow > 0 else "")
    url = f"http://127.0.0.1:{PORT_HTTP}/index.html{query}#{route}"
    cdp.call("Page.navigate", url=url)
    deadline = time.time() + 60
    while time.time() < deadline:
        title = cdp.eval("document.title") or ""
        if "办公" in title:
            break
        time.sleep(0.3)
    time.sleep(settle)


ENABLE_SEMANTICS = """(() => {
  const p = document.querySelector('flt-semantics-placeholder');
  if (p) { p.click(); return 'enabled'; }
  return 'already';
})()"""

# 语义树的 innerText 是可读的（CanvasKit 只是不把文字画成 DOM），
# 但 flt-semantics 的 getBoundingClientRect 在这套 headless 上是错的
# （按它点会点到别处）。所以：文字用来**断言**，点击用 1440×900 下的实测像素。
HAS_TEXT = """(() => {
  const want = %s;
  for (const el of document.querySelectorAll('flt-semantics')) {
    const text = (el.innerText || '').trim().replace(/\\s+/g, ' ');
    if (text.indexOf(want) >= 0) return true;
  }
  return false;
})()"""

LIST_BUTTONS = """(() => Array.from(document.querySelectorAll('flt-semantics[role="button"]'))
  .map(e => (e.innerText || '').trim().replace(/\\s+/g, ' '))
  .filter(t => t.length > 0).join(' | '))()"""


def enable_semantics(cdp: CDP) -> None:
    cdp.eval(ENABLE_SEMANTICS)
    time.sleep(1.2)


def has_text(cdp: CDP, needle: str) -> bool:
    return bool(cdp.eval(HAS_TEXT % json.dumps(needle, ensure_ascii=False)))


def click(cdp: CDP, x: float, y: float) -> None:
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


def click_expect(cdp: CDP, label: str, x: float, y: float, expect: str, timeout: float = 3.0) -> None:
    """按屏幕坐标点一个按钮，再用语义树里的文字确认真的点到了。"""
    click(cdp, x, y)
    deadline = time.time() + timeout
    while time.time() < deadline:
        if has_text(cdp, expect):
            return
        time.sleep(0.1)
    raise SystemExit(
        f"点了「{label}」@({x},{y}) 之后没等到「{expect}」；现有按钮：{cdp.eval(LIST_BUTTONS)}"
    )


# ---------------------------------------------------------------------- 抓帧
def record(cdp: CDP, trigger, window: float) -> list[tuple[float, Image.Image]]:
    """触发一次交互，按合成帧抓 [0, window] 内的画面，返回 [(ms, image)]。"""
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
        data = base64.b64decode(event["data"])
        elapsed = (time.perf_counter() - t0) * 1000.0
        frames.append((elapsed, Image.open(io.BytesIO(data)).convert("RGB")))
        if elapsed > window * 1000.0:
            break
    cdp.call("Page.stopScreencast")

    if len(frames) >= 4:
        return frames

    # 退回截图轮询
    frames = []
    t0 = time.perf_counter()
    trigger()
    while True:
        data = cdp.call("Page.captureScreenshot", format="png", fromSurface=True)["data"]
        elapsed = (time.perf_counter() - t0) * 1000.0
        frames.append((elapsed, Image.open(io.BytesIO(base64.b64decode(data))).convert("RGB")))
        if elapsed > window * 1000.0:
            break
    return frames


def pick(frames: list[tuple[float, Image.Image]], count: int) -> list[tuple[float, Image.Image]]:
    """在整段窗口里按时间等距挑 count 帧（取最近的一帧、去重）。"""
    if not frames:
        raise SystemExit("一帧都没抓到")
    last = frames[-1][0]
    picked: list[tuple[float, Image.Image]] = []
    used: set[int] = set()
    for i in range(count):
        target = last * i / (count - 1) if count > 1 else 0.0
        best = min(range(len(frames)), key=lambda k: abs(frames[k][0] - target))
        if best in used:
            continue
        used.add(best)
        picked.append(frames[best])
    return picked


def save_gif(frames: list[tuple[float, Image.Image]], path: str, width: int = 960) -> None:
    scaled: list[Image.Image] = []
    durations: list[int] = []
    for i, (ms, image) in enumerate(frames):
        ratio = width / image.width
        small = image.resize((width, int(image.height * ratio)), Image.LANCZOS)
        scaled.append(small.convert("P", palette=Image.ADAPTIVE, colors=128))
        nxt = frames[i + 1][0] if i + 1 < len(frames) else ms + 90.0
        durations.append(int(max(30, min(400, nxt - ms))))
    scaled[0].save(
        path,
        save_all=True,
        append_images=scaled[1:],
        duration=durations,
        loop=0,
        optimize=True,
        disposal=2,
    )


def save_sheet(
    frames: list[tuple[float, Image.Image]],
    path: str,
    cols: int = 4,
    width: int = 480,
    slow: float = 1.0,
) -> None:
    tiles: list[Image.Image] = []
    for ms, image in frames:
        ratio = width / image.width
        tile = image.resize((width, int(image.height * ratio)), Image.LANCZOS)
        canvas = Image.new("RGB", (tile.width, tile.height + 20), (24, 26, 28))
        canvas.paste(tile, (0, 20))
        ImageDraw.Draw(canvas).text((6, 4), f"{ms:7.1f} ms (1/{slow:g} 速)", fill=(230, 230, 230))
        tiles.append(canvas)
    rows = (len(tiles) + cols - 1) // cols
    cell_w, cell_h = tiles[0].width, tiles[0].height
    sheet = Image.new("RGB", (cell_w * cols, cell_h * rows), (12, 13, 14))
    for i, tile in enumerate(tiles):
        sheet.paste(tile, ((i % cols) * cell_w, (i // cols) * cell_h))
    sheet.save(path)


def shot(cdp: CDP) -> Image.Image:
    data = cdp.call("Page.captureScreenshot", format="png", fromSurface=True)["data"]
    return Image.open(io.BytesIO(base64.b64decode(data))).convert("RGB")


# ------------------------------------------------------------------------ 主流程
def capture_all(cdp: CDP) -> dict:
    manifest: dict = {"view": list(VIEW), "captures": []}
    os.makedirs(OUT, exist_ok=True)

    # ① 工作台卡片错峰入场：先从别的页回来，让工作台整页重建（maintainState: false）
    go(cdp, "/intake", slow=SLOW_CARDS)
    frames = record(cdp, lambda: cdp.eval("location.hash='#/workbench'"), 4.0)
    save_gif(frames, os.path.join(OUT, "01_workbench_cards.gif"))
    save_sheet(pick(frames, 10), os.path.join(OUT, "01_workbench_cards.png"), slow=SLOW_CARDS)
    manifest["captures"].append(
        {
            "name": "01_workbench_cards",
            "slow_factor": SLOW_CARDS,
            "window_ms": round(frames[-1][0], 1),
            "frames": len(frames),
            "real_ms": round(frames[-1][0] / SLOW_CARDS, 1),
        }
    )

    # ② 工作区撤销 → 画布 cross-fade（v2 → v1，150ms）
    #    按钮坐标是 1440×900 下的实测值：撤销图标 (749,146)，见 stills/workspace_1440x900.png
    go(cdp, "/workspace", slow=SLOW_CROSSFADE)
    enable_semantics(cdp)
    frames = record(
        cdp,
        lambda: click_expect(cdp, "撤销", 749, 146, "已撤销上一次修改"),
        2.9,
    )
    save_gif(frames, os.path.join(OUT, "02_workspace_crossfade.gif"))
    save_sheet(pick(frames, 8), os.path.join(OUT, "02_workspace_crossfade.png"), slow=SLOW_CROSSFADE)
    manifest["captures"].append(
        {
            "name": "02_workspace_crossfade",
            "slow_factor": SLOW_CROSSFADE,
            "window_ms": round(frames[-1][0], 1),
            "frames": len(frames),
            "real_ms": round(frames[-1][0] / SLOW_CROSSFADE, 1),
        }
    )

    # ③ 前后对比弹层：scale 0.94→1 + 两页依次滑入（220ms；「前后对比」胶囊在 (980,146)）
    go(cdp, "/workspace", slow=SLOW_DIALOG)
    enable_semantics(cdp)
    frames = record(
        cdp,
        lambda: click_expect(cdp, "前后对比", 980, 146, "回到上一版"),
        2.6,
    )
    save_gif(frames, os.path.join(OUT, "03_compare_dialog.gif"))
    save_sheet(pick(frames, 8), os.path.join(OUT, "03_compare_dialog.png"), slow=SLOW_DIALOG)
    manifest["captures"].append(
        {
            "name": "03_compare_dialog",
            "slow_factor": SLOW_DIALOG,
            "window_ms": round(frames[-1][0], 1),
            "frames": len(frames),
            "real_ms": round(frames[-1][0] / SLOW_DIALOG, 1),
        }
    )

    # ④ 交付检查逐条打勾（60ms 错峰 + 300ms 描线）+ 导出成功弹层（导出按钮在 (1276,806)）
    go(cdp, "/workspace", slow=SLOW_DELIVERY)
    enable_semantics(cdp)
    frames_check = record(cdp, lambda: cdp.eval("location.hash='#/delivery'"), 4.4)
    frames_export = record(
        cdp,
        # 成功态出现「继续检查」= 弹层确实开到了最后一步（生成 2s + 220ms 成功入场）
        lambda: click_expect(cdp, "导出", 1276, 806, "继续检查", timeout=8.0),
        5.2,
    )
    frames = frames_check + [(ms + frames_check[-1][0] + 300.0, im) for ms, im in frames_export]
    save_gif(frames, os.path.join(OUT, "04_delivery_check.gif"))
    save_sheet(pick(frames, 10), os.path.join(OUT, "04_delivery_check.png"), slow=SLOW_DELIVERY)
    manifest["captures"].append(
        {
            "name": "04_delivery_check",
            "slow_factor": SLOW_DELIVERY,
            "window_ms": round(frames[-1][0], 1),
            "frames": len(frames),
            "real_ms": round(frames[-1][0] / SLOW_DELIVERY, 1),
        }
    )
    return manifest


def capture_stills(cdp: CDP, manifest: dict) -> None:
    os.makedirs(STILLS, exist_ok=True)
    drift: dict = {}
    for size, tag in ((VIEW, "1440x900"), (MOBILE, "500x900")):
        set_view(cdp, size)
        for route in PAGES:
            go(cdp, route, settle=2.4)
            still = shot(cdp)
            name = f"{route.strip('/') or 'root'}_{tag}.png"
            still.save(os.path.join(STILLS, name))

            # 减弱动效：循环动画（呼吸点 / shimmer）应全部静止 → 两张图必须逐像素相同
            set_reduced_motion(cdp, True)
            time.sleep(0.5)
            first = shot(cdp)
            time.sleep(0.4)
            second = shot(cdp)
            diff = ImageChops.difference(first, second)
            drift[name] = sum(1 for px in diff.getdata() if px != (0, 0, 0))
            set_reduced_motion(cdp, False)
    with open(os.path.join(STILLS, "drift.json"), "w", encoding="utf-8") as fh:
        json.dump(drift, fh, ensure_ascii=False, indent=2)
    manifest["stills_drift_pixels_reduced_motion"] = drift


def main() -> None:
    # `--stills-only`：只出静止态（给「改造前后逐像素对比」用，见 docs/动效清单.md）
    stills_only = "--stills-only" in sys.argv
    http = start_http()
    chrome = start_chrome()
    try:
        cdp = open_target()
        set_view(cdp, VIEW)
        cdp.call("Page.navigate", url=f"http://127.0.0.1:{PORT_HTTP}/index.html")
        time.sleep(3.0)
        manifest = {"view": list(VIEW), "captures": []} if stills_only else capture_all(cdp)
        capture_stills(cdp, manifest)
        with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, ensure_ascii=False, indent=2)
        print(json.dumps(manifest, ensure_ascii=False, indent=2))
        bad = {k: v for k, v in manifest.get("stills_drift_pixels_reduced_motion", {}).items() if v != 0}
        if bad:
            print(f"!! 静止态还有像素差：{bad}", file=sys.stderr)
    finally:
        chrome.kill()
        http.kill()


if __name__ == "__main__":
    main()
