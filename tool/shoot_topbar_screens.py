"""r3 顶栏出图：工作台 / 材料输入 / 模块工作区 / 返回工作台，外加切主题对照。

判据全部落在图上：
  · 工作台（01、04）右侧只有 主题按钮 + 加号 —— 像素扫描找不到头像组，也找不到项目名；
  · 材料输入 / 模块工作区（02、03）多出「城市公共空间调研 + 已自动保存」两组像素；
  · 01 与 04 如果 md5 相同，就说明「从项目返回工作台」后顶栏真的回到了同一状态。

用法（仓库根目录，release 包已构建）：
    flutter build web --release
    cd build/web && python -m http.server 8099 --bind 127.0.0.1
    python tool/shoot_topbar_screens.py

输出：docs/screenshots_v8/
    01_workbench_topbar.png        工作台整屏
    02_intake_topbar.png           材料输入整屏
    03_workspace_topbar.png        模块工作区整屏
    04_back_to_workbench.png       点顶栏「工作台」回到工作台后整屏
    05_workbench_topbar_dark.png   工作台黑夜
    06_intake_topbar_dark.png      材料输入黑夜
    *_strip_2x.png                 顶栏 0..72px 裁切、2× 放大（看不清就放大看）
    measurements.txt               像素扫描结果（顶栏高度 / 右侧像素分组 / 组间距）
"""

from __future__ import annotations

import base64
import hashlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request

from PIL import Image
from websockets.sync.client import connect

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", os.environ.get("T0_SHOTS", "screenshots_v8"))
BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8099/index.html"
CHROME_CANDIDATES = [
    r"C:/Program Files/Google/Chrome/Application/chrome.exe",
    r"C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
]
PORT = 9334
VIEW = (1440, 900)

# 顶栏几何（由 test/topbar_test.dart 断言：72 高、右侧 24 内边距、相邻间距 16）
TOPBAR_H = 72
# 两个圆钮都是 36×36（T0.iconButtonSize），加号右边缘距视口 24：加号 1380..1416、主题 1328..1364
THEME_CENTER = (1346, 36)
ADD_CENTER = (1398, 36)
# 顶栏左侧导航「工作台」的点击点不再硬编码：浏览器字体宽度和 widget 测试不同，
# 改为打开 Flutter 语义树后按语义节点的屏幕矩形点（见 button_center）。
IDLE_POINT = (1435, 895)  # 页面右下角留白处：不压任何可悬停元素

LIGHT_SURFACE = (0xFF, 0xFD, 0xF8)
DARK_SURFACE = (0x3A, 0x2F, 0x44)


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

    def eval(self, expression: str):
        res = self.call("Runtime.evaluate", expression=expression, returnByValue=True)
        return (res.get("result") or {}).get("value")

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
        self.call("Page.navigate", url=url)

    def navigate(self, url: str, settle: float = 4.5) -> None:
        self.call("Page.navigate", url=url)
        time.sleep(settle)

    def click(self, x: float, y: float) -> None:
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

    def move(self, x: float, y: float) -> None:
        self.call(
            "Input.dispatchMouseEvent",
            type="mouseMoved",
            x=x,
            y=y,
            buttons=0,
            pointerType="mouse",
        )

    def shot_bytes(self) -> bytes:
        data = self.call("Page.captureScreenshot", format="png", fromSurface=True)["data"]
        return base64.b64decode(data)

    def assert_app(self, timeout: float = 45.0) -> None:
        """等到 MaterialApp 真正跑起来（它会把 document.title 改成「t0 办公 …」）。

        刚 rebuild 完的 release 包第一次加载要拉 CanvasKit + 字体，4~5 秒不够，
        所以这里轮询而不是一锤子；404 页 / about:blank 永远不会出现这个标题。
        """
        deadline = time.time() + timeout
        title = ""
        while time.time() < deadline:
            title = self.eval("document.title") or ""
            if "t0" in title.lower() and "办公" in title:
                return
            time.sleep(0.5)
        raise SystemExit(f"页面没加载成功（document.title={title!r}），拒绝落盘")


def find_chrome() -> str:
    for path in CHROME_CANDIDATES:
        if os.path.exists(path):
            return path
    raise SystemExit("找不到 Chrome / Edge")


def start_chrome() -> subprocess.Popen:
    profile = os.path.join(tempfile.gettempdir(), "t0chrome-topbar")
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
                return proc, json.load(r)
        except Exception:
            time.sleep(0.2)
    proc.kill()
    raise SystemExit("Chrome 调试端口没起来")


_nonce = [0]


def route(url_base: str, name: str) -> str:
    """每次带不同查询串：只改 hash 是 same-document 跳转，Flutter 不会重启，
    上一次的主题 / 滚动位置会带过来。"""
    _nonce[0] += 1
    sep = "&" if "?" in url_base else "?"
    return f"{url_base}{sep}n={_nonce[0]}#/{name}"


# ------------------------------------------------------------------ 语义树点击
# 画布应用没有可点的 DOM，只能靠坐标；而字体在浏览器里和 widget 测试里宽度不同，
# 硬编码坐标会漂。所以先打开 Flutter 的语义树（语义节点带 role=button 和屏幕矩形），
# 按文字找按钮再点它的中心。
ENABLE_SEMANTICS = """(() => {
  const p = document.querySelector('flt-semantics-placeholder');
  if (p) { p.click(); return 'enabled'; }
  return 'already';
})()"""

BUTTON_RECT = """(() => {
  const want = %s;
  for (const el of document.querySelectorAll('flt-semantics[role="button"], flt-semantics[role="link"]')) {
    const text = (el.innerText || '').trim().replace(/\\s+/g, ' ');
    if (text === want || text.indexOf(want) === 0) {
      const r = el.getBoundingClientRect();
      return {x: r.x + r.width / 2, y: r.y + r.height / 2, w: r.width, h: r.height, text: text};
    }
  }
  return null;
})()"""

LIST_BUTTONS = """(() => Array.from(document.querySelectorAll('flt-semantics[role="button"]'))
  .map(e => (e.innerText || '').trim().replace(/\\s+/g, ' '))
  .filter(t => t.length > 0).join(' | '))()"""


def enable_semantics(cdp: CDP) -> str:
    state = cdp.eval(ENABLE_SEMANTICS)
    time.sleep(1.5)
    return str(state)


def button_center(cdp: CDP, label: str) -> tuple[float, float]:
    rect = cdp.eval(BUTTON_RECT % json.dumps(label, ensure_ascii=False))
    if not rect:
        raise SystemExit(f"语义树里找不到按钮「{label}」；现有按钮：{cdp.eval(LIST_BUTTONS)}")
    print(f"  语义节点「{label}」@ {rect['x']:.1f},{rect['y']:.1f} ({rect['w']:.0f}x{rect['h']:.0f})")
    return float(rect["x"]), float(rect["y"])


def strip_2x(png: bytes) -> bytes:
    im = Image.open(io.BytesIO(png)).convert("RGB")
    top = im.crop((0, 0, VIEW[0], TOPBAR_H))
    top = top.resize((VIEW[0] * 2, TOPBAR_H * 2), Image.NEAREST)
    buf = io.BytesIO()
    top.save(buf, format="PNG")
    return buf.getvalue()


def crop_2x(png: bytes, box: tuple[int, int, int, int]) -> bytes:
    """裁一块再 2× 放大：给「模拟解析失败」这类只有几十像素高的按钮留证据。"""
    im = Image.open(io.BytesIO(png)).convert("RGB")
    part = im.crop(box)
    part = part.resize((part.width * 2, part.height * 2), Image.NEAREST)
    buf = io.BytesIO()
    part.save(buf, format="PNG")
    return buf.getvalue()


def topbar_height(im: Image.Image, x: int = 1000) -> int:
    """x 列往下第一条「非 surface」的行是顶栏的下边框，所以高度 = y + 1。"""
    px = im.load()
    for y in range(0, 200):
        if px[x, y] != LIGHT_SURFACE:
            return y + 1
    return -1


def merge_runs(cols: list[int], gap: int = 10) -> list[tuple[int, int]]:
    runs: list[tuple[int, int]] = []
    for x in cols:
        if runs and x == runs[-1][1] + 1:
            runs[-1] = (runs[-1][0], x)
        else:
            runs.append((x, x))
    merged: list[tuple[int, int]] = []
    for g in runs:
        if merged and g[0] - merged[-1][1] <= gap:
            merged[-1] = (merged[-1][0], g[1])
        else:
            merged.append(g)
    return merged


def luminance(rgb) -> float:
    def lin(c: int) -> float:
        s = c / 255
        return s / 12.92 if s <= 0.03928 else ((s + 0.055) / 1.055) ** 2.4

    r, g, b = (lin(int(c)) for c in rgb[:3])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ink_stats(im: Image.Image, x0: int, x1: int, surface) -> tuple[int, float]:
    """组内「明显不是底色」的像素数量与平均亮度：判断字色离底色多远（昼暗夜亮）。"""
    px = im.load()
    hits: list[float] = []
    for x in range(x0, x1 + 1):
        for y in range(18, TOPBAR_H - 14):
            c = px[x, y]
            if max(abs(c[0] - surface[0]), abs(c[1] - surface[1]), abs(c[2] - surface[2])) > 60:
                hits.append(luminance(c))
    return len(hits), (sum(hits) / len(hits) if hits else 0.0)


def runs_in_topbar(
    im: Image.Image,
    surface: tuple[int, int, int] = LIGHT_SURFACE,
    x0: int = 900,
    x1: int = 1439,
    gap: int = 10,
) -> list[tuple[int, int]]:
    """把顶栏右侧「和底色不一样」的列合并成组 = 肉眼看到的元素。

    组里包含文字字面与侧边留白，所以组间像素距离会比 16 小一点；
    精确间距以 test/topbar_test.dart 的 widget 矩形为准。
    """
    px = im.load()
    cols: list[int] = []
    for x in range(x0, x1 + 1):
        for y in range(16, TOPBAR_H - 14):
            r, g, b = px[x, y]
            if max(abs(r - surface[0]), abs(g - surface[1]), abs(b - surface[2])) > 24:
                cols.append(x)
                break
    return merge_runs(cols, gap)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    proc, _info = start_chrome()
    with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json/list", timeout=5) as r:
        targets = [t for t in json.load(r) if t.get("type") == "page"]
    cdp = CDP(targets[0]["webSocketDebuggerUrl"])
    cdp.open_page("about:blank")

    shots: dict[str, bytes] = {}
    try:
        plan = [
            ("01_workbench_topbar.png", "workbench", False),
            ("02_intake_topbar.png", "intake", False),
            ("03_workspace_topbar.png", "workspace", False),
            ("05_workbench_topbar_dark.png", "workbench", True),
            ("06_intake_topbar_dark.png", "intake", True),
        ]
        for filename, route_name, dark in plan:
            cdp.navigate(route(BASE, route_name))
            if dark:
                cdp.click(*THEME_CENTER)
                time.sleep(1.0)  # 420ms 过渡跑完再截落定态
                cdp.move(*IDLE_POINT)
                time.sleep(0.2)
            cdp.assert_app()
            png = cdp.shot_bytes()
            shots[filename] = png
            with open(os.path.join(OUT, filename), "wb") as fh:
                fh.write(png)
            with open(os.path.join(OUT, filename.replace(".png", "_strip_2x.png")), "wb") as fh:
                fh.write(strip_2x(png))
            if route_name == "intake" and not dark:
                # 三个并排按钮（使用示例材料 / 模拟解析失败 / 重新开始）2× 局部图，
                # 用来核对「模拟解析失败」和左右同形（胶囊 + 1px 描边 + danger 字色）
                with open(os.path.join(OUT, "07_intake_buttons_2x.png"), "wb") as fh:
                    fh.write(crop_2x(png, (110, 585, 500, 655)))
            print(f"{filename}  md5={hashlib.md5(png).hexdigest()[:12]}")

        # 04：从材料输入点顶栏「工作台」回到工作台（同一进程内导航，不是重新打开页面）
        cdp.navigate(route(BASE, "intake"))
        cdp.assert_app()
        print("  打开语义树找「工作台」导航：", enable_semantics(cdp))
        nav_point = button_center(cdp, "工作台")
        cdp.click(*nav_point)
        time.sleep(1.4)  # 240ms 转场 + 落定
        cdp.move(*IDLE_POINT)
        time.sleep(0.4)
        after = cdp.shot_bytes()
        with open(os.path.join(OUT, "04_back_to_workbench.png"), "wb") as fh:
            fh.write(after)
        with open(
            os.path.join(OUT, "04_back_to_workbench_strip_2x.png"), "wb"
        ) as fh:
            fh.write(strip_2x(after))
        print(f"04_back_to_workbench.png  md5={hashlib.md5(after).hexdigest()[:12]}")
    finally:
        try:
            cdp.call("Browser.close")
        except Exception:
            pass
        proc.terminate()

    # ------------------------------------------------------------ 像素自检
    lines: list[str] = []
    groups: dict[str, list[tuple[int, int]]] = {}
    for filename in (
        "01_workbench_topbar.png",
        "02_intake_topbar.png",
        "03_workspace_topbar.png",
        "04_back_to_workbench.png",
    ):
        im = Image.open(os.path.join(OUT, filename)).convert("RGB")
        h = topbar_height(im)
        groups[filename] = runs_in_topbar(im)
        lines.append(f"{filename}: 顶栏高度 {h}px（含 1px 下边框）")
        lines.append(
            "  右侧像素分组（x 区间）: "
            + ", ".join(f"{a}-{b}" for a, b in groups[filename])
        )
        gaps = [
            groups[filename][i + 1][0] - groups[filename][i][1]
            for i in range(len(groups[filename]) - 1)
        ]
        lines.append(
            "  组间像素距离: " + (", ".join(str(g) for g in gaps) if gaps else "（只有一组）")
        )

    # 硬判据：工作台 2 组（主题 + 加号），项目内 4 组（项目名 / 已保存 / 主题 / 加号）
    for filename in ("01_workbench_topbar.png", "04_back_to_workbench.png"):
        if len(groups[filename]) != 2:
            raise SystemExit(
                f"{filename} 右侧应只有 2 组像素，实际 {len(groups[filename])} 组：{groups[filename]}"
            )
    for filename in ("02_intake_topbar.png", "03_workspace_topbar.png"):
        if len(groups[filename]) != 4:
            raise SystemExit(
                f"{filename} 右侧应有 4 组像素，实际 {len(groups[filename])} 组：{groups[filename]}"
            )

    # 01 vs 04：返回工作台后整屏应与首次进入一致（同一状态）
    im01 = Image.open(os.path.join(OUT, "01_workbench_topbar.png")).convert("RGB")
    im04 = Image.open(os.path.join(OUT, "04_back_to_workbench.png")).convert("RGB")
    diff = sum(
        1
        for a, b in zip(im01.getdata(), im04.getdata())
        if max(abs(a[0] - b[0]), abs(a[1] - b[1]), abs(a[2] - b[2])) > 8
    )
    total_px = im01.width * im01.height
    lines.append("")
    lines.append(
        f"01 与 04 整屏差异像素: {diff}/{total_px} ({100 * diff / total_px:.3f}%)  "
        f"md5 相同={hashlib.md5(shots['01_workbench_topbar.png']).digest() == hashlib.md5(after).digest()}"
    )
    lines.append("（01 首次进工作台，04 从材料输入点「工作台」返回；差异应接近 0）")

    # 昼 / 夜：顶栏底色与项目名字色
    for filename, surface in (
        ("02_intake_topbar.png", LIGHT_SURFACE),
        ("06_intake_topbar_dark.png", DARK_SURFACE),
    ):
        im = Image.open(os.path.join(OUT, filename)).convert("RGB")
        px = im.load()
        bg = px[1000, 4]
        g = runs_in_topbar(im, surface, gap=14 if surface == DARK_SURFACE else 10)
        lines.append(
            f"{filename}: 顶栏底色 @ (1000,4) = #{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}；"
            f"右侧像素分组 {', '.join(f'{a}-{b}' for a, b in g)}"
        )
        if g:
            n, lum = ink_stats(im, g[0][0], g[0][1], surface)
            lines.append(f"  项目名区 ({g[0][0]}-{g[0][1]}) 笔画像素 {n} 个，平均亮度 {lum:.3f}")

    with open(os.path.join(OUT, "measurements.txt"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
