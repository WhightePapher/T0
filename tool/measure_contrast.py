"""从截图里量「文字 / 底色」对比度。

方法（和审图一致）：在每个区块的矩形里取「出现次数最多的颜色」当底色，
取「与该底色相对亮度差最大的像素」当字色，按 WCAG 2.x 相对亮度算比值。

用法：
    python tool/measure_contrast.py docs/screenshots_v5/08_transition_210ms.png
    python tool/measure_contrast.py --batch docs/screenshots_v4 docs/screenshots_v5
"""

from __future__ import annotations

import os
import sys
from collections import Counter

from PIL import Image

# 1440×900 视口下的区块（x1, y1, x2, y2），左闭右开
BLOCKS = {
    '步骤名「材料输入」12px': (126, 87, 192, 105),
    '数字圈「1」': (98, 86, 122, 108),
    '主标题（两行）': (96, 200, 700, 340),
    '副标题': (96, 352, 500, 376),
    '项目卡标题': (205, 472, 400, 494),
    '项目卡元信息': (205, 502, 430, 522),
    '右卡标题「三步」': (1048, 470, 1110, 496),
    '右卡 01 说明': (1048, 545, 1300, 568),
    '主 CTA 文字': (1200, 328, 1320, 356),
}

# 05 / 06 交付检查：左卡口径三行 + 右侧红色胶囊 + 徽章
DELIVERY_BLOCKS = {
    '已就绪 4/5（含 1 待确认）11px': (150, 452, 372, 468),
    '待补充 1 个模块 20px': (140, 484, 380, 506),
    '说明段「结论总结」11px': (150, 516, 372, 533),
    '红胶囊「待补充」11px': (1246, 722, 1302, 750),
    '徽章「2 项待处理」10.5px': (1252, 281, 1321, 310),
}


def channel(c: int) -> float:
    v = c / 255
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def luminance(rgb) -> float:
    return 0.2126 * channel(rgb[0]) + 0.7152 * channel(rgb[1]) + 0.0722 * channel(rgb[2])


def block_contrast(img: Image.Image, box) -> tuple[float, tuple, tuple]:
    crop = img.crop(box).convert('RGB')
    pixels = list(crop.getdata())
    counts = Counter(pixels)
    bg = counts.most_common(1)[0][0]
    lbg = luminance(bg)

    # 字色取「与底色亮度差最大、且出现次数够多（>=12 px，排除反锯齿零星点）的那种像素」。
    # 不用「出现最多的非底色」：格子纸网格线 / 虚线框的出现面积比字还大。
    candidates = [(n, p) for p, n in counts.items() if p != bg and n >= 12]
    if not candidates:
        candidates = [(n, p) for p, n in counts.items() if p != bg]
    fg = max(candidates, key=lambda t: abs(luminance(t[1]) - lbg))[1]
    lfg = luminance(fg)
    hi, lo = max(lbg, lfg), min(lbg, lfg)
    return (hi + 0.05) / (lo + 0.05), bg, fg


def report(path: str, blocks: dict | None = None) -> dict[str, float]:
    blocks = blocks or BLOCKS
    img = Image.open(path)
    out: dict[str, float] = {}
    print(f'\n{os.path.basename(path)}')
    print(f'  {"区块":<18}{"比值":>7}  {"底色":<9}{"字色":<9}')
    for name, box in blocks.items():
        ratio, bg, fg = block_contrast(img, box)
        out[name] = ratio
        print(
            f'  {name:<16}{ratio:>7.2f}  '
            f'#{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}   #{fg[0]:02X}{fg[1]:02X}{fg[2]:02X}'
        )
    return out


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    blocks = DELIVERY_BLOCKS if '--delivery' in sys.argv else BLOCKS
    files: list[str] = []
    for a in args:
        if os.path.isdir(a):
            files += [
                os.path.join(a, f)
                for f in sorted(os.listdir(a))
                if f.endswith('.png')
            ]
        else:
            files.append(a)
    if not files:
        raise SystemExit('给一个 png，或一个目录')
    for f in files:
        report(f, blocks)


if __name__ == '__main__':
    main()
