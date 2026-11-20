"""docs/screenshots_v5 出图：白天 / 黑夜全页（web release + 无头 Chrome CDP）。

和 tool/shoot_theme_screens.py 同一套 CDP 手法（headless Chrome + Page.captureScreenshot），
只是本卡不需要过渡中间帧，只拍落定态。

用法（仓库根目录）：
    flutter build web --release
    python -m http.server 8099 --bind 127.0.0.1   # 在 build/web 里起
    python tool/shoot_screens_v5.py
输出：
    docs/screenshots_v5/*.png（1440×900，DPR 1）
    （delivery_before_light.png 不在这里拍：它是 main @205da09 的 screenshots_v4 原图，直接拷过来当基线）
"""

from __future__ import annotations

import base64
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
OUT = os.path.join(ROOT, "docs", "screenshots_v5")
BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8099/index.html"
CHROME_CANDIDATES = [
    r"C:/Program Files/Google/Chrome/Application/chrome.exe",
    r"C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
]
PORT = 9337
VIEW = (1440, 900)

# 主题切换按钮：顶部导航右侧、头像组左边，36px 圆按钮
TOGGLE = (1224, 36)


class CDP:
    def __init__(self, ws_url: str) -> None:
        self.ws = connect(ws_url, max_size=None, open_timeout=30)
        self.next_id = 0

    def call(self, method: str, **params):
        self.next_id += 1
        mid = self.next_id
        self.ws.send(json.dumps({"id": mid, "method": method, "params": params}))
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

    def assert_app(self) -> None:
        """落盘前确认页面是真的应用，不是 http.server 的 404 / 错误页。

        18:08 那批 7 张 404（md5 全是 528cbf41…、各 19466 B）就是因为采集时
        build/web 被 flutter clean 清空、http.server 返回错误页，脚本照拍不误。
        """
        res = self.call("Runtime.evaluate", expression="document.title",
                        returnByValue=True)
        title = (res.get("result") or {}).get("value") or ""
        if "lab5" not in title.lower():
            raise SystemExit(f"页面没加载成功（document.title={title!r}），拒绝落盘")

    def shot(self, path: str) -> float:
        started = time.time()
        data = self.call("Page.captureScreenshot", format="png", fromSurface=True)["data"]
        with open(path, "wb") as f:
            f.write(base64.b64decode(data))
        return (time.time() - started) * 1000


def find_chrome() -> str:
    for path in CHROME_CANDIDATES:
        if os.path.exists(path):
            return path
    raise SystemExit("找不到 Chrome / Edge")


def start_chrome() -> subprocess.Popen:
    profile = os.path.join(tempfile.gettempdir(), "t0chrome-v5")
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
            with urllib.request.urlopen(
                f"http://127.0.0.1:{PORT}/json/version", timeout=1
            ) as r:
                json.load(r)
            return proc
        except Exception:
            time.sleep(0.2)
    proc.kill()
    raise SystemExit("Chrome 调试端口没起来")


_nonce = [0]


def route(url_base: str, name: str) -> str:
    """每次带一个不同的查询串：只改 hash 是 same-document 跳转，Flutter 不会重启。"""
    _nonce[0] += 1
    sep = "&" if "?" in url_base else "?"
    return f"{url_base}{sep}n={_nonce[0]}#/{name}"


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    proc = start_chrome()
    with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json/list", timeout=5) as r:
        targets = [t for t in json.load(r) if t.get("type") == "page"]
    cdp = CDP(targets[0]["webSocketDebuggerUrl"])
    cdp.open_page("about:blank")
    try:
        # 文件名自带「页名 + 明暗」，一眼能读：workbench / workspace / delivery
        plan = [
            ("workbench_light.png", "workbench", False),
            ("workbench_dark.png", "workbench", True),
            ("workspace_light.png", "workspace", False),
            ("workspace_dark.png", "workspace", True),
            ("delivery_after_light.png", "delivery", False),
            ("delivery_after_dark.png", "delivery", True),
        ]
        for filename, route_name, dark in plan:
            cdp.navigate(route(BASE, route_name))
            if dark:
                cdp.click(*TOGGLE)
                time.sleep(1.0)  # 420ms 过渡跑完再截落定态
            cdp.assert_app()
            tmp = os.path.join(OUT, filename + ".tmp.png")
            ms = cdp.shot(tmp)
            cdp.assert_app()
            os.replace(tmp, os.path.join(OUT, filename))
            print(f"{filename}  (capture {ms:.0f} ms, dark={dark})")

        # 模块工作区：滚到底再拍一张，证明页脚不会压住白页最后一行
        cdp.navigate(route(BASE, "workspace"))
        for _ in range(6):
            cdp.call("Input.dispatchMouseEvent", type="mouseWheel",
                     x=700, y=600, deltaX=0, deltaY=400)
            time.sleep(0.25)
        time.sleep(0.8)
        cdp.assert_app()
        tmp = os.path.join(OUT, "workspace_light_scrolled.png.tmp.png")
        ms = cdp.shot(tmp)
        cdp.assert_app()
        os.replace(tmp, os.path.join(OUT, "workspace_light_scrolled.png"))
        print(f"workspace_light_scrolled.png  (capture {ms:.0f} ms)")
    finally:
        try:
            cdp.call("Browser.close")
        except Exception:
            pass
        proc.terminate()


if __name__ == "__main__":
    main()
