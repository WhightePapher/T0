"""用一张源图生成 Flutter 三端应用图标。

用法：python tool/make_icons.py "D:\\pictures\\素材\\T0.png"
产物：web/icons/*.png、web/favicon.png、windows/runner/resources/app_icon.ico、
      android/app/src/main/res/mipmap-*/ic_launcher.png
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent

WHITE = (255, 255, 255)

# Web 图标文件名带版本号：浏览器与 service worker 会按 URL 缓存旧 favicon，
# 改名是唯一可靠的穿透手段（manifest.json / index.html 里的引用要同步改）
ICON_SUFFIX = "-v2"


def load_logo(src: Path, margin_ratio: float = 0.10) -> Image.Image:
    """裁掉白边，居中放到正方形白底上，四周留 margin_ratio 的边距。"""
    im = Image.open(src).convert("RGBA")
    # 白底当背景：找出非白区域
    bg = Image.new("RGBA", im.size, WHITE + (255,))
    diff = Image.new("L", im.size, 0)
    px, bgpx, dp = im.load(), bg.load(), diff.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r1, g1, b1, a1 = px[x, y]
            r2, g2, b2, _ = bgpx[x, y]
            dp[x, y] = 255 if (a1 > 16 and (abs(r1 - r2) + abs(g1 - g2) + abs(b1 - b2)) > 24) else 0
    box = diff.getbbox()
    if not box:
        raise SystemExit("源图里找不到非白内容")
    logo = im.crop(box)

    # 贴到正方形白底
    side = int(max(logo.size) / (1 - 2 * margin_ratio))
    canvas = Image.new("RGB", (side, side), WHITE)
    logo_rgb = Image.new("RGB", logo.size, WHITE)
    logo_rgb.paste(logo, mask=logo.split()[3])
    canvas.paste(logo_rgb, ((side - logo.width) // 2, (side - logo.height) // 2))
    return canvas


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    src = Path(sys.argv[1])
    if not src.exists():
        print("源图不存在:", src)
        return 1

    master = load_logo(src)
    print("裁切后正方形:", master.size)

    # ---- Web ----
    icons_dir = ROOT / "web" / "icons"
    icons_dir.mkdir(parents=True, exist_ok=True)
    for name, size in ((f"Icon-192{ICON_SUFFIX}.png", 192), (f"Icon-512{ICON_SUFFIX}.png", 512)):
        master.resize((size, size), Image.LANCZOS).save(icons_dir / name)
    # maskable：内容缩到 60%，留出安全区
    for name, size in ((f"Icon-maskable-192{ICON_SUFFIX}.png", 192), (f"Icon-maskable-512{ICON_SUFFIX}.png", 512)):
        inner = int(size * 0.60)
        canvas = Image.new("RGB", (size, size), WHITE)
        canvas.paste(master.resize((inner, inner), Image.LANCZOS),
                     ((size - inner) // 2, (size - inner) // 2))
        canvas.save(icons_dir / name)
    master.resize((48, 48), Image.LANCZOS).save(ROOT / "web" / f"favicon{ICON_SUFFIX}.png")
    print("web 图标完成")

    # ---- Windows .ico ----
    ico = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    master.save(ico, format="ICO", sizes=sizes)
    print("windows app_icon.ico 完成:", ico.stat().st_size, "bytes")

    # ---- Android mipmaps ----
    dens = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for name, size in dens.items():
        d = ROOT / "android" / "app" / "src" / "main" / "res" / f"mipmap-{name}"
        d.mkdir(parents=True, exist_ok=True)
        master.resize((size, size), Image.LANCZOS).save(d / "ic_launcher.png")
    print("android mipmap 完成:", ", ".join(dens))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
