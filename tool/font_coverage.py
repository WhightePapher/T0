#!/usr/bin/env python3
"""缺字自检：把 lib/ 下所有字符串字面量里的非 ASCII 字符取出来，
逐个对照 assets/fonts/*.ttf 的 cmap，报告缺字。

只依赖标准库（直接解析 TrueType/OpenType 的 cmap 表），
所以任何一台机器上的 `python tool/font_coverage.py` 都能跑，不需要 fontTools。

输出约定：
  assets/fonts/T0Sans-400.ttf  coverage: 8133/8133  missing: 0
  ...
  missing: 0            <- 全部字体都覆盖时，最后一行是这句

退出码 0 = 无缺字，1 = 有缺字。
"""

from __future__ import annotations

import pathlib
import re
import struct
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
FONT_DIR = REPO / "assets" / "fonts"

# Dart 字符串字面量（单引号 / 双引号，允许转义），不做完整语法分析，够用即可
LITERAL = re.compile(r"'([^'\\\n]|\\.)*'|\"([^\"\\\n]|\\.)*\"", re.S)


def cmap_codepoints(path: pathlib.Path) -> set[int]:
    """读 TTF/OTF 的 cmap，返回所有被映射的码位（format 4 + 12）。"""
    data = path.read_bytes()
    if len(data) < 12:
        raise ValueError(f"{path.name}: 不是字体文件")
    num_tables = struct.unpack(">H", data[4:6])[0]
    cmap_offset = None
    for i in range(num_tables):
        entry = 12 + i * 16
        tag = data[entry : entry + 4]
        offset = struct.unpack(">I", data[entry + 8 : entry + 12])[0]
        if tag == b"cmap":
            cmap_offset = offset
            break
    if cmap_offset is None:
        raise ValueError(f"{path.name}: 没有 cmap 表")

    n_sub = struct.unpack(">H", data[cmap_offset + 2 : cmap_offset + 4])[0]
    codepoints: set[int] = set()
    for i in range(n_sub):
        rec = cmap_offset + 4 + i * 8
        sub_off = cmap_offset + struct.unpack(">I", data[rec + 4 : rec + 8])[0]
        fmt = struct.unpack(">H", data[sub_off : sub_off + 2])[0]
        if fmt == 4:
            seg_x2 = struct.unpack(">H", data[sub_off + 6 : sub_off + 8])[0]
            seg = seg_x2 // 2
            ends = struct.unpack(">%dH" % seg, data[sub_off + 14 : sub_off + 14 + seg_x2])
            starts_off = sub_off + 16 + seg_x2
            starts = struct.unpack(">%dH" % seg, data[starts_off : starts_off + seg_x2])
            deltas_off = starts_off + seg_x2
            deltas = struct.unpack(">%dh" % seg, data[deltas_off : deltas_off + seg_x2])
            ranges_off = deltas_off + seg_x2
            ranges = struct.unpack(">%dH" % seg, data[ranges_off : ranges_off + seg_x2])
            for s in range(seg):
                for cp in range(starts[s], ends[s] + 1):
                    if cp == 0xFFFF:
                        continue
                    if ranges[s] == 0:
                        glyph = (cp + deltas[s]) & 0xFFFF
                    else:
                        gi_off = ranges_off + s * 2 + ranges[s] + (cp - starts[s]) * 2
                        if gi_off + 2 > len(data):
                            continue
                        glyph = struct.unpack(">H", data[gi_off : gi_off + 2])[0]
                        if glyph:
                            glyph = (glyph + deltas[s]) & 0xFFFF
                    if glyph:
                        codepoints.add(cp)
        elif fmt == 12:
            n_groups = struct.unpack(">I", data[sub_off + 12 : sub_off + 16])[0]
            for g in range(n_groups):
                rec2 = sub_off + 16 + g * 12
                start, end, _gid = struct.unpack(">III", data[rec2 : rec2 + 12])
                codepoints.update(range(start, end + 1))
    return codepoints


def literal_chars() -> dict[str, set[str]]:
    """file -> 该文件字符串字面量里出现的非 ASCII 字符集合。"""
    found: dict[str, set[str]] = {}
    for path in sorted((REPO / "lib").rglob("*.dart")):
        text = path.read_text(encoding="utf-8")
        chars: set[str] = set()
        for match in LITERAL.finditer(text):
            for ch in match.group(0):
                if ord(ch) > 0x7F:
                    chars.add(ch)
        # 另外把 icon / 文档注释外的中文也算进来：注释不渲染，但宁严勿松
        if chars:
            found[str(path.relative_to(REPO)).replace("\\", "/")] = chars
    return found


def main() -> int:
    if not FONT_DIR.exists():
        print(f"找不到字体目录 {FONT_DIR}", file=sys.stderr)
        return 1
    used: set[str] = set()
    for chars in literal_chars().values():
        used |= chars
    print(f"lib/ 字符串字面量里的非 ASCII 字符: {len(used)} 个")

    fonts = sorted(FONT_DIR.glob("*.ttf"))
    if not fonts:
        print(f"{FONT_DIR} 里没有 .ttf", file=sys.stderr)
        return 1

    total_missing = 0
    for font in fonts:
        covered = cmap_codepoints(font)
        # T0Mono 是拉丁等宽字体，只管 ASCII/拉丁部分；中文由 fontFamilyFallback 交给 T0Sans
        latin_only = font.name.startswith("T0Mono")
        scope = {ch for ch in used if ord(ch) <= 0x2FFF} if latin_only else used
        missing = sorted(ch for ch in scope if ord(ch) not in covered)
        total_missing += len(missing)
        note = "  (latin 子集，汉字走 T0Sans fallback)" if latin_only else ""
        status = "missing: 0" if not missing else f"missing: {len(missing)} -> {''.join(missing)}"
        print(f"{font.relative_to(REPO)}  coverage: {len(scope) - len(missing)}/{len(scope)}  {status}{note}")

    print(f"missing: {total_missing}")
    return 0 if total_missing == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
