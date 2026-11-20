# Windows 图标 + 深色小字 + 06 两处遗留（screenshots_v5）

基线：`main @ 9ff1b6f`；本卡分支 `wt/t_4d8e0f52`。
产物两条线：**web**（`flutter build web --release`，1440×900 / DPR 1，无头 Chrome + CDP）
和 **Windows exe**（`build/windows/.../Release/*.exe`，客户区 1440×900 逻辑 → 本机 150% → 窗口 2182×1406 物理，
`PrintWindow(PW_RENDERFULLCONTENT)` 抓窗口位图）。

> 目录重名说明：`9ff1b6f` 里把之前那批「拍到 8099 上主仓旧构建」的 v5 删掉了；本目录是重拍的一批。

## 0. 自证

**web 服务**（图确实来自本 worktree 的构建）：

```bash
$ md5sum build/web/main.dart.js
0a9846a6a101f8da90e803fd69bec1b8 *build/web/main.dart.js
$ curl -s http://127.0.0.1:8141/main.dart.js | md5sum
0a9846a6a101f8da90e803fd69bec1b8 *-
```

**exe 浅色 / 深色必须不同**（脚本自己比 md5，相同就报错退出）：

| 文件 | 抓图时间 | md5 | 顶栏均值 top_mean |
|---|---|---|---|
| `exe_light.png` | 18:31:41 | `bfaa9993b662b52dc88d597fd38501d7` | **245**（≈#FFFDF8） |
| `exe_dark.png` | 18:31:52 | `7e4d2fe00cd59d0a1a77793233d9c9f8` | **63**（≈#3A2F44） |

两张整窗图都已**裁到内容区**（去掉 PrintWindow 抓进来的 11px 纯黑边；裁后 2160×1394，四边纯黑像素 0）。
`2182×1406` 是裁前的原始尺寸，只为说明窗口在 150% 缩放下的物理大小。

深色那张是**起第二次进程**（`T0_START_THEME=dark`，见 `lib/theme/start_theme_io.dart`），不依赖点击：
这台机器顶栏右上角常被资源管理器 / 终端压住，合成鼠标点不到 36px 圆钮。交互另用 `--click-check` 验证。

## 1. 图目录（状态 / 页面 / 尺寸 / md5）

| 文件 | 主题 | 页面 / 内容 | 来源 | 尺寸 | md5 |
|---|---|---|---|---|---|
| `workbench_light.png` | 浅色 | 工作台 | web（新） | 1440×900 | `1ab1cc1763da33c09861c027c5215c15` |
| `workbench_dark.png` | 深色 | 工作台 | web（新） | 1440×900 | `d56dd08741c57aadf2b8ae9e9fc268a8` |
| `workspace_light.png` | 浅色 | 模块工作区（页脚不压字） | web（新） | 1440×900 | `1271545af9f904c6296a4d0c0b2f68a8` |
| `workspace_light_scrolled.png` | 浅色 | 模块工作区**滚到底**（末行完整可见） | web（新） | 1440×900 | `27f48e74cb3c09b5accbd65a04bc2736` |
| `workspace_dark.png` | 深色 | 模块工作区 | web（新） | 1440×900 | `f8cce798f66ef8c6549cccd084a9f990` |
| `delivery_before_light.png` | 浅色 | 交付检查 **改前**（`screenshots_v4`，main @205da09） | web（沿用基线） | 1440×900 | `f5900e080db51fd500d2ab676005bed2` |
| `delivery_after_light.png` | 浅色 | 交付检查 改后 | web（新） | 1440×900 | `e3b98f4f3095d400f27bac92658ade1f` |
| `delivery_after_dark.png` | 深色 | 交付检查 改后 | web（新） | 1440×900 | `e91d52e7d4202ffe63b5af3ac0d84d7c` |
| `exe_light.png` | 浅色 | 工作台（真实 exe，已裁到内容区） | exe（新） | 2160×1394 | `bfaa9993b662b52dc88d597fd38501d7` |
| `exe_dark.png` | 深色 | 工作台（真实 exe，含**深色原生标题栏**，已裁到内容区） | exe（新） | 2160×1394 | `7e4d2fe00cd59d0a1a77793233d9c9f8` |
| `exe_theme_light.png` | 浅色 | 主题按钮 4×（太阳） | exe（新） | 240×240 | `59a2c218b2db359f7df0f13a3722167c` |
| `exe_theme_dark.png` | 深色 | 主题按钮 4×（月亮） | exe（新） | 240×240 | `04d2091dd6ab05aaa9d172def03b4207` |
| `exe_primary_light.png` | 浅色 | 主按钮 3×（`(1171,314)-(1343,369)`） | exe（新） | 774×246 | `cd4d641f15583c4253085353ad7a509e` |
| `exe_primary_dark.png` | 深色 | 主按钮 3× | exe（新） | 774×246 | `d5bbf9e138ae97ab4c48e9f423aa5846` |
| `exe_titlebar_zoom.png` | 浅色 | 标题栏 3×（应用图标 + `t0 办公`） | exe（新） | 1380×135 | `35de7aa8696e818659ace83bcc27e140` |

过渡帧在 `docs/screenshots_v7/`：`07_t105` / `08_t120` / `09_t210` / `10_t315`。

## 2. P1：Windows exe 的太阳 / 月亮（根因不是 tree-shaking）

| 事实 | 数据 |
|---|---|
| 主人给的 `dist` 里图标字体 | `MaterialIcons-Regular.otf` **3104 B / 26 码位**，缺 `0xf162`（light_mode_outlined）、`0xef9f`（dark_mode_outlined） |
| 同一份代码全新建（干净 `build/`） | **3376 B / 27 码位**，两个码位都在 |
| web 构建的同一字体 | 9712 B / 81 码位，两个码位都在 |
| 旧 dist 里该字体 mtime | **2026-11-10 17:43**，exe 是 **11-12 15:29** → 增量构建沿用了旧子集 |

图标字体子集按 **Assets 清单**判断是否重生成，Dart 里新加 `Icons.xxx` 不会让它失效；`build/` 没清过就把旧子集打进产物。

**修法两层**：① 主题按钮改 CustomPaint 自绘（`_ThemeGlyph`，不读 MaterialIcons）；
② `tool/verify_icon_font.py`（逐个比对产物 `cmap` + 字体 mtime 比源码旧即失败）+ `tool/package_windows.py`（校验失败自动 `flutter clean` 重建一次）。

## 3. P2：深色 mono / 小字对比度

| 区域 | 改前（`screenshots_v4` 实测） | 改后（本批实测） |
|---|---|---|
| 工作台 `WORKBENCH · 04`（eyebrow, on bg） | `#9C8FA9` / `#2E2536` = **4.82** | `#BEB4C9` / `#2E2536` = **7.36**（eyebrow 走 stepMuted） |
| 工作台 三步卡 01/02/03（mono, on surface） | `#9B8EA9` / `#3A2F44` = **4.09** | `#B7ACC3` / `#3A2F44` = **5.81** |
| 工作台 产品流程 标签（label, on surface） | `#9C8FA9` / `#3A2F44` = **4.14** | `#B8ADC4` / `#3A2F44` = **5.88** |
| 模块工作区 左栏 01~05（mono, on surface） | `#9C8FA9` / `#3A2F44` = **4.14** | `#B8ADC4` / `#3A2F44` = **5.88** |
| 模块工作区 `t0 copilot`（mono, 8px） | ink2 `#68736F` = **4.40** | stepMuted `#606B67` = **4.95** |

深色 `muted` `#9C8FA9` → **`#B8ADC4`**（surface 5.88 / surface2 4.94 / bg 6.84）；浅色底次级文字
（工作台副标题、「最近项目」、交付页右上说明、`t0 copilot`）统一 `stepMuted`（白天 4.95 / 黑夜 7.36）。
量法：`tool/measure_mono_contrast.py`（众数色当底，取与底色亮度差最大的像素当笔画核心，WCAG 相对亮度）。

## 4. 06 交付检查

| 项 | 处理 |
|---|---|
| 左卡留白 | 环下补一行口径说明「交付口径：有内容就计入（已确认 + 待确认）」吃掉空白，其余留白拆到环下 / 按钮上方两段；测试断言按钮贴卡底 ≤30px、说明段→按钮 ≤100px |
| 用词统一 | 状态词只有 **已确认 / 待确认 / 待补充**：`整体完成度`→`整体就绪度`、`全部完成`→`全部已确认`、`全部页面已完成`→`全部页面已确认`、`未完成内容`→`未就绪内容`、右上说明「未确认或待补充」→「待确认」；`结论总结` 行来源 `待补充`→`尚缺材料` |

口径写进 `docs/视觉设计说明.md`：环图 80% = 已就绪 4/5（3 已确认 + 1 待确认），徽章「2 项待处理」= 待确认 1 + 待补充 1。

## 5. 其它（一起收的 P2）

| 项 | 处理 |
|---|---|
| 标题栏是 Flutter 蓝图标 | `tool/make_app_icon.py` 生成 `windows/runner/resources/app_icon.ico`（暖纸底 + 墨色 t0，16–256） |
| 标题「t0办公」/ 页脚「t0 办公」不一致 | 统一 `t0 办公` |
| 深色下原生标题栏仍是浅灰 | `windows/runner/flutter_window.cpp` 加 `ApplyDarkTitleBar`（DWM 20/35/36）+ `t0/theme` channel：启动按 `T0_START_THEME`，运行中随切换同步。`exe_dark.png` 的 y=0–44 现在是 `#2E2536`，和内容区没有硬直边 |
| 模块工作区页脚压住白页末行 | 画布滚动区底部 padding `32` → `pad + 72`；`workspace_light_scrolled.png` 里末行「让座椅、界面和活动区互相形成观看关系。」完整可见 |
| 模块工作区同屏两个实心绿按钮 | 「应用修改」改 `SecondaryButton`，一屏只留「交付检查」一个实心主按钮 |
| 过渡中主按钮闪黑 / 闪白 | `accentFill` / `accentStrongFill` + `onFill`，逐帧证据见 `screenshots_v7` |

## 6. 已知项（不影响合并）

- 01 工作台右卡上下内边距不均（27 / 94）。
- 06 左卡两段留白 99px + 87px（分摊后仍有 2 处，符合「≤100px 且不堆一处」的验收）。
- 05 纸张卡上的「结构压缩版」8px 小标偏小。
- `screenshots_v7` 的过渡帧本轮未重审（CTA 底色已逐帧断言为绿系，见该目录 README）。

## 7. 验收命令（本分支实跑）

```
$ flutter analyze
Analyzing t_4d8e0f52...
No issues found! (ran in 5.6s)

$ flutter test
00:09 +27: All tests passed!

$ flutter build web --release
√ Built build\web

$ flutter build windows --release
√ Built build\windows\x64\runner\Release\lab5_crossplatformvisualdesignpractice.exe
```

采集脚本已加**错误页断言**：落盘前 `document.title` 不含 `lab5` 直接非零退出，且先写 `.tmp.png` 再 `os.replace`，
不会用 404 页面覆盖已有旧图（18:08 那 7 张 19466 B 的 404 就是这么来的）。

复现：

```bash
python tool/make_app_icon.py
python tool/package_windows.py                   # 构建 + 图标字体校验 + 打包 dist
cd build/web && python -m http.server 8141 &
python tool/shoot_screens_v5.py http://127.0.0.1:8141/index.html
T0_SHOTS=screenshots_v7 python tool/shoot_theme_screens.py http://127.0.0.1:8141/index.html
python tool/shoot_windows_exe.py                 # exe 浅 / 深 + 放大图（--click-check 验证点击交互）
python tool/measure_mono_contrast.py
python tool/measure_transition_fill.py
```
