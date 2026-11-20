# 审图请求 · docs/screenshots_v9（r6 批次）

**对应哪次改动**：分支 `wt/t_37d23f97`（worktree `.worktrees/t_37d23f97`，基线 main `f2cda22` = r4 提交）。
本卡做三件事：①「按住看修改前」P0；② 主题切换掉帧（先量再修）；③ 应用图标。
另外收掉 14:20 / 14:40 两轮审图反馈里的 P1 + 3 条小项，并登记 5 条不修的已知项。

**本批新增 / 改名的文件（一条一行，全部登记）**

| 文件 | 状态 | 证明什么 |
|---|---|---|
| `press_01_hover.png` | 新增（原 `01_hover.png` 改名） | 鼠标悬停在「按住看修改前」上 1.2s：画布仍是 v2，无「正在看修改前」胶囊 |
| `press_02_holding.png` | 新增（原 `02_holding.png` 改名） | 按住不放：画布切 v1 + 顶部胶囊 + 工具条徽章 v1 + 按钮高亮 |
| `press_04_compare_modal.png` | 新增（原 `04_compare_modal.png` 改名） | 「前后对比」弹层：双栏并排、列头版本号紧跟标签，与按住态明显不同 |
| `press_05_v1_title_2x.png` | 新增 | v1 纸卡标题 2×：两行均衡断句，末行不是孤字（14:20 P1 的验收图） |
| `press_diff.txt` | 新增 | 上面几张的数字：差异像素、胶囊/卡间隙、复位 md5、工作台左边界、深色底纹差 |
| `exe_icon.png` | 新增 | 从 release exe 里提取的内嵌图标（32×32），主体 25×22 = 占高 69% |
| `exe_icon_8x.png` | 新增 | 上一张 8× 最近邻放大：加粗 t0、纯品牌红、无速度线、无浅粉 |
| `exe_icon_sizes_4x.png` | 新增 | 从 exe 按 48/64/128/256 四档取出的内嵌图标并排 —— 大尺寸也是新标（改名，原先叫 alt_tab_icon.png，它不是 Alt-Tab 截图） |
| `exe_icon_check.txt` | 新增 | 上面这张的原始量数：七档逐帧主体 bbox 与占高 |
| `docs/icon_check.txt` | 新增 | 生成器的自检输出（ICO 七帧 + web 六张，逐帧占高与留白） |
| `01_workbench_light.png` | 复拍 | 虚线入口左边界与项目卡对齐（浅色实测都是 x=96） |
| `01_workbench_dark.png` | 复拍 | 深色底纹可见（底 `#2E2536` / 网格 `#32293B`，差 5/255） |
| `docs/perf_r6/before_{A,B,C,D}_1..2.log` | 新增（8 个） | 修复前 debug 构建的帧耗时原始日志（maintainState=true） |
| `docs/perf_r6/after_{A,B,C,D,soak}_1..3.log` | 新增（18 个） | 修复后 debug 构建的原始日志 |
| `docs/perf_r6/release_{A,B,C,D,soak}_1..3.log` | 新增（15 个） | 修复后 release 构建复核；`release_soak_*` 里大量 frames=0（窗口被遮挡时引擎不出帧），**不作依据** |

**改名对应（旧 → 新）**

```
01_hover.png          → press_01_hover.png
02_holding.png        → press_02_holding.png
04_compare_modal.png  → press_04_compare_modal.png
03_released.png       → 删除
```

`03_released.png` 删掉的理由：这个按钮没有 hover 视觉态，「松开」与「悬浮」本来就该逐像素相同
（实测 md5 都是 `0efd86eade93`），拿它当「释放态」的证据不成立。释放的证据改成数字，写在
`press_diff.txt`：**松开后 md5 回到 press_01 那一张，差异像素 0（画布确实回到 v2）**。

**服务自证**：截的是本 worktree 的 release 包（8123 端口，不用 r4 的 8110 / v8 的 8099），
`tool/shoot_r6.py` 每次出图前自检磁盘与 HTTP 的 `main.dart.js` md5 一致才落盘。

---

## 1. P0「按住看修改前」：根因 / 改了什么 / 数字

**根因**（r5 版本 `workspace_page.dart:1618` 起）：`MouseRegion.onEnter/onExit` 把 hover 当按住；
`_holding` 只被赋值、画布从不读它，所以按住时下方没有任何变化，与「前后对比」读起来一样。

**改了什么**

| 改动 | 位置 |
|---|---|
| 按钮改 `Listener(onPointerDown/onPointerUp/onPointerCancel)`，`MouseRegion` 只留 cursor | `workspace_page.dart:1707-1720` |
| 画布按 `_showingBefore` / `_canvasVersion2` 二选一取 v1 / v2 | `workspace_page.dart:75-78` |
| 幻灯片换版本用 `AnimatedSwitcher` 150ms 淡入淡出（`StackFit.expand` 保持 720×405 排版） | `workspace_page.dart:651-676` |
| 按住时只多一条 16px 细胶囊「正在看修改前」，不弹覆盖层 | `workspace_page.dart:392-400 / 1755` |
| 工具条徽章跟着画布走（按住显示 v1） | `workspace_page.dart:419` |
| 新增 `test/hold_compare_test.dart`：悬浮 3s / 按住 / 拖出松手 / 右键 / 无 v2 模块 | `test/hold_compare_test.dart` |

**数字证据**（`press_diff.txt`，脚本判据已按 14:40 反馈修正）

```
悬浮 1.2s：无「正在看修改前」胶囊，画布仍是 v2
按住：胶囊出现；胶囊 175..188，封面卡顶 202，间隙 13px（要求 ≥8）
按住 vs 悬浮：差异像素 36007（bbox 411,129..1043,831 —— 覆盖整个画布）
松开后 md5 = press_01 md5 = 0efd86eade93，差异像素 0（复位）
胶囊中心 670.5 = 画布中心 670.5
```

已知项：按住态是「原位替换 + 一条提示」，与「前后对比」弹层靠「有没有覆盖层」区分，两者不共用任何视觉。

---

## 2. P1 主题切换越用越卡：先量再修

**怎么量的**：`lib/perf/frame_stats.dart` 注册 `SchedulerBinding.addTimingsCallback`，拿引擎上报的真实
`FrameTiming`（build / raster 分开）；`lib/main.dart` 加 `--perf=A|B|C|D|E|soak` 场景驱动，
每次切换统计这一轮动画窗口内的帧，并同时记 Element 数（≈widget 数）与 RSS；
`tool/perf_r6.py` 每组跑 2~3 次取中位数（一个窗口里只有 1~40 帧，单次 p95 会被一帧抖动带跑）。

**根因**：`PageRoute` 默认 `maintainState: true`，逛过的每个页面都留在树里。逛完五步后
Element 1323 → **4660**（3.5 倍），主题动画 25 帧把它们全部重建，build p50 45 → **251ms**，
420ms 里只出 1 帧（≈2fps）。操作次数本身不涨（soak 20 次切换 Element 恒定 1323）——
涨的是「逛过的页面数」，这就是「越用越卡」。

**改了什么**：`main.dart:225-231` 给 `_fadeUpRoute` 设 `maintainState: false`。五步是线性流程、
数据都在 `T0Store` 单例里，回上一页重建即可。

**修复前后（debug 构建，同一把尺子，中位数）**

| 组 | 场景 | frames/420ms | build p50 | build p95 | raster p95 | Element |
|---|---|---|---|---|---|---|
| A | 冷启动后第一次切换 | 1 → 1 | 157.5 → 176.7 | 157.5 → 176.7 | 8.6 → 9.0 | 1323 → 1291 |
| B | 连续切换 10 次之后 | 7 → 8 | 48.0 → 44.8 | 54.3 → 49.3 | 21.4 → 12.8 | 1323 → 1291 |
| C | 工作区 20 次操作之后 | 8 → 7 | 47.2 → 49.9 | 61.4 → 57.6 | 22.8 → 11.6 | 1345 → 1313 |
| D | **逛完 5 个页面之后** | **1 → 13** | **251.4 → 18.3** | **251.4 → 42.3** | 6.8 → 4.3 | **4660 → 922** |
| soak | 连切 20 次 | 6 → 17 | 41.2 → 16.1 | 50.5 → 22.3 | 16.1 → 5.2 | 1323 → 1291 |

**release 复核（最终包）**：A `build p95 10.0 / raster p95 10.8`、B `6.6 / 6.0`、C `7.2 / 6.6`、
D `4.9 / 20.0`（D 的 raster p95 被一帧抖动带起，p50 5.5）。

**怎么读这三组**：A 组是冷启动首帧（含 JIT / 首布局），p95 天然偏高，不代表「越用越卡」；
真正的增长项是 D 组（逛过的页面数），修复后 D 的 Element 从 4660 掉到 922、build p50 从 251ms
掉到 18ms。A/B/C 三组的 raster p50 为 9.0 / 9.3 / 8.2（差 13%），p95 因 A 组只有 1 帧样本，
差值不可比 —— 这一点如实写在这里，不用它当验收依据。

`release_soak_*` 里大量 `frames=0`：窗口被别的窗口压住时引擎不出帧，这组数字不作依据；
连续切换的趋势用 debug 的 `after_soak_*`（前 15 次 raster p95 5.3 / 后 15 次 4.9，无增长）。

---

## 3. P1 应用图标

**① Web 缓存穿透**（`web/index.html` / `web/manifest.json` / `tool/make_icons.py`）

```
web/icons/Icon-192-v2.png、Icon-512-v2.png、Icon-maskable-192-v2.png、Icon-maskable-512-v2.png
web/favicon-v2.png；index.html 引用 favicon-v2.png?v=2、apple-touch-icon 也带 ?v=2
manifest.json 四个 src 同步改成 -v2 名字；make_icons.py 加 ICON_SUFFIX="-v2"，以后重新生成不会退回旧名
```

浏览器与 service worker 会按 URL 缓存旧 favicon，**部署后仍需硬刷一次**（Ctrl+Shift+R）。

**② Windows + web 全套重出**（`tool/make_t0_icons.py`，审图 15:00）

上一版只换了 ICO 的 16/24/32，48 以上和 web 仍是旧母版（占高 28~29% + 速度线），同一个应用
出现两套标。现在改成「一张 1024px 母版 → 全套尺寸」，逐帧把主体高度校到 65~70%、
留白左右对称（16px 垂直方向只能差 1px，否则比例会掉到 62% 或 75%）：

| 帧 | 主体（像素） | 占高 | 留白 左/右 |
|---|---|---|---|
| ICO 16 | 12 × 11 | 69% | 2 / 2 |
| ICO 24 | 18 × 16 | 67% | 3 / 3 |
| ICO 32 | 26 × 22 | 69% | 3 / 3 |
| ICO 48 | 36 × 32 | 67% | 6 / 6 |
| ICO 64 | 50 × 44 | 69% | 7 / 7 |
| ICO 128 | 100 × 88 | 69% | 14 / 14 |
| ICO 256 | 196 × 174 | 68% | 30 / 30 |
| web Icon-192 / 512 | 148×130 / 394×348 | 68% | 22 / 22、59 / 59 |
| web maskable-192 / 512 | 138×122 / 366×324 | 64% / 63% | 27 / 27、73 / 73（红像素最大半径 39.9% / 39.7%，压进 maskable 安全区 40% 以内） |
| web favicon 64 / 32 | 50×44 / 26×22 | 69% | 7 / 7、3 / 3 |

生成后自检把逐帧数字写进 `docs/icon_check.txt`；再从 **release exe** 用 `PrivateExtractIcons`
按七档取回来复量（`tool/extract_exe_icon.py` → `exe_icon_check.txt`），七档全部与生成值一致，
说明 exe 里嵌的确实是新全套：`exe_icon_sizes_4x.png` 是 48/64/128/256 四档并排（Alt-Tab、资源管理器
大图标就是这个尺寸），`exe_icon.png` / `exe_icon_8x.png` 是 32 档。

web 侧同步改名：`Icon-192-v2.png`、`Icon-512-v2.png`、`Icon-maskable-192/512-v2.png`、
`favicon-v2.png`(64)、`favicon-32-v2.png`(32)；`index.html` 两个 `<link rel="icon">` 带 `?v=2`，
`manifest.json` 四个 src 同步。浏览器与 service worker 按 URL 缓存旧图，**部署后仍需硬刷一次**。

用户侧清系统图标缓存（本卡不改缓存本身）：

```
ie4uinit.exe -show        # 或删掉 %LocalAppData%\IconCache.db 后重启资源管理器
```

---

## 4. 审图 14:20 / 14:40 的收口

| 条目 | 状态 | 实测 |
|---|---|---|
| P1 v1 纸卡标题折三行、末行只剩「量。」 | 已修 | `_slideContent` 不再 `replaceAll('\n','')`，保留作者断句 → 两行（`press_05_v1_title_2x.png`） |
| P2-② 「从一份材料开始」整组偏左 | 已修 | 虚线描边原本画在 0..size 上，比卡边框左 1~2px；`paper_background.dart:117` 缩进 0.5px → 浅色实测虚线 x=96 = 项目卡 x=96（审图给的 22px 用当前构建量不到，如实记在这里） |
| P2-⑤ 胶囊压卡上边框 | 已修 | 胶囊改 16px 细胶囊 + `top: 0`：胶囊 175..188、卡顶 202，间隙 13px（≥8） |
| 图标 16/24/32 单独出 | 已修 | 见第 3 节 |
| 15:00 P1 图标只换了一半（48+ / web 仍旧标） | 已修 | 全套 7 档 + web 6 张都从 1024 母版重出，exe 内七档复量一致（`exe_icon_check.txt`、`exe_icon_sizes_4x.png`） |
| 15:20-1 maskable-512 红像素半径 41.3% 超安全区 | 已修 | maskable 版单独按「半径 ≤ 40%」重排：512 → 主体 366×324、半径 **39.7%**（192 → 39.9%），代价是占高落到 63~64%（这档以安全区为准） |
| 15:20-2 ico 16 纵向留白 2/3 | 已修 | 16px 取 12px 高、上下 2/2、左右 1/1；代价是占高 75%（11px 必然是 2/3，二者不可兼得，按「上下同值」优先） |
| 15:20-3 `alt_tab_icon.png` 名字与内容不符 | 已修 | 改名 `exe_icon_sizes_4x.png`，README / 本文件同步；不冒充 Alt-Tab 截图 |
| 15:00 P2-3 弹层两个缩略图只占 34~45% 高 | 说明（二选一） | 这两个框是**整页预览**（按宽度贴顶、保留纸页下方留白），不是裁切缩略图；05 页的卡片是 1:1 版心，两处取景本来就不同。若审图要「填满」，应改成 cover 裁切（会切掉纸页底部），留到 r7 定 |
| 深色点阵底纹看不见 | 已修 | `palette.dart:358` `0x1A43384F → 0x6C43384F`：底 `#2E2536` / 网格 `#32293B`，差 5/255（4~6 区间内） |
| press_04 列头「版本 1 / 修改后」贴太近 | 已修 | `_CompareBox` 版本号紧跟标签（去掉 Spacer，改 8px 间距），见 `press_04_compare_modal.png` |
| `press_diff.txt` 判据错误两行 | 已修 | 深色那行改为只量浅色（深色 line/lineStrong 是另一组色值）；胶囊定位从「非底色」改成按 `accentSoft` 取行 |

**本轮明确不做**

- 05 纸张卡末行被切、环旁「已确认 3/5」与环内重复 → 归 r5（t_25e68217，默认缩放 0.71），合并后一起验。
- 05 页脚压字（审图 P2-①）→ 同上，不动。

## 5. 已知项（本批不修，登记在此）

1. `11_workbench_ring_2x.png` 图幅 160×82，环被裁到画外，证明不了「环 + 新口径」。
2. `07_intake_danger_light_2x.png` 与 `07_..._dark_2x.png` 取景/倍率不一致（278×112 vs 196×64）。
3. 同屏并存「04」与「t0 / 04」两种页码写法（待确认是否两套模板）。
4. `release_soak_*` 帧耗时日志在窗口被遮挡时整组 `frames=0`，暂不能作为连续切换的证据。
5. v7 过渡中段前景塌成纯黑 / 纯白（对比度兜底的副作用）—— 与本批无关，未动动画曲线。

## 6. 验收命令（真跑）

```
$ flutter analyze
No issues found! (ran in 7.4s)

$ flutter test
00:16 +64: All tests passed!

$ flutter build web --release
✓ Built build/web

$ flutter build windows --release
✓ Built build/windows/x64/runner/Release/lab5_crossplatformvisualdesignpractice.exe
```
