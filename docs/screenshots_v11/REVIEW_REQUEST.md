# REVIEW REQUEST · Lab5 r7（分支 `wt/t_0549455d`）

- 分支：**`wt/t_0549455d`**（worktree `D:/Projects/Lab5_CrossPlatformVisualDesignPractice/.worktrees/t_0549455d`，基线 main `ad03048`，本批提交 `d15ac67` + `10c8093`）
- 范围：只收 4 件事（05 页脚压字 / 环旁小字 / 三栏色线 / 按压按钮 / 页眉小标 —— 卡片编号 #1–#5），不加功能、不改配色体系、不动图标
- 证据：`docs/screenshots_v11/`（15 张图 + `measurements.txt` + `positions.json` + `README.md`）；逐条改动与改前改后实测在 `README.md`
- 出图口径：1440×900 / DPR 1；`build/web/main.dart.js` md5 `5e1f1d3682cc44e4be791c46c32ff55e`（脚本落盘前比对了磁盘与 HTTP，一致才出图）

## 1. 四条验收命令的真实输出

### ① `flutter analyze`

```
$ flutter analyze
Analyzing t_0549455d...
No issues found! (ran in 5.2s)
```

### ② `flutter test`

```
$ flutter test
00:18 +64: .../test/topbar_test.dart: 顶栏圆形按钮尺寸统一 1440 下主题与加号都是 36×36
00:18 +65: .../test/topbar_test.dart: 顶栏圆形按钮尺寸统一 500 下主题与菜单按钮也都是 36×36
00:19 +66: .../test/topbar_test.dart: 切主题 白天 ↔ 黑夜：这一段的字色 / 底色跟着变，位置不变
00:20 +67: All tests passed!
```

新增 `test/r7_layout_test.dart`（3 条版面契约：05 卡底到页脚线 ≥20px / 三栏色线等长 / 按住按钮矩形不变），
另把 `test/widget_test.dart` 里两处断言跟着变了口径（环旁文案改「已确认 3 个模块」；纸卡中文小标 15px 在 0.71 下仍 ≥10px）。

### ③ `flutter build web --release`

```
$ flutter build web --release
Compiling lib\main.dart for the Web...                            166.0s
√ Built build\web
$ md5sum build/web/main.dart.js
5e1f1d3682cc44e4be791c46c32ff55e *build/web/main.dart.js
```

### ④ `python tool/shoot_v11.py http://127.0.0.1:8124/index.html`（尾部）

```
main.dart.js  disk=5e1f1d3682cc http=5e1f1d3682cc OK
05_workspace_light.png  md5=df896ae5fb74  166KB
05_workspace_light_scrolled.png  md5=7d2d086a6ed9  163KB
press_01_light.png  md5=0ccf999befc5  185KB
press_02_light.png  md5=22383e8df2a2  176KB
press_02_columns_2x.png  md5=6eef25eb40c2  11KB
press_03_compare_modal.png  md5=3e06c1bc534f  149KB
press_03_compare_columns_2x.png  md5=9d87264365c5  22KB
05_workspace_dark.png  md5=81ab228985fb  167KB
已整目录替换 → D:\Projects\...\.worktrees\t_0549455d\docs\screenshots_v11
$ ls docs/screenshots_v11
05_toolbar_zoom_2x.png      05_workspace_dark.png       05_workspace_light.png
05_workspace_light_scrolled.png  header_t0_4x.png       measurements.txt
positions.json              press_01_button_2x.png      press_01_light.png
press_02_button_2x.png      press_02_columns_2x.png     press_02_light.png
press_03_compare_columns_2x.png  press_03_compare_modal.png
press_button_compare_2x.png workbench_ring.png          workbench_ring_2x.png
README.md                   REVIEW_REQUEST.md
```

这批图与 r6（`docs/screenshots_v9/`）同名文件 md5 全部不同（对照表在 `README.md` §1）。

## 2. 逐条结论

| # | 结论 | 一句话证据（详细数字见 `README.md`） |
|---|---|---|
| #1 05 纸卡末行被页脚切掉 | **已修** | 默认缩放 0.82→**0.71**；纸卡底边 y=797、页脚线 y=831 → 间距 **34px**（改前卡底应在 886、被压 55px，图上连成一片量不到卡底）；滚到底 100px；缩放控件显示 **71%**（`05_toolbar_zoom_2x.png`） |
| #2 环旁「已确认 3/5」重复 | **已修** | 文案改「已确认 **3 个模块**」，环内 3/5 保留；字面 79×11px，字号/字色不变（`workbench_ring_2x.png`） |
| #3 三栏色线不等长 | **已修** | 158/159/173（极差 15）→ **142/142/142（极差 0）**；首栏线色按原型回 **`#147A62`**，舞台与弹层两处渲染器一起改（`press_02_columns_2x.png`、`press_03_compare_columns_2x.png`） |
| #4 按压瞬间按钮变形 | **已修** | 胶囊两态 x=821 / 821、宽 110 / 111（+1px 是右边缘抗锯齿；改前 110→78、左边界 +32）；按下只换底色描边（`press_button_compare_2x.png`） |
| #5 页眉小标过小 | **已修** | 8px 等宽 → **sans 12px w600**；字面高 7px→**9px**，对比度 5.36→**7.07:1**，`0` 的中孔可辨（`header_t0_4x.png`）；弹层缩略图同款小标 7px→sans 9px |

另外按审图要求补进 `docs/视觉设计说明.md:67-70`：**深色主题不影响 deck 纸面**（`#EBE6DB` / `#FFFDF8` / `#17211F` 与浅色逐像素相同，只有外壳跟主题），这是既定口径、不是漏改；`05_workspace_dark.png` 与浅色那张的 797 / 831 完全一致。

## 3. 需要 owner 决定 / 已知项

1. 纸卡页脚那行「修改说明：… / 版本 2」仍是 7.5px 等宽（71% 下约 5.3px）。#5 只点名页眉小标，
   改这一行会推动纸卡的三段式版心，所以本轮没动 —— 要不要下一轮一起提？
2. 对比弹层里的正文仍是 7.5px（缩略图尺寸），本轮只把小标提到 9px sans；
   如果希望弹层正文也按屏幕可读字号走，需要重排那块缩略图的版心。
3. 三栏色线的 142px 是默认 71% 缩放下的值；换成 0.82 / 100% 会等比变长，三栏恒等长（有测试守着）。

## 4. 复核入口

```bash
cd D:/Projects/Lab5_CrossPlatformVisualDesignPractice/.worktrees/t_0549455d
git log --oneline -3            # 10c8093 / d15ac67 / ad03048
flutter analyze && flutter test
cat docs/screenshots_v11/measurements.txt
```
