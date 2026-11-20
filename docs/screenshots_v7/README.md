# 主题过渡帧实测（screenshots_v7）· 主按钮不再闪黑闪白 + 弧 / 字兜底

基线：`main @ 9ff1b6f`；本卡分支 `wt/t_4d8e0f52`。
产物：Flutter web `--release`，1440×900 / DPR 1，无头 Chrome + CDP screencast 取帧。

## 0. 服务自证

```bash
$ md5sum build/web/main.dart.js
0a9846a6a101f8da90e803fd69bec1b8 *build/web/main.dart.js
$ curl -s http://127.0.0.1:8141/main.dart.js | md5sum
0a9846a6a101f8da90e803fd69bec1b8 *-
```

```bash
cd build/web && python -m http.server 8141 --bind 127.0.0.1 &
T0_SHOTS=screenshots_v7 python tool/shoot_theme_screens.py http://127.0.0.1:8141/index.html
python tool/measure_transition_fill.py
```

本目录只放过渡帧（`07`–`10` + `transition_timeline.txt`）；同一构建的静态页在 `docs/screenshots_v5/`。

## 1. 逐帧实测（`tool/measure_transition_fill.py`）

CTA 区域 = `(1171, 314) – (1343, 369)`（在 `workbench_light.png` 里按 accent 绿定位，四帧同一块）。

| 文件 | 标称 | 实测动画时间 | CTA 底色 | CTA 上字色 | 字/底 | CTA 内纯黑% | CTA 内纯白% |
|---|---|---|---|---|---|---|---|
| `07_t105.png` | 105ms | **108ms** | `#298D70` | `#000000` | **5.14** | 1.72 | 0.0 |
| `08_t120.png` | 120ms | **121ms** | `#2B8F72` | `#000000` | **5.27** | 1.72 | 0.0 |
| `09_t210.png` | 210ms | **210ms** | `#3EA07F` | `#1B1620` | **5.53** | 0.0 | 0.0 |
| `10_t315.png` | 315ms | **318ms** | `#4DAE8A` | `#1B1620` | **6.54** | 0.0 | 0.0 |

读法：

- **CTA 底色四帧全是绿系插值**（`#298D70 → #2B8F72 → #3EA07F → #4DAE8A`），没有 `#000000` / `#FFFFFF`；
  CTA 区域内的纯黑只有 105/120ms 的 1.72%，那是**字**（`onFill` 在交叉窄带用的纯黑字，5.14 / 5.27:1），
  不是底色。210ms 起字色回到设计深字 `#1B1620`。
- 全帧仍有 1.28% 纯黑（105/120ms）/ 1.27% 纯白（210ms）：是**大标题和正文**的前景兜底
  （中灰底上只有亮度极值能读），面积是笔画，不是填充块；设计说明里有专节解释。

## 2. 改法（不动版式）

| 文件 | 改动 |
|---|---|
| `lib/theme/palette.dart` | 新增面字段 `accentFill` / `accentStrongFill`（和 bg / surface 一样的 420ms 插值，不经过 anchor）；新增 `onFill(fill)`（按底色亮度选字色，三段阈值保证 ≥4.5）；新增 `readableFill(fill, bg, min)`（填充色对底色不够对比时往黑 / 白推一档）；中灰段的前景兜底改为**每帧在纯黑 / 纯白里挑对比度更高的那个**（深色侧优先 `#E8E4EE`，撑不到 4.5 才用纯白） |
| `lib/widgets/primary_button.dart` | 底色 `accent` / `accentStrong` → `accentFill` / `accentStrongFill`；字色 `onAccent` → `onFill(background)` |
| `lib/widgets/progress_ring.dart` | 弧色 = `readableFill(accentFill, track, min: 3.0)`：过渡中段弧对卡面 ≥3:1（改前 1.35:1）；环内数字用 `ink`，对卡面 9:1 以上 |
| `lib/widgets/app_shell.dart` | 步骤点激活态底色 `accent` → `accentFill`、数字 → `onFill(accentFill)` |
| `lib/features/workspace/workspace_page.dart` | 3px 进度条 `accent` → `accentFill` |

`test/widget_test.dart` 逐帧断言：`accentFill` 只在两端绿之间移动、`onFill/accentFill` ≥4.5、
`readableFill` 弧 ≥3:1、`muted/surface` ≥4.5。

## 3. 图

| 文件 | 实测 | 页面底色 | md5 |
|---|---|---|---|
| `07_t105.png` | 108ms | `#B0AAAA` | `f1b42563d160c3ba61890b8f41023fff` |
| `08_t120.png` | 121ms | `#A9A3A4` | `300e01e609b5778c3681e062cdf02eb4` |
| `09_t210.png` | 210ms | `#69616B` | `7f8487c9f6e1bf3b92b83fc810a03c63` |
| `10_t315.png` | 318ms | `#342C3C` | `150458c41e92b247608a785f1c594b9d` |
| `transition_timeline.txt` | — | — | screencast 每帧的动画时间 / 页面底色 |
