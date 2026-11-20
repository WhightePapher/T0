"""用本机 Chrome + CDP 给 t0办公 出图（白天 / 黑夜 / 主题切换中间帧）。

为什么要自己拉 CDP：主题过渡只有 420ms，必须点完按钮后按毫秒级时间点取帧，
而 walker 之类的封装截图一次要几秒。这里直接用 websocket 说 CDP。

用法（仓库根目录）：
    python tool/shoot_theme_screens.py

前置：
    flutter build web --release
    python -m http.server 8099 --bind 127.0.0.1   # 在 build/web 里起
输出：
    docs/screenshots_v5/*.png（1440×900，DPR 1）
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

from websockets.sync.client import connect

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# 批次目录可以用环境变量覆盖，默认出当前一批（v5）；v4 的图留在仓库里不动。
OUT = os.path.join(ROOT, "docs", os.environ.get("T0_SHOTS", "screenshots_v5"))
BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8099/index.html"
CHROME_CANDIDATES = [
    r"C:/Program Files/Google/Chrome/Application/chrome.exe",
    r"C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
]
PORT = 9333
VIEW = (1440, 900)

# 主题切换按钮：顶部导航右侧、头像组左边，36px 圆按钮
TOGGLE = (1224, 36)


class CDP:
    def __init__(self, ws_url: str) -> None:
        self.ws = connect(ws_url, max_size=None, open_timeout=30)
        self.next_id = 0
        self.session_id: str | None = None

    def call(self, method: str, **params):
        self.next_id += 1
        mid = self.next_id
        payload = {"id": mid, "method": method, "params": params}
        if self.session_id:
            payload["sessionId"] = self.session_id
        self.ws.send(json.dumps(payload))
        while True:
            msg = json.loads(self.ws.recv())
            if msg.get("id") == mid:
                if "error" in msg:
                    raise RuntimeError(f"{method}: {msg['error']}")
                return msg.get("result", {})

    def open_page(self, url: str) -> None:
        self.call("Page.enable")
        self.call("Runtime.enable")
        self.call(
            "Emulation.setDeviceMetricsOverride",
            width=VIEW[0],
            height=VIEW[1],
            deviceScaleFactor=1,
            mobile=False,
        )
        self.call("Emulation.setTouchEmulationEnabled", enabled=False)
        self.navigate(url)

    def navigate(self, url: str, settle: float = 4.0) -> None:
        self.call("Page.navigate", url=url)
        time.sleep(settle)

    def click(self, x: int, y: int) -> None:
        for kind in ("mousePressed", "mouseReleased"):
            self.call(
                "Input.dispatchMouseEvent",
                type=kind,
                x=x,
                y=y,
                button="left",
                buttons=1,
                clickCount=1,
                pointerType="mouse",
            )

    def send_raw(self, method: str, **params) -> None:
        self.next_id += 1
        payload = {"id": self.next_id, "method": method, "params": params}
        if self.session_id:
            payload["sessionId"] = self.session_id
        self.ws.send(json.dumps(payload))

    def pump(self, deadline: float, on_event) -> None:
        while time.time() < deadline:
            try:
                msg = json.loads(self.ws.recv(timeout=0.25))
            except TimeoutError:
                continue
            if "id" in msg:
                continue
            if msg.get("method"):
                on_event(msg["method"], msg.get("params", {}))

    def assert_app(self) -> None:
        """落盘前确认页面是真应用（404 错误页的 document.title 不带 lab5）。"""
        res = self.call("Runtime.evaluate", expression="document.title",
                        returnByValue=True)
        title = (res.get("result") or {}).get("value") or ""
        if "lab5" not in title.lower():
            raise SystemExit(f"页面没加载成功（document.title={title!r}），拒绝落盘")

    def shot(self, path: str) -> float:
        started = time.time()
        data = self.call("Page.captureScreenshot", format="png", fromSurface=True)[
            "data"
        ]
        with open(path, "wb") as f:
            f.write(base64.b64decode(data))
        return (time.time() - started) * 1000


def find_chrome() -> str:
    for path in CHROME_CANDIDATES:
        if os.path.exists(path):
            return path
    raise SystemExit("找不到 Chrome / Edge")


def start_chrome() -> subprocess.Popen:
    profile = os.path.join(tempfile.gettempdir(), "t0chrome-shots")
    shutil.rmtree(profile, ignore_errors=True)
    proc = subprocess.Popen(
        [
            find_chrome(),
            "--headless=new",
            f"--remote-debugging-port={PORT}",
            f"--user-data-dir={profile}",
            f"--window-size={VIEW[0]},{VIEW[1]}",
            "--force-device-scale-factor=1",
            "--hide-scrollbars",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-extensions",
            "--disable-features=Translate",
            "about:blank",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    for _ in range(150):
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json/version", timeout=1) as r:
                info = json.load(r)
            return proc, info
        except Exception:
            time.sleep(0.2)
    proc.kill()
    raise SystemExit("Chrome 调试端口没起来")


_nonce = [0]


def route(url_base: str, name: str) -> str:
    """每次带一个不同的查询串：只改 hash 是 same-document 跳转，Flutter 不会重启，
    主题状态会从上一次截图带过来（白天图里拍出黑夜，反之亦然）。"""
    _nonce[0] += 1
    sep = "&" if "?" in url_base else "?"
    return f"{url_base}{sep}n={_nonce[0]}#/{name}"


RAFSHIM = """
(() => {
  // 拍摄用的慢动作：只缩放 rAF 时间戳，动画本身仍是 420ms / easeInOutCubic。
  // 无头 CanvasKit 在 1440x900 只有 ~8fps，不减速就采不到 120/210/300ms 这些点。
  const orig = window.requestAnimationFrame.bind(window);
  const wall0 = performance.now();
  window.requestAnimationFrame = (cb) => orig((ts) => cb(wall0 + (ts - wall0) * 0.2));
})();
"""
SLOWMO = 0.2


def record_transition(cdp: CDP, url: str, window: float = 3.2) -> list[dict]:
    """点一下主题按钮，把这段过渡的每一帧都收下来（含 CDP 时间戳）。"""
    script_id = cdp.call("Page.addScriptToEvaluateOnNewDocument", source=RAFSHIM)[
        "identifier"
    ]
    try:
        cdp.navigate(url, settle=5.0)
        frames: list[dict] = []

        def on_event(method: str, params: dict) -> None:
            if method != "Page.screencastFrame":
                return
            frames.append(
                {
                    "t": float(params.get("metadata", {}).get("timestamp", 0.0)),
                    "png": base64.b64decode(params["data"]),
                }
            )
            cdp.send_raw("Page.screencastFrameAck", sessionId=params["sessionId"])

        cdp.call(
            "Page.startScreencast",
            format="png",
            maxWidth=VIEW[0],
            maxHeight=VIEW[1],
            everyNthFrame=1,
        )
        time.sleep(0.2)  # 先收一两帧静止态，用来确认起点是白天
        for kind in ("mousePressed", "mouseReleased"):
            cdp.send_raw(
                "Input.dispatchMouseEvent",
                type=kind,
                x=TOGGLE[0],
                y=TOGGLE[1],
                button="left",
                buttons=1,
                clickCount=1,
                pointerType="mouse",
            )
        cdp.pump(time.time() + window, on_event)
        cdp.call("Page.stopScreencast")
        print(f"screencast frames: {len(frames)}")
        return frames
    finally:
        cdp.call("Page.removeScriptToEvaluateOnNewDocument", identifier=script_id)


LIGHT_BG = (0xF6, 0xF2, 0xE9)


def pick_transition_frames(frames: list[dict]) -> None:
    """以「最后一帧仍是白天底色」为动画起点，按 120/210/300ms 取最接近的帧。"""
    from PIL import Image

    if not frames:
        raise SystemExit("没有收到 screencast 帧")

    def bg(png: bytes) -> tuple[int, int, int]:
        return Image.open(io.BytesIO(png)).convert("RGB").getpixel((200, 700))

    t_light = None
    for f in frames:
        if bg(f["png"]) == LIGHT_BG:
            t_light = f["t"]
    if t_light is None:
        raise SystemExit("没有拍到白天起手帧")

    samples = []
    for f in frames:
        anim_ms = (f["t"] - t_light) * 1000 * SLOWMO
        if 10 <= anim_ms <= 430:
            samples.append({"ms": anim_ms, "png": f["png"], "bg": bg(f["png"])})

    print("过渡采样（动画时间 / 页面底色）：")
    for s in samples:
        print(f"  {s['ms']:6.1f} ms  #{s['bg'][0]:02X}{s['bg'][1]:02X}{s['bg'][2]:02X}")
    with open(os.path.join(OUT, "transition_timeline.txt"), "w", encoding="utf-8") as fh:
        fh.write("# 主题切换过渡采样（页面底色像素 200,700，动画时间 = 墙钟时间 × 0.2）\n")
        for s in samples:
            fh.write(f"{s['ms']:.1f} ms  #{s['bg'][0]:02X}{s['bg'][1]:02X}{s['bg'][2]:02X}\n")

    for target, name in (
        (105, "10_transition_105ms.png"),
        (120, "07_transition_120ms.png"),
        (210, "08_transition_210ms.png"),
        (300, "09_transition_300ms.png"),
        (315, "11_transition_315ms.png"),
    ):
        if not samples:
            raise SystemExit(f"没有取到 {target}ms 附近的过渡帧")
        best = min(samples, key=lambda s: abs(s["ms"] - target))
        if abs(best["ms"] - target) > 30:
            raise SystemExit(f"{target}ms 附近没有足够接近的帧（最近 {best['ms']:.0f}ms）")
        with open(os.path.join(OUT, name), "wb") as fh:
            fh.write(best["png"])
        print(
            f"{name}  实际 {best['ms']:.0f} ms（动画时间），背景 "
            f"#{best['bg'][0]:02X}{best['bg'][1]:02X}{best['bg'][2]:02X}"
        )


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    proc, info = start_chrome()
    # 直接连页面 target 自己的 ws（走 browser 级 attach 时 Page.* 方法会报 not found）
    with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json/list", timeout=5) as r:
        targets = [t for t in json.load(r) if t.get("type") == "page"]
    cdp = CDP(targets[0]["webSocketDebuggerUrl"])
    cdp.open_page("about:blank")
    try:
        plan = [
            ("01_light_工作台.png", "workbench", False, None),
            ("02_dark_工作台.png", "workbench", True, None),
            ("03_light_模块工作区.png", "workspace", False, None),
            ("04_dark_模块工作区.png", "workspace", True, None),
            ("05_light_交付检查.png", "delivery", False, None),
            ("06_dark_交付检查.png", "delivery", True, None),
        ]
        for filename, route_name, dark, _ in plan:
            cdp.navigate(route(BASE, route_name))
            if dark:
                cdp.click(*TOGGLE)
                time.sleep(1.0)  # 420ms 过渡跑完，再截落定态
            cdp.assert_app()
            tmp = os.path.join(OUT, filename + ".tmp.png")
            ms = cdp.shot(tmp)
            os.replace(tmp, os.path.join(OUT, filename))
            print(f"{filename}  (capture {ms:.0f} ms, dark={dark})")

        # 过渡中间帧：CDP screencast 连续收帧（每帧自带时间戳），
        # 再挑出离 120 / 210 / 300ms 最近的三帧
        frames = record_transition(cdp, route(BASE, "workbench"))
        pick_transition_frames(frames)
    finally:
        try:
            cdp.call("Browser.close")
        except Exception:
            pass
        proc.terminate()


if __name__ == "__main__":
    main()
