# r6 批次（2026-11-13，分支 `wt/t_37d23f97`）· 按住对比 / 主题掉帧 / 图标

分支 **`wt/t_37d23f97`**（worktree `.worktrees/t_37d23f97`，基线 main `f2cda22`）·
1440×900 / DPR 1 · 无头 Chrome + CDP · 静态服务 8123（本 worktree 的 `build/web`）
审图正文见 `REVIEW_REQUEST.md`；本文件保留逐条改动 + 数字。

## 本批文件登记（一条一行）

| 文件 | 证明什么 |
|---|---|
| `press_01_hover.png` | 悬浮 1.2s：画布仍是 v2、无胶囊（原 `01_hover.png` 改名） |
| `press_02_holding.png` | 按住：画布切 v1 + 胶囊 + 徽章 v1（原 `02_holding.png` 改名） |
| `press_04_compare_modal.png` | 前后对比弹层：双栏并排、版本号紧跟列头（原 `04_compare_modal.png` 改名） |
| `press_05_v1_title_2x.png` | v1 纸卡标题 2×：两行、末行不是孤字 |
| `press_diff.txt` | 差异像素 36007 / 间隙 13px / 复位 md5 相同 / 左边界 96=96 / 深色底纹差 5 |
| `exe_icon.png` | release exe 内嵌图标 32×32，主体 26×22（占高 69%，留白 3/3） |
| `exe_icon_8x.png` | 同一张 8× 放大：加粗 t0、纯品牌红、无速度线 |
| `exe_icon_sizes_4x.png` | exe 内 48/64/128/256 四档并排（资源管理器/Alt-Tab 大图标用的就是这些帧；不是 Alt-Tab 截图） |
| `exe_icon_check.txt` | 上面两张的原始量数：七档逐帧主体 bbox 与占高 |
| `docs/icon_check.txt` | 生成器自检：ICO 七帧 + web 六张逐帧占高与留白 |
| `01_workbench_light.png`（复拍） | 虚线入口 x=96 = 项目卡 x=96 |
| `01_workbench_dark.png`（复拍） | 深色底纹 `#32293B` on `#2E2536`，差 5/255 |
| `docs/perf_r6/before_*`、`after_*`、`release_*` | 帧耗时原始日志（A/B/C/D/soak），口径见 `REVIEW_REQUEST.md` 第 2 节 |

**改名对应**：`01_hover→press_01_hover`、`02_holding→press_02_holding`、`04_compare_modal→press_04_compare_modal`；
`03_released.png` 已删除（松开与悬浮本就逐像素相同，改用 `press_diff.txt` 的「复位后 md5 相同、差异 0」作证据）。

**服务自证**：`tool/shoot_r6.py` 出图前比对磁盘与 HTTP 的 `main.dart.js` md5，一致才落盘。

## 三个问题（r6 正文）

1. **按住看修改前**：`Listener` 按/松控制 + 画布二选一 v1/v2 + 150ms 淡切 + 一条 16px 胶囊。
   证据：`press_01/02/04/05` + `press_diff.txt`（间隙 13px、按住差异 36007px、松开复位 0px）。
2. **主题切换越用越卡**：根因是 `PageRoute.maintainState=true` 让逛过的页面全留在树里
   （Element 1323→4660，build p50 45→251ms，420ms 只出 1 帧）；`_fadeUpRoute` 改
   `maintainState: false` 后 Element 4660→922、build p50 251→18ms、420ms 13 帧。
   采集口径：`lib/perf/frame_stats.dart` + `--perf=A|B|C|D|E|soak` + `tool/perf_r6.py`（取中位数）。
3. **图标**：一张 1024px 母版出全套 —— ICO 16/24/32/48/64/128/256 七帧 + web
   `Icon-192/512-v2`、`Icon-maskable-*-v2`、`favicon-v2`(64)/`favicon-32-v2`(32)，
   逐帧主体占高 66~69%、留白左右对称（`docs/icon_check.txt`）；再从 release exe 用
   `PrivateExtractIcons` 取回七档复量一致（`exe_icon_check.txt` / `exe_icon_sizes_4x.png`）。
   浏览器与 service worker 按 URL 缓存旧图，部署后需硬刷一次；系统图标缓存用
   `ie4uinit.exe -show`。

---

# r4 收口实拍（历史批次，分支 `wt/t_4d7daebe`）· 2 处对比度边缘值 + 3 条已知项

分支 `wt/t_4d7daebe`（r3 已合 main `f2e30ec`）· 1440×900 / DPR 1 · 无头 Chrome + CDP
产物：本 worktree 的 `flutter build web --release`，自起 8110 端口；v8 用的 8099 / 8101 没动。

## 0. 服务自证（md5）：截的就是这份构建

```
$ md5sum build/web/main.dart.js
96386899ad3a4419469dc6fd01311ae0 *build/web/main.dart.js
$ curl -s http://127.0.0.1:8110/main.dart.js | md5sum
96386899ad3a4419469dc6fd01311ae0 *-
```

出图与量数（都在仓库根目录）：

```bash
flutter build web --release
cd build/web && python -m http.server 8110 --bind 127.0.0.1 &
python tool/shoot_v9.py http://127.0.0.1:8110/index.html   # 6 张整屏 + 8 张局部 + positions.json
python tool/measure_v9.py                                   # 本文件里所有对比度 / 内边距数字
```

`tool/measure_v9.py` 用同一把尺子量 v8（`docs/screenshots_v8/`）与 v9：取样带里出现最多的颜色当底色，
取「与底色亮度差最大且像素数 ≥12」的颜色当字色，按 WCAG 相对亮度算比值 —— 与审图、
`tool/measure_contrast.py` 同法。材料输入页 r4 版面一个像素都没挪，所以 v8 / v9 共用同一批取样带。

---

## 1. 逐条改动 + 改前改后实测

### #1（P2）深色「模拟解析失败」对比度 —— 已修

`lib/theme/palette.dart:352`：深色 `danger` `#E07A72` → `#F09189`（只动这一个 token；浅色和红胶囊一个字没动）。

| 位置 | 改前 | 改后 | 图 |
|---|---|---|---|
| 深色胶囊字 · 底 = 卡面 `#3A2F44` | `#E07A72` = **4.31** | `#F09189` = **5.46** | `02_intake_dark.png` / `07_intake_danger_dark_2x.png` |
| 浅色同一元素（对照，本轮不动） | `#A63F36` on `#FFFDF8` = 6.10 | 6.10（不变） | `02_intake_light.png` / `07_intake_danger_light_2x.png` |

同一 token 的其它配对（令牌值直算，改前 → 改后）：`surface2 #463A52` 3.62 → **4.59**、
`dangerSoft #331F24` 5.28 → 6.69、`bg #2E2536` 5.02 → 6.36。浅色 `dangerSoft` 上的红色胶囊不受影响。

### #2（P2）浅色次级色压在彩色底上的两处 —— 已修

新增令牌 `T0Palette.mutedOnTint = lerp(muted, ink, 0.15)`（`lib/theme/palette.dart:258`），
只给这两处用：`muted` / `stepMuted` 一个字没改（页面底那批配对继续按 v6/v8 的口径量）。

| 位置 | 文件:行 | 浅色 改前 | 浅色 改后 | 深色 改前 | 深色 改后 |
|---|---|---|---|---|---|
| 未选中 tab「粘贴文本」· 底 tab 轨道 `#EBE6DB` | `intake_page.dart:555` | `#68736F` = **3.95** | `#5C6763` = **4.72** | 9.24 | 8.91 |
| 文件卡 meta「14 页 · 3.2 MB…」· 底 `#DFF0E9` | `intake_page.dart:339-342` | `#68736F` = **4.16** | `#5C6763` = **4.97** | 6.73 | 6.49 |

深色两格是 `#C6BACE → #C1B7CC`（新令牌黑夜值落在 muted 与 ink2 之间）：数值略降但仍在 8.9 / 6.5，
深色原本就不吃紧；浅色这两处才是本轮要过的线。图：`02_intake_light.png`、
`08_intake_tabs_light_2x.png`、`08_intake_filecard_light_2x.png`。

### #3（已知项 6）01 工作台右卡「产品流程·三步」内边距不均 —— 已修

`lib/features/workbench/workbench_page.dart:229-234`：卡内 `Column` 由 `mainAxisSize.min` 改成
`max` + `MainAxisAlignment.center`，整列在卡内垂直居中。卡高、左列、文字、卡宽（322）都没动
（移动端是无界高度，`max` 退化成 `min`，单列布局不受影响）。

| | 卡矩形（1440×900） | 上留白 | 下留白 | 差 |
|---|---|---|---|---|
| 改前 v8 | `1023,421..1342,768` | 26px | 94px | 68px |
| 改后 v9 | `1023,421..1342,768` | **59px** | **61px** | **2px** |

（审图给的是 27 / 94，本脚本量到 26 / 94 —— 同一把尺子、差在取整与抗锯齿那一行。）
图：`01_workbench_light.png` / `01_workbench_dark.png`，局部 `10_workbench_aside_2x.png`。

### #4（已知项 7）05 纸张卡左上中文小标「结构压缩版」—— 已修

`lib/features/workspace/workspace_page.dart:768-780`：纸卡按 720×405 画、再 `FittedBox` 缩到 82%，
原来的 8px 中文落到屏幕上只剩 6.6px。中文这一版按「屏幕上 10~11px」反推：
`fontSize: 13`（13 × 0.82 ≈ **10.7**）、`height: 1.1`、`letterSpacing: 0.8`；同位置的英文小标
（版本 1）仍是 8px，没有改。

| | 字面（像素，取自截图） |
|---|---|
| 改前 v6 `03_light_模块工作区.png` | **37 × 7 px** |
| 改后 v9 `05_workspace_light.png` | **56 × 10 px** |

图：`05_workspace_light.png` / `05_workspace_dark.png`；`09_workspace_label_10x.png` 是同一块
按 10× 最近邻放大，五个字（结 / 构 / 压 / 缩 / 版）逐字可认。

> 拍 05 时先用 AI 面板真跑了一次「应用修改」（点一个建议 chip → 应用修改 → 等 toast 走完），
> 因为「结构压缩版」这个小标只在版本 2 出现；版本 1 的位置是英文 `t0 / CONTROLLED SLIDES`。
> 所以这两张图里右栏是「当前为版本 2」的状态，这是为了拍到要验的那一版，不是新加的界面。

### #5（已知项 2）工作台环旁补口径 —— 已修

`lib/widgets/project_card.dart:77-87`：环左侧加一行「已确认 3/5」（`3/5`、`2/4` 两个数都没改），
字号 11px、字色 `ink2Strong`，与交付页「已就绪 4/5（含 1 待确认）」同字号同色（同一个 `copyWith`）。

| | 字芯配色 | 对比度 |
|---|---|---|
| 浅色 | `#404A47` on 卡面 `#FFFDF8` | **9.03** |
| 深色 | `#DDD4E3` on 卡面 `#3A2F44` | **8.74** |

（11px 小字笔画芯在取样带里只有 11 个像素，按审图那把「≥12 个」的尺子会取到抗锯齿色
`#6B736F` = 4.80，也已在 `measurements.txt` 里如实列出。）
环的位置和卡高都没动：两张图里环的绿色弧外接矩形都是 `942,472..978,517`，
项目卡上下边框仍在 `448 / 541`（第二张 `556 / 649`），与 v8 逐像素相同 —— 新加的这句塞在环左边、
右对齐，没有把卡撑高。图：`01_workbench_light.png` / `01_workbench_dark.png`，
局部 `11_workbench_ring_2x.png` / `11_workbench_ring_dark_2x.png`。

---

## 2. 图 → 它证明什么

| 图 | 证明 |
|---|---|
| `01_workbench_light.png` | 环旁「已确认 3/5 / 已确认 2/4」在位；右卡内容上下留白 59 / 61；整页无其它变化 |
| `01_workbench_dark.png` | 换肤后同一几何：新加的字跟环一起落在原位，字色 `#DDD4E3` |
| `02_intake_light.png` | 未选中 tab 与文件卡 meta 用新令牌（4.72 / 4.97）；浅色「模拟解析失败」仍是 6.10 |
| `02_intake_dark.png` | 深色「模拟解析失败」`#F09189` = 5.46（本轮 P2 的正主） |
| `05_workspace_light.png` | 纸卡左上中文小标按 13px 出（屏幕 10.7px），版本 2 状态 |
| `05_workspace_dark.png` | 换肤后纸卡仍是固定 deck 配色，小标同样清楚 |
| `07_intake_danger_light_2x.png` / `07_intake_danger_dark_2x.png` | 「模拟解析失败」浅 / 深两态 2× 局部：只有字色变，描边与左右两钮同形 |
| `08_intake_tabs_light_2x.png` | tab 轨道 + 三个 tab：未选中两项变深一档，选中项仍是 ink |
| `08_intake_filecard_light_2x.png` | 文件卡整块 2×：meta 那行与标题的主次关系没被压平 |
| `09_workspace_label_10x.png` | 中文小标 10× 放大，逐字可认 |
| `10_workbench_aside_2x.png` | 右卡整卡 2×：上 59 / 下 61，三步行距仍是 16，卡高没变 |
| `11_workbench_ring_2x.png` / `11_workbench_ring_dark_2x.png` | 环 + 新口径的 2× 局部，浅深两色 |
| `measurements.txt` / `positions.json` | 上面所有数字的原始输出 + 量数用的元素矩形 |

## 3. 验收命令（真跑）

```
$ flutter analyze
Analyzing t_4d7daebe...
No issues found! (ran in 7.1s)

$ flutter test
00:16 +61: All tests passed!
```

新增的 4 条断言（`test/widget_test.dart:379 / 412 / 435 / 453`）：
`mutedOnTint` 两套主题 × 两种彩色底 ≥4.5；右卡上下留白差 ≤8px 且卡不被撑高；
环旁口径「已确认 3/5」存在且与交付页同字号同色；05 中文小标屏幕字号 ≥10px。
另外深色对比度表里补了 `danger / surface`、`danger / surface2` 两组配对。

## 4. 本轮不动 / 仍留着的已知项

- **「模拟解析失败」用词**保持「模拟」（理由写进 `docs/视觉设计说明.md`）；基线写的是「演示」，
  这是有意分歧，不是漏改。
- **v7 过渡中段层级塌陷**（105/120ms 前景同纯黑、210ms 同纯白）：对比度兜底的副作用，
  已有专节说明，本轮不动，动画曲线一个字没改 —— 所以这一批**没重拍过渡帧**。
- 已知项 1 / 3 / 4 / 5（过渡中段层级、主题图标 3.33、缺 160–200ms 采样、exe 裁切图）
  原样保留，见 `docs/视觉设计说明.md`。
- 05 的**前后对比弹层**里那行 7px 中文小标（`_compareSlide`）没改：它是弹层里的缩略对比，
  不在本卡「纸张卡左上小标」范围内；要一起改属于另一条。
