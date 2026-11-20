"""构建并打包 Windows release 产物到 dist/Lab5-办公-Windows。

为什么需要这一步：`flutter build windows --release` 的图标字体子集只按 Assets 清单
判断是否重建，增量构建会把旧子集原样打进去（见 tool/verify_icon_font.py 的说明）。
手工「build 完直接拷 dist」就会把缺 glyph 的包发出去 —— 上一版 dist 里的空圆圈就是这么来的。

流程：
1. `flutter build windows --release`；
2. `tool/verify_icon_font.py` 校验 glyph 覆盖与字体新旧；
3. 失败且原因是「字体比源码旧」→ 自动 `flutter clean` 重来一次（只重试一次）；
4. 把 exe / data / flutter_windows.dll 拷到 --out，exe 改名成 Lab5办公.exe。

用法：
    python tool/package_windows.py              # 构建 + 校验 + 打包到 dist/Lab5-办公-Windows
    python tool/package_windows.py --skip-build  # 只校验 + 用现有 build 打包
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build" / "windows" / "x64" / "runner" / "Release"
DEFAULT_EXE = "lab5_crossplatformvisualdesignpractice.exe"
PACKED_EXE = "Lab5办公.exe"
DEFAULT_OUT = ROOT / "dist" / "Lab5-办公-Windows"


def run(cmd: list[str]) -> int:
    # shell=True：Windows 上的 flutter 是 flutter.bat，CreateProcess 不能直接执行 .bat
    print("$", " ".join(cmd), flush=True)
    return subprocess.call(subprocess.list2cmdline(cmd), shell=True, cwd=ROOT)


def verify() -> int:
    return run([sys.executable, str(ROOT / "tool" / "verify_icon_font.py")])


def build() -> None:
    code = run(["flutter", "build", "windows", "--release"])
    if code != 0:
        raise SystemExit(f"flutter build windows 失败：{code}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--skip-build", action="store_true")
    args = ap.parse_args()

    if not args.skip_build:
        build()
        if verify() != 0:
            print("校验没过：清掉 build/ 后重建一次（图标字体子集只能靠 clean 刷新）", flush=True)
            if run(["flutter", "clean"]) != 0:
                raise SystemExit("flutter clean 失败")
            build()
            if verify() != 0:
                raise SystemExit("重建后图标字体仍然不对，停下来人工看")

    exe = BUILD / DEFAULT_EXE
    if not exe.exists():
        raise SystemExit(f"没有构建产物：{exe}")

    out = args.out
    out.mkdir(parents=True, exist_ok=True)
    if (out / "data").exists():
        shutil.rmtree(out / "data")
    shutil.copytree(BUILD / "data", out / "data")
    for name in ("flutter_windows.dll", "native_assets.json"):
        src = BUILD / name
        if src.exists():
            shutil.copy2(src, out / name)
    shutil.copy2(exe, out / PACKED_EXE)

    total = sum(p.stat().st_size for p in out.rglob("*") if p.is_file())
    print(f"\n打包完成：{out}")
    print(f"  {PACKED_EXE}            {(out / PACKED_EXE).stat().st_size / 1024:.0f} KB")
    print(f"  flutter_windows.dll    {(out / 'flutter_windows.dll').stat().st_size / 1048576:.1f} MB")
    print(f"  合计                   {total / 1048576:.0f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
