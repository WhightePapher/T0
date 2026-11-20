"""校验 Windows 产物里的 MaterialIcons 子集是否还在 —— 防止「空圆圈」回归。

背景（t_4d8e0f52 P1）：Windows release 的图标字体子集写在
`build/windows/x64/runner/Release/data/flutter_assets/fonts/MaterialIcons-Regular.otf`，
它是**按 Assets 清单**判断要不要重生成的，Dart 代码里新加一个 `Icons.xxx` 并不会让它失效。
于是增量构建（`build/` 没清过）会把旧子集原样打进产物：

    dist/Lab5-办公-Windows/.../MaterialIcons-Regular.otf   3104 B / 26 码位
    → 缺 0xf162 (light_mode_outlined) 和 0xef9f (dark_mode_outlined)
    → 白天模式的主题按钮只剩一个描边空圈

同一个源码全新建（干净的 build/）产出的是 27 码位、两个码位都在。

本脚本做三件事：
1. 扫 `lib/` 里所有 `Icons.<name>`；
2. 从 Flutter SDK 的 `icons.dart` 查到每个名字的码位；
3. 读产物的 `cmap`，逐个比对；缺失就列出名字 + 码位并以 1 退出。

另外比对字体文件与 `lib/` 最新 Dart 文件的 mtime：字体比代码旧，说明构建复用了旧子集，
直接判失败（提示 `flutter clean` 后重建），不等到肉眼发现图标没了。

用法：
    python tool/verify_icon_font.py                       # 查 build/windows/.../Release
    python tool/verify_icon_font.py --bundle dist/Lab5-办公-Windows
    python tool/verify_icon_font.py --font some/MaterialIcons-Regular.otf
"""

from __future__ import annotations

import argparse
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_BUNDLE = ROOT / "build" / "windows" / "x64" / "runner" / "Release"
FONT_REL = Path("data") / "flutter_assets" / "fonts" / "MaterialIcons-Regular.otf"

ICON_USE = re.compile(r"\bIcons\.([A-Za-z_][A-Za-z0-9_]*)")
ICON_DEF = re.compile(r"static const IconData (\w+)\s*=\s*IconData\(\s*(0x[0-9A-Fa-f]+)", re.S)


def flutter_sdk() -> Path:
    """从 `flutter` 可执行文件的位置反推 SDK 根目录。"""
    import shutil

    exe = shutil.which("flutter")
    if not exe:
        raise SystemExit("PATH 里找不到 flutter")
    return Path(exe).resolve().parent.parent


def used_icons(lib: Path) -> dict[str, list[str]]:
    """{icon 名: [出现位置]}，位置只用来报错时定位。"""
    found: dict[str, list[str]] = {}
    for path in sorted(lib.rglob("*.dart")):
        text = path.read_text(encoding="utf-8", errors="ignore")
        for lineno, line in enumerate(text.splitlines(), 1):
            # 只扫代码，注释里提到 Icons.xxx 不算使用（否则文档注释会造出假缺失）
            code = line.split("//", 1)[0]
            for name in ICON_USE.findall(code):
                found.setdefault(name, []).append(
                    f"{path.relative_to(ROOT)}:{lineno}"
                )
    return found


def icon_codepoints(icons_dart: Path) -> dict[str, int]:
    text = icons_dart.read_text(encoding="utf-8", errors="ignore")
    return {name: int(cp, 16) for name, cp in ICON_DEF.findall(text)}


def font_codepoints(font: Path) -> set[int]:
    """只解析 cmap（format 4 / 12），不依赖 fontTools。"""
    data = font.read_bytes()
    num_tables = struct.unpack(">H", data[4:6])[0]
    tables: dict[str, tuple[int, int]] = {}
    for i in range(num_tables):
        off = 12 + i * 16
        tag = data[off : off + 4].decode("latin1")
        _, offset, length = struct.unpack(">III", data[off + 4 : off + 16])
        tables[tag] = (offset, length)
    if "cmap" not in tables:
        raise SystemExit(f"{font} 里没有 cmap 表")
    off, length = tables["cmap"]
    cmap = data[off : off + length]
    _, count = struct.unpack(">HH", cmap[:4])
    points: set[int] = set()
    for i in range(count):
        _, _, sub = struct.unpack(">HHI", cmap[4 + i * 8 : 12 + i * 8])
        fmt = struct.unpack(">H", cmap[sub : sub + 2])[0]
        if fmt == 4:
            seg_x2 = struct.unpack(">H", cmap[sub + 6 : sub + 8])[0]
            seg = seg_x2 // 2
            ends = struct.unpack(f">{seg}H", cmap[sub + 14 : sub + 14 + seg_x2])
            starts = struct.unpack(
                f">{seg}H", cmap[sub + 16 + seg_x2 : sub + 16 + 2 * seg_x2]
            )
            for start, end in zip(starts, ends):
                if start != 0xFFFF:
                    points.update(range(start, end + 1))
        elif fmt == 12:
            groups = struct.unpack(">I", cmap[sub + 12 : sub + 16])[0]
            for g in range(groups):
                base = sub + 16 + g * 12
                start, end, _ = struct.unpack(">III", cmap[base : base + 12])
                points.update(range(start, end + 1))
    return points


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--bundle", type=Path, default=None, help="含 data/flutter_assets 的产物目录")
    ap.add_argument("--font", type=Path, default=None, help="直接指定 otf")
    ap.add_argument("--lib", type=Path, default=ROOT / "lib")
    ap.add_argument("--sdk", type=Path, default=None)
    ap.add_argument("--allow-stale", action="store_true", help="只查缺字，不查字体文件新旧")
    args = ap.parse_args()

    font = args.font or ((args.bundle or DEFAULT_BUNDLE) / FONT_REL)
    if not font.exists():
        print(f"找不到图标字体：{font}")
        print("先跑 flutter build windows --release")
        return 1

    sdk = args.sdk or flutter_sdk()
    icons_dart = sdk / "packages" / "flutter" / "lib" / "src" / "material" / "icons.dart"
    if not icons_dart.exists():
        print(f"找不到 SDK 的 icons.dart：{icons_dart}（用 --sdk 指定）")
        return 1

    used = used_icons(args.lib)
    defs = icon_codepoints(icons_dart)
    present = font_codepoints(font)

    unknown = sorted(name for name in used if name not in defs)
    missing = sorted(
        (defs[name], name, used[name][0])
        for name in used
        if name in defs and defs[name] not in present
    )

    print(f"图标字体   {font}  ({font.stat().st_size} B / {len(present)} 码位)")
    print(f"lib/ 用到  {len(used)} 个 Icons.*")
    if unknown:
        print(f"⚠ SDK 里查不到定义：{', '.join(unknown)}")

    stale = False
    if not args.allow_stale:
        newest = max(
            (p.stat().st_mtime, p) for p in args.lib.rglob("*.dart")
        )
        if font.stat().st_mtime < newest[0]:
            stale = True
            from datetime import datetime

            print(
                "✗ 图标字体比源码旧：字体 "
                f"{datetime.fromtimestamp(font.stat().st_mtime):%Y-%m-%d %H:%M:%S}"
                f" < {newest[1].relative_to(ROOT)} "
                f"{datetime.fromtimestamp(newest[0]):%Y-%m-%d %H:%M:%S}"
            )
            print("  这是增量构建复用了旧子集：flutter clean 后重跑构建（或跑 tool/package_windows.py）")

    if missing:
        print(f"✗ 缺 {len(missing)} 个 glyph：")
        for cp, name, where in missing:
            print(f"    0x{cp:04x}  Icons.{name:<24} 首见 {where}")
        return 1

    print("✓ 所有用到的图标都在字体子集里")
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
