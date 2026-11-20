"""从 release exe 里按尺寸取内嵌图标，出证据图（审图 15:00 第 4 条）。

为什么不用 Icon.ExtractAssociatedIcon：它只给 32×32，证明不了 Alt-Tab / 资源管理器显示的
大尺寸也是新标。这里用 PrivateExtractIcons（Windows shell 取图标的那条 API），
按 16/24/32/48/64/128/256 逐档取，再画到白底 32bpp DIB 上读回来，逐帧量主体占高。

用法（仓库根目录，release 包已构建）：
    python tool/extract_exe_icon.py
产物 docs/screenshots_v9/：
    exe_icon.png        32×32（16× 任务栏尺寸的原件）
    exe_icon_8x.png     32×32 的 8× 放大
    exe_icon_sizes_4x.png  48/64/128/256 四档并排（资源管理器/Alt-Tab 大图标用的就是这些帧）
"""

from __future__ import annotations

import ctypes
import ctypes.wintypes as wt
import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
EXE = ROOT / "build" / "windows" / "x64" / "runner" / "Release" / "lab5_crossplatformvisualdesignpractice.exe"
OUT = ROOT / "docs" / "screenshots_v9"
SIZES = (16, 24, 32, 48, 64, 128, 256)

user32 = ctypes.WinDLL("user32", use_last_error=True)
gdi32 = ctypes.WinDLL("gdi32", use_last_error=True)

user32.PrivateExtractIconsW.argtypes = [
    wt.LPCWSTR, ctypes.c_int, ctypes.c_int, ctypes.c_int,
    ctypes.POINTER(wt.HICON), ctypes.POINTER(wt.UINT), wt.UINT, wt.UINT,
]
user32.PrivateExtractIconsW.restype = wt.UINT
user32.GetDC.restype = ctypes.c_void_p
user32.GetDC.argtypes = [wt.HWND]
user32.ReleaseDC.argtypes = [wt.HWND, ctypes.c_void_p]
user32.DrawIconEx.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, wt.HICON,
                              ctypes.c_int, ctypes.c_int, wt.UINT, wt.HBRUSH, wt.UINT]
user32.DestroyIcon.argtypes = [wt.HICON]
gdi32.CreateCompatibleDC.restype = ctypes.c_void_p
gdi32.CreateCompatibleDC.argtypes = [ctypes.c_void_p]
gdi32.CreateDIBSection.restype = ctypes.c_void_p
gdi32.CreateDIBSection.argtypes = [ctypes.c_void_p, ctypes.c_void_p, wt.UINT,
                                   ctypes.POINTER(ctypes.c_void_p), wt.HANDLE, wt.DWORD]
gdi32.SelectObject.restype = ctypes.c_void_p
gdi32.SelectObject.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
gdi32.DeleteObject.argtypes = [ctypes.c_void_p]
gdi32.DeleteDC.argtypes = [ctypes.c_void_p]


class BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [
        ("biSize", wt.DWORD), ("biWidth", wt.LONG), ("biHeight", wt.LONG),
        ("biPlanes", wt.WORD), ("biBitCount", wt.WORD), ("biCompression", wt.DWORD),
        ("biSizeImage", wt.DWORD), ("biXPelsPerMeter", wt.LONG), ("biYPelsPerMeter", wt.LONG),
        ("biClrUsed", wt.DWORD), ("biClrImportant", wt.DWORD),
    ]


def extract(size: int) -> Image.Image:
    hicon = wt.HICON()
    icon_id = wt.UINT()
    count = user32.PrivateExtractIconsW(str(EXE), 0, size, size,
                                        ctypes.byref(hicon), ctypes.byref(icon_id), 1, 0)
    if count == 0 or not hicon:
        raise SystemExit(f"{size}px 取不到图标（PrivateExtractIcons 返回 {count}）")

    screen_dc = user32.GetDC(None)
    mem_dc = gdi32.CreateCompatibleDC(screen_dc)
    bmi = BITMAPINFOHEADER()
    bmi.biSize = ctypes.sizeof(BITMAPINFOHEADER)
    bmi.biWidth = size
    bmi.biHeight = -size  # top-down
    bmi.biPlanes = 1
    bmi.biBitCount = 32
    bmi.biCompression = 0  # BI_RGB
    bits = ctypes.c_void_p()
    dib = gdi32.CreateDIBSection(mem_dc, ctypes.byref(bmi), 0, ctypes.byref(bits), None, 0)
    if not dib:
        raise SystemExit("CreateDIBSection 失败")
    old = gdi32.SelectObject(mem_dc, dib)

    # 白底：本工程图标就是白底红标，先刷白再叠图标
    buf = (ctypes.c_ubyte * (size * size * 4)).from_address(bits.value)
    for i in range(0, size * size * 4, 4):
        buf[i] = buf[i + 1] = buf[i + 2] = buf[i + 3] = 255
    user32.DrawIconEx(mem_dc, 0, 0, hicon, size, size, 0, None, 0x0003)  # DI_NORMAL

    data = bytes(buf)
    gdi32.SelectObject(mem_dc, old)
    gdi32.DeleteObject(dib)
    gdi32.DeleteDC(mem_dc)
    user32.ReleaseDC(None, screen_dc)
    user32.DestroyIcon(hicon)

    # DIB 的字节序是 BGRA，按 "BGRA" 原始模式读，否则红蓝会被换掉
    img = Image.frombuffer("RGBA", (size, size), data, "raw", "BGRA", 0, 1).convert("RGB")
    return img


def ink_stats(im: Image.Image) -> str:
    px = im.load()
    xs, ys = [], []
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = px[x, y]
            if r > 240 and g > 240 and b > 240:
                continue
            xs.append(x)
            ys.append(y)
    if not xs:
        return "空白"
    w = max(xs) - min(xs) + 1
    h = max(ys) - min(ys) + 1
    return f"主体 {w}x{h} 占高 {h / im.height:.0%} 留白 左{min(xs)}/右{im.width - max(xs) - 1}"


def main() -> None:
    if not EXE.exists():
        raise SystemExit(f"找不到 {EXE}")
    OUT.mkdir(parents=True, exist_ok=True)
    frames = {size: extract(size) for size in SIZES}

    frames[32].save(OUT / "exe_icon.png")
    frames[32].resize((32 * 8, 32 * 8), Image.NEAREST).save(OUT / "exe_icon_8x.png")

    big = [48, 64, 128, 256]
    pad = 16
    width = sum(frames[s].width for s in big) + pad * (len(big) + 1)
    height = max(frames[s].height for s in big) + pad * 2
    sheet = Image.new("RGB", (width, height), (238, 234, 226))
    x = pad
    for size in big:
        sheet.paste(frames[size], (x, (height - size) // 2))
        x += size + pad
    sheet.save(OUT / "exe_icon_sizes_4x.png")

    lines = [f"exe 内嵌图标（PrivateExtractIcons，{EXE.name}）"]
    for size in SIZES:
        lines.append(f"  {size:>3}px  {ink_stats(frames[size])}")
    text = "\n".join(lines)
    print(text)
    with open(OUT / "exe_icon_check.txt", "w", encoding="utf-8") as fh:
        fh.write(text + "\n")


if __name__ == "__main__":
    main()
