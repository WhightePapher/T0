"""r4 收尾出图：01 工作台 / 02 材料输入 / 05 模块工作区，浅色 + 深色各一张。

与 `tool/shoot_topbar_screens.py` 同一套 CDP 手法（headless Chrome + Page.captureScreenshot），
差别是这一批要为「4 处改动」留可度量的证据：

  · 01 工作台：环旁新加的「已确认 3/5」+ 右上「产品流程」卡内边距；
  · 02 材料输入：未选中 tab 与文件卡 meta 的字色（浅色）、「模拟解析失败」的字色（深色）；
  · 05 模块工作区：纸张卡左上中文小标「结构压缩版」（只在版本 2 出现，
    所以这一页先用 AI 面板真跑一次「应用修改」把状态推进到版本 2 再拍）。

用法（仓库根目录，release 包已构建，静态服务在本 worktree 的 build/web 上）：
    flutter build web --release
    cd build/web && python -m http.server 8110 --bind 127.0.0.1
    python tool/shoot_v9.py http://127.0.0.1:8110/index.html

输出：docs/screenshots_v9/（1440×900，DPR 1）
    01_workbench_light.png / 01_workbench_dark.png
    02_intake_light.png    / 02_intake_dark.png
    05_workspace_light.png / 05_workspace_dark.png
    07_intake_danger_{light,dark}_2x.png      「模拟解析失败」2× 局部
    08_intake_tabs_light_2x.png               tab 轨道 2× 局部
    08_intake_filecard_light_2x.png           文件卡 2× 局部
    09_workspace_label_10x.png                纸张卡左上小标 10× 放大
    10_workbench_aside_2x.png                 右卡「产品流程·三步」2× 局部
    11_workbench_ring_{light,dark}_2x.png     环 + 「已确认 3/5」2× 局部
    positions.json                            从像素里量到的元素矩形（给 measure_v9.py 用）
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
from collections import Counter

from PIL import Image
from websockets.sync.client import connect

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", os.environ.get("T0_SHOTS", "screenshots_v9"))
BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8110/index.html"
CHROME_CANDIDATES = [
    r"C:/Program Files/Google/Chrome/Application/chrome.exe",
    r"C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
]
PORT = 9335
VIEW = (1440, 900)

# 顶栏两个圆钮：主题 1328..1363、加号 1380..1415，中线 y=36（test/topbar_test.dart 断言）
THEME_CENTER = (1346, 36)
IDLE_POINT = (1435, 895)

# 浅色 / 深色卡面（用来判断截图是不是真的落在该主题上）
LIGHT_SURFACE = (0xFF, 0xFD, 0xF8)
DARK_SURFACE = (0x3A, 0x2F, 0x44)

# 固定版面里的取样带（1440×900，x1/y1/x2/y2 左闭右开）。
# 材料输入页三处元素的版面在 r4 里一个像素都没动，所以 v8 的基线图可以用同一批取样带。
BANDS = {
    "02:tab_text": (440, 282, 700, 318),        # 未选中 tab「粘贴文本」，底是 tab 轨道 canvas
    "02:file_meta": (190, 552, 470, 582),       # 文件卡 meta「14 页 · 3.2 MB · …」，底是 accentSoft
    "02:danger_text": (270, 604, 392, 640),     # 「模拟解析失败」胶囊里的字
    "01:ring_caption": (700, 470, 934, 526),    # 环左侧新加的「已确认 3/5」
    "01:aside_card": (1010, 405, 1355, 790),    # 右卡「产品流程·三步」整卡区域
}


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

    def assert_app(self, timeout: float = 60.0) -> None:
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


def start_chrome():
    profile = os.path.join(tempfile.gettempdir(), "t0chrome-v9")
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
    """每次带不同查询串：只改 hash 是 same-document 跳转，Flutter 不会重启。"""
    _nonce[0] += 1
    sep = "&" if "?" in url_base else "?"
    return f"{url_base}{sep}n={_nonce[0]}#/{name}"


# ------------------------------------------------------------------ 语义树（只用来点按钮）
ENABLE_SEMANTICS = """(() => {
  const p = document.querySelector('flt-semantics-placeholder');
  if (p) { p.click(); return 'enabled'; }
  return 'already';
})()"""

FIND_RECT = """(() => {
  const want = %s;
  for (const el of document.querySelectorAll('flt-semantics')) {
    const text = (el.innerText || '').trim().replace(/\\s+/g, ' ');
    if (text === want || text.indexOf(want) === 0) {
      const r = el.getBoundingClientRect();
      if (r.width > 0 && r.height > 0) {
        return {x: r.x, y: r.y, w: r.width, h: r.height, text: text};
      }
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


def click_label(cdp: CDP, label: str) -> dict:
    rect = cdp.eval(FIND_RECT % json.dumps(label, ensure_ascii=False))
    if not rect:
        raise SystemExit(f"语义树里找不到「{label}」；现有按钮：{cdp.eval(LIST_BUTTONS)}")
    print(f"  点「{label}」@ {rect['x']:.1f},{rect['y']:.1f} ({rect['w']:.0f}x{rect['h']:.0f})")
    cdp.click(rect["x"] + rect["w"] / 2, rect["y"] + rect["h"] / 2)
    return rect


# ------------------------------------------------------------------ 像素工具
def to_image(png) -> Image.Image:
    if isinstance(png, bytes):
        return Image.open(io.BytesIO(png)).convert("RGB")
    return Image.open(png).convert("RGB")


def ink_bbox(im: Image.Image, box, thresh: int = 40):
    """取样带里「和底色明显不同」的像素外接矩形 = 字面（不含行高留白）。"""
    crop = im.crop(tuple(box))
    pixels = list(crop.getdata())
    counts = Counter(pixels)
    bg = counts.most_common(1)[0][0]
    xs: list[int] = []
    ys: list[int] = []
    w = crop.width
    for idx, p in enumerate(pixels):
        if max(abs(p[0] - bg[0]), abs(p[1] - bg[1]), abs(p[2] - bg[2])) > thresh:
            xs.append(idx % w)
            ys.append(idx // w)
    if not xs:
        raise SystemExit(f"取样带 {box} 里找不到字（底色 #{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}）")
    return (box[0] + min(xs), box[1] + min(ys), box[0] + max(xs) + 1, box[1] + max(ys) + 1), bg


def color_bbox(im: Image.Image, region, color, tol: int = 6):
    """region 里「等于 color」的像素外接矩形（用来找卡面 / 纸页）。"""
    crop = im.crop(tuple(region))
    px = crop.load()
    xs: list[int] = []
    ys: list[int] = []
    for y in range(crop.height):
        for x in range(crop.width):
            p = px[x, y]
            if max(abs(p[0] - color[0]), abs(p[1] - color[1]), abs(p[2] - color[2])) <= tol:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return (region[0] + min(xs), region[1] + min(ys), region[0] + max(xs) + 1, region[1] + max(ys) + 1)


def find_paper_card(im: Image.Image, region, color, min_run: int = 400):
    """在画布列里找纸页：逐行统计「等于 color」的像素数，连续 >min_run 的行才是纸页。"""
    crop = im.crop(tuple(region))
    px = crop.load()
    rows: list[int] = []
    for y in range(crop.height):
        hits = 0
        for x in range(crop.width):
            p = px[x, y]
            if max(abs(p[0] - color[0]), abs(p[1] - color[1]), abs(p[2] - color[2])) <= 6:
                hits += 1
        if hits >= min_run:
            rows.append(y)
    if not rows:
        return None
    y0, y1 = min(rows), max(rows) + 1
    # 左右边界只在纸页顶部那条带里量：整段 y0..y1 里还混着工具栏按钮等其它白块
    band_end = min(y1, y0 + 30)
    cols: list[int] = []
    for x in range(crop.width):
        for y in range(y0, band_end):
            p = px[x, y]
            if max(abs(p[0] - color[0]), abs(p[1] - color[1]), abs(p[2] - color[2])) <= 6:
                cols.append(x)
                break
    return (region[0] + min(cols), region[1] + y0, region[0] + max(cols) + 1, region[1] + y1)


def pad_box(box, pad: int):
    return (max(0, box[0] - pad), max(0, box[1] - pad), box[2] + pad, box[3] + pad)


def crop_zoom(png: bytes, box, factor: int) -> bytes:
    im = to_image(png)
    part = im.crop(tuple(int(v) for v in box))
    part = part.resize((part.width * factor, part.height * factor), Image.NEAREST)
    buf = io.BytesIO()
    part.save(buf, format="PNG")
    return buf.getvalue()


def save(name: str, data: bytes) -> bytes:
    with open(os.path.join(OUT, name), "wb") as fh:
        fh.write(data)
    print(f"{name}  md5={hashlib.md5(data).hexdigest()[:12]}  {len(data) // 1024}KB")
    return data


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    proc, _info = start_chrome()
    with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json/list", timeout=5) as r:
        targets = [t for t in json.load(r) if t.get("type") == "page"]
    cdp = CDP(targets[0]["webSocketDebuggerUrl"])
    cdp.open_page("about:blank")

    shots: dict[str, bytes] = {}
    try:
        # 01 / 02 / 05 各拍浅色 + 深色；05 先把页面推进到「版本 2」，
        # 因为纸张卡左上的中文小标「结构压缩版」只在版本 2 出现。
        plan = [
            ("01_workbench_light.png", "workbench", False, False),
            ("01_workbench_dark.png", "workbench", True, False),
            ("02_intake_light.png", "intake", False, False),
            ("02_intake_dark.png", "intake", True, False),
            ("05_workspace_light.png", "workspace", False, True),
            ("05_workspace_dark.png", "workspace", True, True),
        ]
        for filename, route_name, dark, edited in plan:
            print(
                f"\n[{filename}] /{route_name}"
                f"{' · 版本 2' if edited else ''}{' · 深色' if dark else ''}"
            )
            cdp.navigate(route(BASE, route_name))
            cdp.assert_app()
            print("  语义树：", enable_semantics(cdp))
            if edited:
                click_label(cdp, "文字太多，压缩成三点")
                time.sleep(0.8)
                click_label(cdp, "应用修改")
                time.sleep(4.8)  # 1.1s 生成 + 2.4s toast 走完，避免截到浮层
            if dark:
                cdp.click(*THEME_CENTER)
                time.sleep(1.4)  # 420ms 过渡 + 落定
                cdp.move(*IDLE_POINT)
                time.sleep(0.4)
            png = cdp.shot_bytes()
            shots[filename] = save(filename, png)

        light_01, dark_01 = shots["01_workbench_light.png"], shots["01_workbench_dark.png"]
        light_02, dark_02 = shots["02_intake_light.png"], shots["02_intake_dark.png"]
        light_05 = shots["05_workspace_light.png"]

        # ---------------------------------------------------------------- 局部图 + 元素框
        positions: dict[str, list[int]] = {}

        # 02：未选中 tab 字面 / 文件卡 meta 字面 / danger 钮里的字
        tab_box, tab_bg = ink_bbox(to_image(light_02), BANDS["02:tab_text"])
        meta_box, meta_bg = ink_bbox(to_image(light_02), BANDS["02:file_meta"])
        danger_light, _ = ink_bbox(to_image(light_02), BANDS["02:danger_text"])
        danger_dark, danger_bg = ink_bbox(to_image(dark_02), BANDS["02:danger_text"])
        positions["02_light:tab_text"] = list(tab_box)
        positions["02_light:file_meta"] = list(meta_box)
        positions["02_light:danger_text"] = list(danger_light)
        positions["02_dark:danger_text"] = list(danger_dark)
        print(
            f"  02 浅色：tab 字面 {tab_box}（底 #{tab_bg[0]:02X}{tab_bg[1]:02X}{tab_bg[2]:02X}）、"
            f"文件卡 meta {meta_box}（底 #{meta_bg[0]:02X}{meta_bg[1]:02X}{meta_bg[2]:02X}）"
        )
        print(
            f"  02 深色：danger 字面 {danger_dark}"
            f"（底 #{danger_bg[0]:02X}{danger_bg[1]:02X}{danger_bg[2]:02X}）"
        )
        save("08_intake_tabs_light_2x.png", crop_zoom(light_02, (110, 268, 1010, 330), 2))
        save("08_intake_filecard_light_2x.png", crop_zoom(light_02, pad_box(meta_box, 62), 2))
        save("07_intake_danger_light_2x.png", crop_zoom(light_02, pad_box(danger_light, 10), 2))
        save("07_intake_danger_dark_2x.png", crop_zoom(dark_02, pad_box(danger_dark, 10), 2))

        # 01：环旁口径字面 + 右卡整卡
        cap_box, cap_bg = ink_bbox(to_image(light_01), BANDS["01:ring_caption"])
        cap_dark, _ = ink_bbox(to_image(dark_01), BANDS["01:ring_caption"])
        positions["01_light:ring_caption"] = list(cap_box)
        positions["01_dark:ring_caption"] = list(cap_dark)
        print(
            f"  01 浅色：环旁口径字面 {cap_box}"
            f"（底 #{cap_bg[0]:02X}{cap_bg[1]:02X}{cap_bg[2]:02X}）"
        )
        aside = color_bbox(to_image(light_01), BANDS["01:aside_card"], LIGHT_SURFACE)
        if aside is None:
            raise SystemExit("01 里找不到右卡卡面")
        positions["01_light:aside_card"] = list(aside)
        save("11_workbench_ring_2x.png", crop_zoom(light_01, pad_box(cap_box, 14), 2))
        save("11_workbench_ring_dark_2x.png", crop_zoom(dark_01, pad_box(cap_dark, 14), 2))
        save("10_workbench_aside_2x.png", crop_zoom(light_01, pad_box(aside, 6), 2))

        # 05：纸张卡左上小标（纸页 = deckPaper #FFFDF8，在中间画布列里按「长白行」找，
        # 直接找颜色会被顶栏 / 面包屑的白底带偏）
        page = find_paper_card(to_image(light_05), (290, 300, 1055, 900), LIGHT_SURFACE)
        if page is None:
            raise SystemExit("05 里找不到纸张卡")
        positions["05_light:paper_card"] = list(page)
        label_box = (page[0] + 8, page[1] + 8, page[0] + 240, page[1] + 46)
        save("09_workspace_label_10x.png", crop_zoom(light_05, label_box, 10))
        print(f"  05 纸张卡 {page}；左上小标取样 {label_box}")

        with open(os.path.join(OUT, "positions.json"), "w", encoding="utf-8") as fh:
            json.dump(positions, fh, ensure_ascii=False, indent=2)
        print(f"\n元素矩形写入 positions.json（{len(positions)} 条）")
    finally:
        try:
            cdp.call("Browser.close")
        except Exception:
            pass
        proc.terminate()


if __name__ == "__main__":
    main()
