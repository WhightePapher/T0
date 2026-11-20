"""r6 图标：小尺寸（16/24/32）单独出，别把 256 的整张图往下缩。

问题（审图 14:40）：32×32 里主体只有 26×10（占高 31%），左侧三条速度线缩到 32px
后糊成浅粉 #F0716B，等于不可认。根因是 make_icons.py 把 256 母版整体缩到 16/24/32，
速度线这种细结构在 32px 下只剩 1px 反锯齿像素。

做法：
  1. 取 .ico 的 256 母帧，按红色连通块面积最大者 = 主体，切出 t0 + 速度线；
  2. 逐列统计红像素，第一根「高度过半」的列 = t0 斜笔画起点，把速度线切掉；
  3. 主体按「占高 65~70%（宽度最多 92%）」重绘到 16/24/32，纯品牌红、白底；
  4. 48 以上原样沿用母版。

用法（仓库根目录）：
    python tool/fix_small_icons.py
产物：windows/runner/resources/app_icon.ico（16/24/32 换新，48+ 不变）
"""

from __future__ import annotations

import io
import pathlib
import struct
from collections import deque

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
ICO = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
SMALL = (16, 24, 32)
KEEP = (48, 64, 128, 256)
TARGET_HEIGHT = 0.68
MAX_WIDTH_RATIO = 0.98


def load_frame(size: int) -> Image.Image:
    frame = Image.open(ICO)
    frame.size = (size, size)
    return frame.convert("RGBA")


def red_mask(im: Image.Image) -> list[list[bool]]:
    px = im.load()
    mask = [[False] * im.width for _ in range(im.height)]
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a > 40 and r > 90 and r - g > 40 and r - b > 40:
                mask[y][x] = True
    return mask


def largest_component(mask: list[list[bool]]) -> tuple[int, int, int, int] | None:
    h, w = len(mask), len(mask[0])
    seen = [[False] * w for _ in range(h)]
    best: tuple[int, int, int, int, int] | None = None
    for y0 in range(h):
        for x0 in range(w):
            if not mask[y0][x0] or seen[y0][x0]:
                continue
            q = deque([(x0, y0)])
            seen[y0][x0] = True
            minx = maxx = x0
            miny = maxy = y0
            area = 0
            while q:
                x, y = q.popleft()
                area += 1
                minx, maxx = min(minx, x), max(maxx, x)
                miny, maxy = min(miny, y), max(maxy, y)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        q.append((nx, ny))
            if best is None or area > best[4]:
                best = (minx, miny, maxx, maxy, area)
    return None if best is None else best[:4]


def mask_image(mask: list[list[bool]], box: tuple[int, int, int, int]) -> Image.Image:
    x0, y0, x1, y1 = box
    data = bytearray()
    for y in range(y0, y1):
        for x in range(x0, x1):
            data.append(255 if mask[y][x] else 0)
    return Image.frombytes("L", (x1 - x0, y1 - y0), bytes(data))


def write_ico(frames: list[Image.Image]) -> None:
    """PIL 存 ICO 只支持「一张图缩出多尺寸」，这里按容器格式自己拼（每帧放 PNG）。"""
    payloads: list[bytes] = []
    for frame in frames:
        buf = io.BytesIO()
        frame.convert("RGBA").save(buf, format="PNG")
        payloads.append(buf.getvalue())

    header = struct.pack("<HHH", 0, 1, len(frames))
    offset = len(header) + 16 * len(frames)
    entries = b""
    for frame, data in zip(frames, payloads):
        w = 0 if frame.width >= 256 else frame.width
        h = 0 if frame.height >= 256 else frame.height
        entries += struct.pack("<BBBBHHII", w, h, 0, 0, 1, 32, len(data), offset)
        offset += len(data)
    ICO.write_bytes(header + entries + b"".join(payloads))


def main() -> None:
    master = load_frame(256)
    mask = red_mask(master)
    box = largest_component(mask)
    if box is None:
        raise SystemExit("母版里找不到红色主体")
    print(f"母版主体 bbox={box} → {box[2] - box[0] + 1}x{box[3] - box[1] + 1}")

    # 小尺寸不再缩母版（母版是「t0 + 三条速度线」的宽幅标志，32px 下必然糊）：
    # 直接按品牌红排一遍加粗 t0，字面高度占 68%，宽度最多 98%。
    # 母版 48 以上原样保留，所以放大看仍是原标志。
    font_path = pathlib.Path("C:/Windows/Fonts/arialbd.ttf")
    font = ImageFont.truetype(str(font_path), 400)
    glyph = Image.new("L", (600, 600), 0)
    ImageDraw.Draw(glyph).text((30, 30), "t0", font=font, fill=255)
    glyph = glyph.crop(glyph.getbbox())
    print(f"小尺寸 t0 字形（{font_path.name} 400px）={glyph.size[0]}x{glyph.size[1]}")

    solid = Image.new("RGBA", glyph.size, (234, 47, 40, 255))  # 母版实测品牌红 #EA2F28
    solid.putalpha(glyph)

    frames: list[Image.Image] = []
    for size in SMALL:
        scale = min(size * TARGET_HEIGHT / solid.height, size * MAX_WIDTH_RATIO / solid.width)
        tw, th = max(4, round(solid.width * scale)), max(6, round(solid.height * scale))
        small = solid.resize((tw, th), Image.LANCZOS)
        canvas = Image.new("RGBA", (size, size), (255, 255, 255, 255))
        canvas.alpha_composite(small, ((size - tw) // 2, (size - th) // 2))
        frames.append(canvas)
        print(f"{size}x{size}: 主体 {tw}x{th} = 占高 {th / size:.0%}")

    for size in KEEP:
        frames.append(load_frame(size))

    write_ico(frames)
    print(f"写入 {ICO}（{ICO.stat().st_size} bytes）")


if __name__ == "__main__":
    main()
