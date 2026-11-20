"""在真实的 Windows exe 上出图：浅色一张、深色一张 —— 用「起两次进程」拿深色，不依赖点击。

为什么不用点按钮：这台机器上顶栏右上角经常被别的窗口（资源管理器 / 终端）压住，
合成鼠标点不到那个 36px 的圆按钮，之前两次交付都栽在这里。应用本身支持启动期覆盖
`T0_START_THEME=dark|light`（见 lib/theme/start_theme_io.dart），
所以脚本直接起两次 exe：一次浅色、一次深色，各抓一张，最后比 md5。

交互（点击切主题）仍然可以单独验证：`--click-check`，它只影响这一个开关，不进交付流程。

用法：
    python tool/shoot_windows_exe.py                  # 交付用：两次进程 + md5 自检 + 三组放大图
    python tool/shoot_windows_exe.py --click-check     # 额外验证「点按钮能切主题」
输出：
    <out>/exe_light.png、exe_dark.png（2182×1406，含窗口边框）
    <out>/exe_theme_light.png、exe_theme_dark.png（主题按钮 4×）
    <out>/exe_primary_light.png、exe_primary_dark.png（主按钮 4×）
    <out>/exe_titlebar_zoom.png（标题栏 3×，看应用图标）
"""

from __future__ import annotations

import argparse
import ctypes
import ctypes.wintypes as wt
import hashlib
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_EXE = ROOT / "dist" / "Lab5-办公-Windows" / "Lab5办公.exe"
DEFAULT_OUT = ROOT / "docs" / "screenshots_v5"
LOGICAL_W, LOGICAL_H = 1440, 900

user32 = ctypes.WinDLL("user32", use_last_error=True)
gdi32 = ctypes.WinDLL("gdi32", use_last_error=True)
user32.SetProcessDPIAware()
user32.GetDpiForWindow.restype = ctypes.c_uint
user32.GetDC.restype = ctypes.c_void_p
user32.GetDC.argtypes = [wt.HWND]
user32.ReleaseDC.argtypes = [wt.HWND, ctypes.c_void_p]
user32.PrintWindow.argtypes = [wt.HWND, ctypes.c_void_p, wt.UINT]
user32.GetWindowRect.argtypes = [wt.HWND, ctypes.POINTER(wt.RECT)]
user32.GetClientRect.argtypes = [wt.HWND, ctypes.POINTER(wt.RECT)]
user32.ClientToScreen.argtypes = [wt.HWND, ctypes.POINTER(wt.POINT)]
user32.MoveWindow.argtypes = [wt.HWND, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, wt.BOOL]
user32.SetWindowPos.argtypes = [wt.HWND, wt.HWND, ctypes.c_int, ctypes.c_int,
                                ctypes.c_int, ctypes.c_int, wt.UINT]
user32.SetForegroundWindow.argtypes = [wt.HWND]
user32.SetCursorPos.argtypes = [ctypes.c_int, ctypes.c_int]
user32.mouse_event.argtypes = [wt.DWORD, wt.DWORD, wt.DWORD, wt.DWORD, ctypes.c_void_p]
gdi32.CreateCompatibleDC.restype = ctypes.c_void_p
gdi32.CreateCompatibleDC.argtypes = [ctypes.c_void_p]
gdi32.CreateCompatibleBitmap.restype = ctypes.c_void_p
gdi32.CreateCompatibleBitmap.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
gdi32.SelectObject.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
gdi32.GetDIBits.argtypes = [ctypes.c_void_p, ctypes.c_void_p, wt.UINT, wt.UINT,
                            ctypes.c_void_p, ctypes.c_void_p, wt.UINT]
gdi32.DeleteObject.argtypes = [ctypes.c_void_p]
gdi32.DeleteDC.argtypes = [ctypes.c_void_p]

HWND_TOPMOST = wt.HWND(-1)
SWP_NOMOVE, SWP_NOSIZE = 0x0002, 0x0001


class BIH(ctypes.Structure):
    _fields_ = [
        ("biSize", wt.DWORD), ("biWidth", wt.LONG), ("biHeight", wt.LONG),
        ("biPlanes", wt.WORD), ("biBitCount", wt.WORD), ("biCompression", wt.DWORD),
        ("biSizeImage", wt.DWORD), ("biXPelsPerMeter", wt.LONG), ("biYPelsPerMeter", wt.LONG),
        ("biClrUsed", wt.DWORD), ("biClrImportant", wt.DWORD),
    ]


def wait_window(pid: int, timeout: float = 40.0) -> int:
    """该进程最大的可见窗口（Flutter 会先建一个 0 尺寸的隐藏窗口）。"""
    end = time.time() + timeout
    while time.time() < end:
        found: list[tuple[int, int]] = []

        @ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
        def cb(h, _l):
            wnd_pid = wt.DWORD()
            user32.GetWindowThreadProcessId(h, ctypes.byref(wnd_pid))
            if wnd_pid.value == pid and user32.IsWindowVisible(h):
                r = wt.RECT()
                user32.GetWindowRect(h, ctypes.byref(r))
                area = (r.right - r.left) * (r.bottom - r.top)
                if area > 400 * 300:
                    found.append((area, h))
            return True

        user32.EnumWindows(cb, 0)
        if found:
            return max(found)[1]
        time.sleep(0.25)
    raise SystemExit("没等到 exe 的主窗口")


def capture(hwnd: int, path: Path) -> Image.Image:
    r = wt.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(r))
    w, h = r.right - r.left, r.bottom - r.top
    hdc_screen = user32.GetDC(None)
    hdc = gdi32.CreateCompatibleDC(hdc_screen)
    bmp = gdi32.CreateCompatibleBitmap(hdc_screen, w, h)
    gdi32.SelectObject(hdc, bmp)
    user32.PrintWindow(hwnd, hdc, 0x2)  # PW_RENDERFULLCONTENT
    bi = BIH()
    bi.biSize = ctypes.sizeof(BIH)
    bi.biWidth, bi.biHeight = w, -h
    bi.biPlanes, bi.biBitCount = 1, 32
    buf = ctypes.create_string_buffer(w * h * 4)
    gdi32.GetDIBits(hdc, bmp, 0, h, buf, ctypes.byref(bi), 0)
    img = Image.frombuffer("RGB", (w, h), buf, "raw", "BGRX", 0, 1).copy()
    img.save(path)
    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(hdc)
    user32.ReleaseDC(None, hdc_screen)
    return img


def top_bar_mean(img: Image.Image, dx: int, dy: int) -> float:
    x1, y1 = max(0, dx + 5), max(0, dy + 5)
    x2 = max(x1 + 1, min(dx + 320, img.width - 5))
    y2 = max(y1 + 1, min(dy + 45, img.height - 5))
    px = list(img.crop((x1, y1, x2, y2)).getdata())
    return sum(sum(p) / 3 for p in px) / max(len(px), 1)


def md5(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def start_and_place(exe: Path, theme: str) -> tuple[subprocess.Popen, int, float, int, int]:
    env = dict(os.environ)
    env["T0_START_THEME"] = theme
    proc = subprocess.Popen([str(exe)], env=env)
    hwnd = wait_window(proc.pid)
    scale = (user32.GetDpiForWindow(hwnd) or 96) / 96.0
    wr, cr = wt.RECT(), wt.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(wr))
    user32.GetClientRect(hwnd, ctypes.byref(cr))
    frame_w = (wr.right - wr.left) - (cr.right - cr.left)
    frame_h = (wr.bottom - wr.top) - (cr.bottom - cr.top)
    user32.MoveWindow(hwnd, 20, 20, int(LOGICAL_W * scale) + frame_w,
                      int(LOGICAL_H * scale) + frame_h, True)
    time.sleep(1.4)
    user32.SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE)
    time.sleep(0.8)
    origin = wt.POINT(0, 0)
    user32.ClientToScreen(hwnd, ctypes.byref(origin))
    user32.GetWindowRect(hwnd, ctypes.byref(wr))
    dx, dy = origin.x - wr.left, origin.y - wr.top
    return proc, hwnd, scale, dx, dy


def stop(proc: subprocess.Popen) -> None:
    time.sleep(0.3)
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()


def crop_scaled(src: Path, dst: Path, box: tuple[int, int, int, int], factor: int) -> None:
    im = Image.open(src).convert("RGB")
    x1, y1, x2, y2 = box
    im.crop((x1, y1, x2, y2)).resize(((x2 - x1) * factor, (y2 - y1) * factor),
                                     Image.LANCZOS).save(dst)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--exe", type=Path, default=DEFAULT_EXE)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--click-check", action="store_true", help="额外验证点按钮能切主题")
    args = ap.parse_args()
    if not args.exe.exists():
        raise SystemExit(f"没有 exe：{args.exe}（先跑 tool/package_windows.py）")
    args.out.mkdir(parents=True, exist_ok=True)

    shots: dict[str, tuple[Path, float, float, int, int]] = {}
    for theme in ("light", "dark"):
        proc, hwnd, scale, dx, dy = start_and_place(args.exe, theme)
        try:
            path = args.out / f"exe_{theme}.png"
            img = capture(hwnd, path)
            mean = top_bar_mean(img, dx, dy)
            shots[theme] = (path, mean, scale, dx, dy)
            print(f"{theme}: {path}  {img.width}x{img.height}  scale={scale}  "
                  f"t={datetime.now():%H:%M:%S}  md5={md5(path)}  "
                  f"top_mean={mean:.0f}  (client origin {dx},{dy})", flush=True)

            if args.click_check and theme == "light":
                # 交互自检：点一下主题按钮，看顶栏是否变深（只报告，不影响出图）
                origin = wt.POINT(0, 0)
                user32.ClientToScreen(hwnd, ctypes.byref(origin))
                cr = wt.RECT()
                user32.GetClientRect(hwnd, ctypes.byref(cr))
                tx = origin.x + cr.right - int(216 * scale)
                ty = origin.y + int(36 * scale)
                user32.SetCursorPos(origin.x + 30, origin.y + cr.bottom - 30)
                user32.mouse_event(0x0002, 0, 0, 0, 0)
                user32.mouse_event(0x0004, 0, 0, 0, 0)
                time.sleep(0.6)
                user32.SetForegroundWindow(hwnd)
                user32.SetCursorPos(tx, ty)
                time.sleep(0.3)
                user32.mouse_event(0x0002, 0, 0, 0, 0)
                time.sleep(0.10)
                user32.mouse_event(0x0004, 0, 0, 0, 0)
                time.sleep(1.2)
                probe = capture(hwnd, args.out / "_click_probe.png")
                pm = top_bar_mean(probe, dx, dy)
                (args.out / "_click_probe.png").unlink(missing_ok=True)
                print(f"click-check: 点击后 top_mean={pm:.0f} → "
                      f"{'PASS' if pm < 120 else 'FAIL（按钮被别的窗口压住）'}", flush=True)
        finally:
            stop(proc)

    light, lmean, scale, dx0, dy0 = shots["light"]
    dark, dmean, _, _, _ = shots["dark"]
    if md5(light) == md5(dark):
        raise SystemExit("两张图 md5 相同，深色没拍到")

    # 放大图：主题按钮（太阳 / 月亮） + 主按钮（CTA 底色） + 标题栏图标
    def client_box(x1: int, y1: int, x2: int, y2: int) -> tuple[int, int, int, int]:
        # 图里客户区原点 = (dx, dy)；逻辑坐标 × scale
        return (dx0 + int(x1 * scale), dy0 + int(y1 * scale),
                dx0 + int(x2 * scale), dy0 + int(y2 * scale))

    # 客户区原点 (dx0, dy0) 来自 light 那张的实测值；两张同尺寸同布局
    crop_scaled(light, args.out / "exe_theme_light.png",
                client_box(1204, 16, 1244, 56), 4)
    crop_scaled(dark, args.out / "exe_theme_dark.png",
                client_box(1204, 16, 1244, 56), 4)
    crop_scaled(light, args.out / "exe_primary_light.png",
                client_box(1171, 314, 1343, 369), 3)
    crop_scaled(dark, args.out / "exe_primary_dark.png",
                client_box(1171, 314, 1343, 369), 3)
    crop_scaled(light, args.out / "exe_titlebar_zoom.png", (0, 0, 460, 45), 3)
    print("zooms: exe_theme_light/dark、exe_primary_light/dark、exe_titlebar_zoom", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
