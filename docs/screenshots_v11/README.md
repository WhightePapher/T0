# r7 批次（2026-11-13，分支 `wt/t_0549455d`）· 05 页脚压字 + 3 条 r6 遗留

- worktree：`D:/Projects/Lab5_CrossPlatformVisualDesignPractice/.worktrees/t_0549455d`
- 分支：**`wt/t_0549455d`**（基线 main `ad03048`，本批两个提交 `d15ac67` / `10c8093`）
- 构建：`flutter build web --release` → `build/web/main.dart.js` md5 `5e1f1d3682cc44e4be791c46c32ff55e`
- 出图：1440×900 / DPR 1，无头 Chrome + CDP（`tool/shoot_v11.py`），静态服务 8124，指向本 worktree 的 `build/web`
- 出图脚本先写 `docs/screenshots_v11_tmp/`，整批成功后**整目录替换** `docs/screenshots_v11/`（审图不会读到半成品）

## 0. 服务自证（截的就是这份构建）

```
$ md5sum build/web/main.dart.js
5e1f1d3682cc44e4be791c46c32ff55e *build/web/main.dart.js
$ python tool/shoot_v11.py http://127.0.0.1:8124/index.html
main.dart.js  disk=5e1f1d3682cc http=5e1f1d3682cc OK      ← 不一致脚本会拒绝落盘
...
已整目录替换 → D:\Projects\...\.worktrees\t_0549455d\docs\screenshots_v11
```

## 1. 本批文件登记（一条一行）

| 文件 | 证明哪一条 | md5（前 12） |
|---|---|---|
| `05_workspace_light.png` | #1 浅色：默认 71%、未滚动，纸卡末行完整、卡底可见、与页脚线 34px | `df896ae5fb74` |
| `05_workspace_dark.png` | #1 深色同一条（deck 纸面刻意不跟主题变） | `81ab228985fb` |
| `05_workspace_light_scrolled.png` | #1 滚到底：间距 100px，滚动后也不压字 | `7d2d086a6ed9` |
| `05_toolbar_zoom_2x.png` | #1 缩放控件显示 **71%**（不是 82%） | `69b5397fee76` |
| `press_01_light.png` | #3/#4 的母图：v1 纸卡三栏 + 悬浮态按钮 | `0ccf999befc5` |
| `press_02_light.png` | #3/#4 的母图：按住态（画布切 v1 + 按钮按下） | `22383e8df2a2` |
| `press_02_columns_2x.png` | #3 三栏色线 2×：三段 142px 等长、首栏品牌绿 `#147A62` | `6eef25eb40c2` |
| `press_button_compare_2x.png` | #4 两态按钮同框 2×：左边界 / 宽度不动 | `b468e0976e40` |
| `press_01_button_2x.png` / `press_02_button_2x.png` | #4 同一裁剪框的两张原图 | `950dd0e0bdbc` / `82771ff9e777` |
| `press_03_compare_modal.png` | #5 第二个渲染面：对比弹层整屏 | `3e06c1bc534f` |
| `press_03_compare_columns_2x.png` | #5/#3 弹层缩略图：页眉小标 sans 9px、三栏首栏也是绿 | `9d87264365c5` |
| `header_t0_4x.png` | #5 页眉「t0 / CONTROLLED SLIDES」4×，`0` 的中孔可辨 | `0f394b0746ee` |
| `workbench_ring.png` / `workbench_ring_2x.png` | #2 环 +「已确认 3 个模块」整屏 / 2× | `3cc059116e85` / `c9b8cc8f8154` |
| `measurements.txt` | 本批全部量数的原始输出（含 r6 基线复量） | `2e6a53f96e0a` |
| `positions.json` | 语义树里的元素矩形（缩放控件 / 按钮两态 / 纸卡带） | `28e437cc1dba` |

**这批是 r7 自己的图**，与 r6（`docs/screenshots_v9/`）同名文件逐字节不同：

| 同名 | v11（本批） | v9（r6） |
|---|---|---|
| `05_workspace_light.png` | `df896ae5fb74` | `1bb5197e81c0` |
| `05_workspace_dark.png` | `81ab228985fb` | `5f1180152c32` |
| 按住态整屏（v11 `press_02_light` / v9 `press_02_holding`） | `22383e8df2a2` | `93617b4aaa65` |
| 对比弹层（v11 `press_03_compare_modal` / v9 `press_04_compare_modal`） | `3e06c1bc534f` | `16bb1a9d831d` |
| 环 2×（v11 `workbench_ring_2x` / v9 `11_workbench_ring_2x`） | `c9b8cc8f8154` | `920e2f86e5ef` |

## 2. 逐条：改了什么 · 文件与行 · 改前改后实测

### #1（P1）05 模块工作区：纸张卡末行被页脚分隔线切掉 → 已修（默认缩放 0.82 → 0.71）

- `lib/models/mock_data.dart:402-407`：`zoom` 初值 `0.82` → **`0.71`**（注释里写了算式）
- `lib/models/mock_data.dart:532`：`reset()` 里的 `zoom.value` 同步 0.71
- 连带 `lib/features/workspace/workspace_page.dart:863-874`：纸卡左上中文小标 13px → **15px**
  （0.71 下 13px 只剩 9.2px，低于 r4 定的「屏幕 ≥10px」；15×0.71 = 10.65px，与 r4 同一档）

实测（同一把尺子量图，`measurements.txt`）：

| 量什么 | 改前（`docs/screenshots_v9/05_workspace_light.png`，0.82，r6 构建） | 改后（本批，0.71） |
|---|---|---|
| 内容纸卡 top | y=554 | y=510 |
| 纸卡卡底 | **量不到**：0.82 下卡高 332px，卡底应在 y=886，而页脚分隔线在 y=831 → **纸卡被页脚压住 55px**，图上纸卡与页脚同色连成一片 | y=797（卡底边在画布底色 `#EBE6DB` 上可辨） |
| 页脚分隔线 | y=831 | y=831 |
| **卡底 → 页脚分隔线** | **0**（连成一片） | **34px**（浅色）/ **34px**（深色）/ **100px**（滚到底） |
| 末行正文（03 视线有落点 的说明）字底 → 页脚线 | 1px（r6 审图实测 y=830 → 831） | **80px**（widget 层实测 832 − 752.1；图上同一行在 y≈752） |
| 缩放控件显示 | 82% | **71%**（语义树 `71%` @ x=633..677，见 `05_toolbar_zoom_2x.png`） |

深色那张与浅色逐像素同值（卡底 797 / 页脚 831），因为 **deck 纸面不跟主题变**（见 §4）。

### #2（P2）工作台环旁「已确认 3/5」与环内重复 → 已修

- `lib/widgets/project_card.dart:78-86`：`'已确认 ${project.done}/${project.total}'` → **`'已确认 ${project.done} 个模块'`**
- 环内 `'${project.done}/${project.total}'` 保留（`project_card.dart:92-99` 未动）
- 两个环（3/5 与 2/4）共用这一个组件，所以两处写法一起变
- 实测：小字字面 bbox (844,490)-(923,501) = **79×11px**，字色 `ink2Strong`（11px，字号/字色与 r4 定的不变）；卡片语义文案 =「…已确认 3 个模块 3/5」→ 分数只在环里出现一次
- 图：`workbench_ring_2x.png`（「已确认 3 个模块」+ 环内「3/5」），整屏 `workbench_ring.png`
- 测试：`test/widget_test.dart:435-452`（`find.text('已确认 3/5')` 断言已改为「不存在」）

### #3（P2）press_02 纸卡三栏色线不等长 → 已修（并回品牌绿）

- `lib/features/workspace/workspace_page.dart:994-1012`：色线移出 `Padding`，`Row` 改 `spacing: 18` + 三栏等分
  （原来前两栏 `Padding(right:18)` 把线裁短、末栏 `right:0` 没裁）
- 同处首栏线色 `deckInk #17211F` → **`deckAccent #147A62`**（原型色）；二三栏 `deckWarn #D56C3D` / `deckLilac #315D9D` 不变
- 弹层缩略图的同一处也改（`workspace_page.dart:1263-1267`），两处渲染器色序一致
- 实测（屏幕上，默认 71%，`press_02_light.png` y=646 行）：

| | 三栏线长 | 极差 | 线色 |
|---|---|---|---|
| 改前（v9 `press_02_holding.png`，0.82，r6） | **158 / 159 / 173 px** | 15px | 墨 / 橙 / 蓝 |
| 改后（本批，0.71） | **142 / 142 / 142 px** | **0px** | **`#147A62` / `#D56C3D` / `#315D9D`** |

- 图：`press_02_columns_2x.png`（三栏 2×，三段等长）、`press_03_compare_columns_2x.png`（弹层同款）
- 测试：`test/r7_layout_test.dart`「三栏色线等长」直接量三个 `Expanded` 的宽度，spread < 0.5

### #4（P2）按压瞬间工具条按钮变形 → 已修

- `lib/features/workspace/workspace_page.dart:1712-1762`：`_HoldCompare` 的文案改放进 `Stack`，
  按下态垫一层透明的长文案占位（`Opacity(0)`），两种状态宽度都按最长那句排
- 按下只换底色 / 描边（`ink` 填充 + `ink` 描边），不动几何
- 实测（像素，同一裁剪框 `x=809..944`，`press_button_compare_2x.png`）：

| | 胶囊左边界 | 胶囊宽度 |
|---|---|---|
| 悬浮（长文案） | x=821 | **110px** |
| 按住（短文案） | x=821 → **差 0px** | 111px（右侧抗锯齿多 1px；原来是 78px） |
| 参照 r6 审图（改前） | x=822 → 853（+32px） | 110 → 78（−32px） |

- 按下态文案「修改前」在固定宽度胶囊里居中（语义 x 853.6→869.7，宽 64.5→32.2），按钮本体不动
- 测试：`test/r7_layout_test.dart`「按住按钮不变形」断言矩形宽度与左边界差 < 0.5

### #5（P2）幻灯片页眉「t0 / CONTROLLED SLIDES」过小 → 已修

- `lib/features/workspace/workspace_page.dart:688-703`：新增 `_eyebrow()` = **sans 12px / w600 / 字距 1.0**
  （原 8–9px 等宽 Cascadia Mono）
- 应用处：封面页 `:724/:729`、纸卡页 `:874/:879`；纸卡中文小标「结构压缩版」15px（`_eyebrow` 的另一支）
- 同款小标的第二个渲染面（对比弹层缩略图，1:1 无缩放）7px 等宽 → **sans 9px w600**（`:1199-1218`）
- 封面页小标透明度 0.55 → 0.66（同一处小标的可读性，改色值 token 一点没动）

| 量什么 | 改前（v9，0.82） | 改后（本批，0.71） |
|---|---|---|
| 字面高（屏幕上） | **7px** | **9px**（100% 缩放下 12px） |
| 对比度（字 vs 封面 `#17211F`） | 5.36:1 | **7.07:1** |
| 字体 | Cascadia Mono（0 的中孔被压死，读成 t8） | Noto Sans（0 的椭圆中孔清楚） |

- 图：`header_t0_4x.png`（4× 放大，`t0` 的 `0` 中孔可辨）、`press_03_compare_columns_2x.png`（弹层里同一处）

### 深色 deck 口径（审图要求补的一句）

`docs/视觉设计说明.md:67-70` 追加：**深色主题不影响 deck 纸面** —— 切到黑夜后舞台底色仍是 `#EBE6DB`、
纸卡 `#FFFDF8`、封面 `#17211F`，与浅色逐像素相同；只有顶栏 / 侧栏 / AI 面板 / 页脚跟着主题变。
本批实测印证：`05_workspace_light.png` 与 `05_workspace_dark.png` 的纸卡底边都是 y=797、页脚上边框都是 y=831。

## 3. 复现

```bash
cd D:/Projects/Lab5_CrossPlatformVisualDesignPractice/.worktrees/t_0549455d
flutter analyze                 # No issues found!
flutter test                    # 67 项全绿
flutter build web --release     # md5 5e1f1d3682cc…
cd build/web && python -m http.server 8124 --bind 127.0.0.1 &
cd ../.. && python tool/shoot_v11.py http://127.0.0.1:8124/index.html
```

`tool/shoot_v11.py` 落盘前先比对磁盘与 HTTP 的 `main.dart.js` md5，不一致直接退出；
图先写 `screenshots_v11_tmp/`，全部成功才整目录替换，并把上一版的 `README.md` / `REVIEW_REQUEST.md` 带过去。

## 4. 已知项 / 未动

- 纸卡页脚那行「修改说明：… / 版本 2」仍是 7.5px 等宽（0.71 下约 5.3px），本轮未动：
  #5 只点名页眉小标，这一行改了会让纸卡三段式版心跟着动。
- 对比弹层里正文仍是 7.5px（缩略图尺寸），本轮只把小标提到 9px sans。
- 三栏色线长度 142px 是 0.71 缩放下的值；0.82 / 100% 下会等比变长，但三栏永远等长（layout 契约在测试里）。
