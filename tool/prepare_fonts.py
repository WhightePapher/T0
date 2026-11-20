#!/usr/bin/env python3
"""把系统里的 Noto Sans SC / Noto Serif SC / Cascadia Mono 子集化 + 静态实例化成
`assets/fonts/*.ttf`，供 Flutter web 离线内嵌使用。

为什么需要这一步：
  Flutter web（CanvasKit）不认系统字体名，字体必须随应用打包；
  但完整的 Noto SC 变量字体一个就 17-25 MB。这里按
  「所有 lib/ 里出现过的字符 + GB2312 全字表 + ASCII/标点」做子集，
  再把变量字体实例化成固定字重（CanvasKit 对 VF 的字重轴支持不稳定，
  静态实例可以保证 FontWeight 真的有对应字重）。

用法（仅开发期需要，不是运行时依赖）：
  uv venv .venv-fonts && uv pip install --python .venv-fonts/Scripts/python.exe fonttools
  .venv-fonts/Scripts/python.exe tool/prepare_fonts.py

产物直接提交进仓库，构建机不需要 fontTools。
"""

from __future__ import annotations

import argparse
import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
SRC = pathlib.Path(r"C:\Windows\Fonts")
OUT = REPO / "assets" / "fonts"

# (源文件, 输出前缀, 需要生成的静态字重)
JOBS = [
    ("NotoSansSC-VF.ttf", "T0Sans", [400, 600, 700]),
    ("NotoSerifSC-VF.ttf", "T0Serif", [700]),
    ("CascadiaMono.ttf", "T0Mono", [400, 500]),
]

EXTRA = (
    # ASCII / 拉丁补充 / 通用标点 / 箭头 / 几何 / CJK 标点 / 全角
    (0x0020, 0x00FF),
    (0x2000, 0x206F),
    (0x2190, 0x21FF),
    (0x25A0, 0x25FF),
    (0x3000, 0x303F),
    (0xFF00, 0xFFEF),
)


def gb2312_chars() -> set[str]:
    """GB2312 全部有效双字节组合（6763 汉字 + 符号）。"""
    out: set[str] = set()
    for hi in range(0xA1, 0xF8):
        for lo in range(0xA1, 0xFF):
            try:
                out.add(bytes([hi, lo]).decode("gb2312"))
            except UnicodeDecodeError:
                continue
    return out


def source_chars() -> set[str]:
    """lib/ 下所有源码里出现的字符（宁多勿少，注释里的也一起收）。"""
    out: set[str] = set()
    for path in (REPO / "lib").rglob("*.dart"):
        out.update(path.read_text(encoding="utf-8"))
    return out


def build_charset() -> set[str]:
    chars = gb2312_chars() | source_chars()
    for lo, hi in EXTRA:
        chars.update(chr(c) for c in range(lo, hi + 1))
    return {c for c in chars if c not in "\r\n\t"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    from fontTools import subset
    from fontTools.ttLib import TTFont
    from fontTools.varLib import instancer

    charset = build_charset()
    unicode_list = sorted(ord(c) for c in charset)
    print(f"charset: {len(unicode_list)} code points")
    OUT.mkdir(parents=True, exist_ok=True)

    for src_name, prefix, weights in JOBS:
        src = SRC / src_name
        if not src.exists():
            print(f"!! missing source font {src}", file=sys.stderr)
            return 1
        for weight in weights:
            dst = OUT / f"{prefix}-{weight}.ttf"
            if args.dry_run:
                print(f"would write {dst.name}")
                continue
            font = TTFont(str(src))
            if "fvar" in font:
                font = instancer.instantiateVariableFont(font, {"wght": weight}, inplace=True)
            # OS/2 字重同步，避免渲染端再按 400 处理
            if "OS/2" in font:
                font["OS/2"].usWeightClass = weight
            options = subset.Options()
            options.layout_features = ["*"]
            options.name_IDs = ["*"]
            options.notdef_outline = True
            options.recalc_bounds = True
            subsetter = subset.Subsetter(options=options)
            subsetter.populate(unicodes=unicode_list)
            subsetter.subset(font)
            font.flavor = None
            font.save(str(dst))
            print(f"{dst.name}: {dst.stat().st_size / 1024:.0f} KB (wght {weight})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
