"""生成 Windows runner 的 app_icon.ico（t0 品牌标记）。

之前 `windows/runner/resources/app_icon.ico` 是 Flutter 模板自带的蓝色图标，
窗口标题栏 / 任务栏 / Alt+Tab 都是那个蓝图标，和「t0办公」的视觉没有关系。
这里按设计稿的暖纸底 + 墨色描边 + 衬线 t0 重画，多尺寸（16~256）写进同一个 ICO。

用法：
    python tool/make_app_icon.py                       # 写 windows/runner/resources/app_icon.ico
    python tool/make_app_icon.py --png docs/app_icon.png
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ICO = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"

PAPER = (246, 242, 233, 255)   # T0Palette.light.bg  #F6F2E9
INK = (23, 33, 31, 255)        # T0Palette.light.ink #17211F
GREEN = (20, 122, 98, 255)     # T0Palette.light.accent #147A62
SIZES = (16, 24, 32, 48, 64, 128, 256)
FONT_CANDIDATES = (
    r"C:/Windows/Fonts/georgiab.ttf",
    r"C:/Windows/Fonts/timesbd.ttf",
    r"C:/Windows/Fonts/constanb.ttf",
    r"C:/Windows/Fonts/segoeuib.ttf",
)


def pick_font() -> str:
    for path in FONT_CANDIDATES:
        if Path(path).exists():
            return path
    raise SystemExit("找不到可用的粗衬线字体")


def render(size: int, font_path: str) -> Image.Image:
    """按 4 倍画再缩，得到干净的抗锯齿边缘。"""
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = round(s * 0.045)
    radius = round(s * 0.20)
    d.rounded_rectangle((pad, pad, s - pad, s - pad), radius=radius, fill=PAPER,
                        outline=INK, width=max(2, round(s * 0.045)))
    # 「t0」：t 用衬线体，0 用绿色，右下角一个小方块呼应品牌
    font = ImageFont.truetype(font_path, round(s * 0.56))
    text = "t0"
    box = d.textbbox((0, 0), text, font=font)
    tw, th = box[2] - box[0], box[3] - box[1]
    x = (s - tw) / 2 - box[0]
    y = (s - th) / 2 - box[1] - s * 0.02
    d.text((x, y), "t", font=font, fill=INK)
    d.text((x + tw * 0.52, y), "0", font=font, fill=GREEN)
    d.rounded_rectangle(
        (s * 0.66, s * 0.70, s * 0.80, s * 0.84),
        radius=round(s * 0.03),
        fill=GREEN,
    )
    return img.resize((size, size), Image.LANCZOS)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--png", type=Path, default=None, help="另外导出一张 256px PNG 预览")
    args = ap.parse_args()
    font_path = pick_font()
    frames = [render(size, font_path) for size in SIZES]
    frames[-1].save(ICO, format="ICO", sizes=[(s, s) for s in SIZES])
    print(f"写入 {ICO}  尺寸 {SIZES}  大小 {ICO.stat().st_size / 1024:.1f} KB")
    if args.png:
        args.png.parent.mkdir(parents=True, exist_ok=True)
        frames[-1].save(args.png)
        print(f"预览 {args.png}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
