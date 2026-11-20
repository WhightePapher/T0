# 修复 r2 实拍（screenshots_v3）

基线：`wt/t_5f41b829` @ 53549b6（字体打包 + 28 项视觉缺陷）。本目录是 `wt/t_0ded2104` 上针对
`reviews/20261110_1432.md` 的 P0/P1/P2 共 7 项 + 1 处补漏（#1b）之后的重新出图。

产物口径：Flutter web `--release`（`build/web`，本地 `python -m http.server`），Chrome 视口 1440×900 /
500×900，DPR 1。06b 是 06 页左卡 x2 裁剪，用来核对口径小字。

## 逐条

### #1（P0）06 交付检查：80% 的交付口径说明

**没有改口径**：`settledCount`（有内容 = 已确认 + 待确认）/ `total` = 4/5 = 80% 保持不变，
改的是三处把它说成「已确认」的文字，并补写口径。

| 位置 | 改成 |
|---|---|
| `lib/features/delivery/delivery_page.dart:108-115` | 环图下新增一行小字「已就绪 4/5（含 1 待确认）」（`reviewCount>0` 才带括号，全就绪时是「已就绪 5/5」） |
| `lib/features/delivery/delivery_page.dart:120-131` | 「还差 1 个模块」→「待补充 1 个模块 / （另有 1 个待确认）」（#1b，第二轮审图补的第三处） |
| `lib/features/delivery/delivery_page.dart:135-141` | 左卡说明「其余 4 个模块**已经确认**」→「其余 4 个模块**已有内容**（其中 1 个待确认）」 |
| `lib/models/mock_data.dart:427` | 新增 `reviewCount`（待确认数），三处文案都从它取数，不再写死 |

`grep -n settledCount lib/`：只剩 `delivery_page.dart`（环图 value、口径小字、说明文）和
`mock_data.dart`（定义），全部按「有内容」表述；导出弹层原本就是「N 个已有内容」。

图：`06_交付检查.png`（默认 3/1/1 全页）、`06b_交付检查_口径小字.png`（左卡 x2 放大，口径小字可读）。

### #2（P1）05 / 08 模块工作区：标题孤字

`lib/models/mock_data.dart:294` 把模块 04 的版本 2 标题手动断行：
`compressedAccent: '\n再谈“丰富”。'`。35px 衬线标题在 632px 可用宽度里放不下 21 个字，
自动断行必然把「丰富」拆成「丰 / 富」；手动断行后第一行「让公共空间先支持“停留”，」、
第二行整句「再谈“丰富”。」。

图：`05_模块工作区.png`（桌面）、`08_窄屏_模块工作区.png`（窄屏，同一处标题也成立）。

### #3（P1）10 前后对比弹层：两栏占满可用宽度

`lib/features/workspace/workspace_page.dart:1020-1058`：`Wrap` 改成 `LayoutBuilder`——宽度够时
两栏 `Expanded` 平分（间距 16），不足 700px 时竖排（避免窄屏各栏被压到 200px 以下）；
`_CompareBox`（`workspace_page.dart:1799`）去掉写死的 `SizedBox(width: 396)`，宽度交给父级。

实测（`10_前后对比弹层.png`，y=500 行取边界像素）：左栏 290–712、右栏 728–1150，
两栏各 422，右端 1150 与「保留当前版本」按钮右端齐平。改前是 290–1097、各 395。

### #4（P2）02 材料输入：三段式轨道与内容区同边线

`lib/features/intake/intake_page.dart:93`：轨道外边距 `fromLTRB(10,10,10,0)` → `fromLTRB(24,10,24,0)`，
与下方拖拽框/文件卡/按钮的 24px 内容边对齐（改前两侧各宽出 14px）。

图：`02_材料输入.png`，轨道左缘 120、拖拽框左缘 120。

### #5（P2）06 交付检查：右栏说明拆词

`lib/features/delivery/delivery_page.dart:27-34`：380px 说明栏里的自动断行会把「模块」拆成
「模 / 块」，改成三段手动断行（14 / 16 / 15 字），每行都在 24 个全角字以内。

另外左卡说明同样会拆「内容」，改成四段手动断行（`delivery_page.dart:135-141`）。
图：`06_交付检查.png`。

### #6（P2）08 窄屏：第 5 个胶囊被切 —— 加右缘渐隐

`lib/features/workspace/workspace_page.dart:39-63`：给胶囊行加 `ScrollController` + `_stripAtEnd`
状态；`:221-224` 滚动容器右内边距 16px；`:265-292` 右缘 28px 渐变遮罩，滚到最右自动收掉。
被切掉的第 5 个胶囊现在压在渐隐下，读起来是「还能横向滚动」，不再是断字。

图：`08_窄屏_模块工作区.png`（500×900）。

### #7（P2）03 大纲确认：页数联动

`lib/models/mock_data.dart:143-149`：第 3 章「观察：三类高频使用冲突」初始 `'1 页'`（原来是 `'2 页'`，
等于没采纳就已经写进大纲）。
`lib/models/mock_data.dart:120` `copyWith` 支持 `pages`；`:476` `adoptSuggestion(..., pages:)`、
`:487` 新增 `revertSuggestion`（撤销时把要点和页数一起撤回）。
`lib/features/outline/outline_page.dart:51` 该建议带 `pages: '2 页'`；`:419-430` 采纳时写入，
`:471-479` 撤销时还原成采纳前的页数。

联动已验证（真点「采纳」）：`test/widget_test.dart` 里
「03 采纳「第 3 章拆成两页」后，大纲页数才从 1 页变 2 页」——
先断言 `通行、停留与活动之间的边界冲突 · 1 页`，点采纳后断言 `· 2 页`。

图：`03_大纲确认.png`（初始 1 页，建议卡仍在）。

## 验收输出

```
$ flutter analyze
Analyzing t_0ded2104...
No issues found! (ran in 6.9s)

$ flutter test
00:09 +20: All tests passed!

$ flutter build web --release
Compiling lib\main.dart for the Web...   142.4s
√ Built build\web
```

## 文件清单

| 文件 | 内容 | 对应 |
|---|---|---|
| 01_工作台.png | 1440×900 | 基线不变 |
| 02_材料输入.png | 1440×900 | #4 |
| 03_大纲确认.png | 1440×900 | #7 |
| 04_模块拆分.png | 1440×900 | 基线不变 |
| 05_模块工作区.png | 1440×900 | #2 |
| 06_交付检查.png | 1440×900 | #1 / #1b / #5 |
| 06b_交付检查_口径小字.png | 06 页左卡 x2 裁剪 | #1 / #1b |
| 07_窄屏_工作台.png | 500×900 | 基线不变 |
| 08_窄屏_模块工作区.png | 500×900 | #2 / #6 |
| 09_hover_导航项.png | 1440×900 | 悬停态（帮助项） |
| 09b_hover_主CTA.png | 1440×900 | 悬停态（新建一个项目） |
| 10_前后对比弹层.png | 1440×900 | #3 |
