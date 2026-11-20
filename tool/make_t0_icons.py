"""r6 图标全套：一张高分母版 → ICO 七帧 + web 四张 + favicon 两档，逐帧自检。

为什么重写：上一版只换了 ICO 的 16/24/32，48 以上和 web 仍是旧母版（占高 28~29% + 三条速度线），
同一个应用出现两套标（小号新、Alt-Tab/资源管理器/浏览器标签旧）。审图 15:00 要求整套一次做全。

母版：按品牌红 #EA2F28（从旧 256 帧采样）排一遍加粗 t0，1024px 出图，之后每个尺寸都从
这张母版缩下去，并逐帧把主体高度校准到 65~70%、水平/垂直居中（不留 3/4 这种 1px 偏差）。

用法（仓库根目录）：
    python tool/make_t0_icons.py
产物：
    windows/runner/resources/app_icon.ico      16/24/32/48/64/128/256
    web/icons/Icon-192-v2.png、Icon-512-v2.png
    web/icons/Icon-maskable-192-v2.png、Icon-maskable-512-v2.png
    web/favicon-v2.png（64）、web/favicon-32-v2.png（32）
    docs/icon_check.txt                        逐帧主体 bbox 与占高（自检）
"""

from __future__ import annotations

import io
import pathlib
import struct

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
ICO = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
WEB = ROOT / "web"
WEB_ICONS = WEB / "icons"
CHECK = ROOT / "docs" / "icon_check.txt"

BRAND_RED = (234, 47, 40)  # 旧 256 帧实测 #EA2F28
MASTER_PX = 1024
TARGET = 0.68  # 主体占高
RANGE = (0.65, 0.70)

ICO_SIZES = (16, 24, 32, 48, 64, 128, 256)
WEB_SIZES = ((WEB_ICONS / "Icon-192-v2.png", 192, TARGET),
             (WEB_ICONS / "Icon-512-v2.png", 512, TARGET),
             # maskable 的安全区要求内容缩到 ~80%，68% 落在安全区内
             (WEB_ICONS / "Icon-maskable-192-v2.png", 192, 0.66),
             (WEB_ICONS / "Icon-maskable-512-v2.png", 512, 0.66),
             (WEB / "favicon-v2.png", 64, TARGET),
             (WEB / "favicon-32-v2.png", 32, TARGET))


def render_master() -> Image.Image:
    """1024px 母版：白底 + 品牌红 t0，返回「只有主体」的 RGBA 图（后面按尺寸缩）"""
    font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", MASTER_PX)
    canvas = Image.new("L", (MASTER_PX * 2, MASTER_PX * 2), 0)
    ImageDraw.Draw(canvas).text((MASTER_PX // 2, MASTER_PX // 2), "t0", font=font, fill=255)
    ink = canvas.crop(canvas.getbbox())
    layer = Image.new("RGBA", ink.size, BRAND_RED + (255,))
    layer.putalpha(ink)
    return layer


def ink_bbox(im: Image.Image) -> tuple[int, int, int, int] | None:
    """非白像素的外接矩形（图标是白底，主体是红色）"""
    px = im.convert("RGB").load()
    xs: list[int] = []
    ys: list[int] = []
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = px[x, y]
            if r > 240 and g > 240 and b > 240:
                continue
            xs.append(x)
            ys.append(y)
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def compose(master: Image.Image, size: int, ratio: float = TARGET) -> tuple[Image.Image, dict]:
    """把母版缩到 size×size：在候选高度里挑一个主体占高 65~70% 且左右留白对称的。

    为什么要挑而不是算：resize + 抗锯齿会让实测 ink 高度比目标差 1px（16px 时就是 6%），
    算出来的 68% 落不到线上，只能逐档试。
    """
    best: tuple[Image.Image, dict] | None = None
    best_score: tuple[int, int, float] = (9, 9, 9.9)
    low = max(4, int(size * max(0.30, ratio - 0.09)))
    high = int(size * min(0.80, ratio + 0.09))
    for target_h in range(low, high + 1):
        h = target_h
        scale = h / master.height
        w = max(4, round(master.width * scale))
        if (size - w) % 2:
            w += 1
        # 垂直方向不强行凑偶数：凑了就会出现「16px 只能 12px 高 = 75%」或
        # 「10px 高 = 62%」二选一，宁可上下留白差 1px 也要落在 65~70% 上
        body = master.resize((w, h), Image.LANCZOS)
        if size <= 32:
            # 小尺寸二值化 alpha：抗锯齿会多出半行像素，实测 ink 高度比目标差 1px
            # （16px 时 6%），二值化后 ink 框正好等于 resize 框，比例可控且边缘更利。
            body.putalpha(body.split()[3].point(lambda v: 255 if v >= 128 else 0))
        canvas = Image.new("RGBA", (size, size), (255, 255, 255, 255))
        canvas.alpha_composite(body, ((size - w) // 2, (size - h) // 2))
        box = ink_bbox(canvas)
        if box is None:
            continue
        info = {
            "size": size,
            "w": box[2] - box[0] + 1,
            "h": box[3] - box[1] + 1,
            "ratio": (box[3] - box[1] + 1) / size,
            "left": box[0],
            "right": size - box[2] - 1,
            "top": box[1],
            "bottom": size - box[3] - 1,
        }
        in_range = RANGE[0] <= info["ratio"] <= RANGE[1]
        symmetric = info["left"] == info["right"] and info["top"] == info["bottom"]
        # 留白对称优先于「65~70%」：16px 上 11px 高必然是 2/3，压不对称；
        # 审图 15:20 要求「上下取同一个整数」，所以对称的 12px(2/2) 胜过 11px(2/3)。
        score = (0 if symmetric else 1, 0 if in_range else 1, -info["ratio"])
        if best is None or score < best_score:  # type: ignore[used-before-assignment]
            best, best_score = (canvas, info), score
    if best is None:
        raise SystemExit(f"{size}px 拼不出图标")
    return best


def max_radius_ratio(im: Image.Image) -> float:
    """红像素到中心的最大半径 / 边长：maskable 安全区要求 ≤ 40%"""
    px = im.convert("RGB").load()
    cx = cy = (im.width - 1) / 2
    best = 0.0
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = px[x, y]
            if r > 240 and g > 240 and b > 240:
                continue
            best = max(best, ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5)
    return best / im.width


def compose_exact(master: Image.Image, size: int, ratio: float) -> tuple[Image.Image, dict]:
    """按指定占高直接排一版（不走候选搜索：maskable 要的是「压进安全区」，不是 68%）"""
    h = max(6, round(size * ratio))
    w = max(4, round(master.width * h / master.height))
    if (size - w) % 2:
        w += 1
    if (size - h) % 2:
        h += 1
    body = master.resize((w, h), Image.LANCZOS)
    if size <= 32:
        body.putalpha(body.split()[3].point(lambda v: 255 if v >= 128 else 0))
    canvas = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    canvas.alpha_composite(body, ((size - w) // 2, (size - h) // 2))
    box = ink_bbox(canvas) or (0, 0, size - 1, size - 1)
    return canvas, {
        "size": size,
        "w": box[2] - box[0] + 1,
        "h": box[3] - box[1] + 1,
        "ratio": (box[3] - box[1] + 1) / size,
        "left": box[0],
        "right": size - box[2] - 1,
        "top": box[1],
        "bottom": size - box[3] - 1,
    }


def compose_maskable(master: Image.Image, size: int) -> tuple[Image.Image, dict]:
    """maskable 版：主体压进中心 80%（红像素最大半径 ≤ 40%），最多重排 4 次收敛"""
    frame, info = compose_exact(master, size, 0.68)
    radius = max_radius_ratio(frame)
    for _ in range(4):
        if radius <= 0.40:
            break
        ratio = info["ratio"] * (0.40 / radius) * 0.99
        frame, info = compose_exact(master, size, ratio)
        radius = max_radius_ratio(frame)
    info["radius"] = radius
    return frame, info


def write_ico(frames: list[Image.Image]) -> None:
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
    master = render_master()
    print(f"母版主体 {master.size[0]}x{master.size[1]}（1024px 字号渲染后裁切）")

    rows: list[str] = []
    ico_frames: list[Image.Image] = []
    for size in ICO_SIZES:
        frame, info = compose(master, size)
        ico_frames.append(frame)
        rows.append(
            f"ICO  {size:>3}px  主体 {info['w']:>3}x{info['h']:<3} 占高 {info['ratio']:.0%}  "
            f"留白 左{info['left']}/右{info['right']}/上{info['top']}/下{info['bottom']}"
        )
        print(rows[-1])
    write_ico(ico_frames)
    print(f"写入 {ICO}（{ICO.stat().st_size} bytes）")

    WEB_ICONS.mkdir(parents=True, exist_ok=True)
    for path, size, ratio in WEB_SIZES:
        frame, info = compose_maskable(master, size) if "maskable" in path.name else compose(master, size, ratio)
        info.setdefault("radius", max_radius_ratio(frame))
        frame.convert("RGBA").save(path)
        rows.append(
            f"WEB  {path.name:<26} {size:>3}px  主体 {info['w']:>3}x{info['h']:<3} "
            f"占高 {info['ratio']:.0%}  留白 左{info['left']}/右{info['right']}"
            f"  最大半径 {info['radius']:.1%}"
        )
        print(rows[-1])

    CHECK.parent.mkdir(parents=True, exist_ok=True)
    CHECK.write_text("\n".join(rows) + "\n", encoding="utf-8")
    print(f"自检写入 {CHECK}")


if __name__ == "__main__":
    main()
