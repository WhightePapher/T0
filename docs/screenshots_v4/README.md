# 主题系统 + 文案压缩 实拍（screenshots_v4）

基线：`main @ 5b4c73e`；本次分支 `wt/t_6a7f7037`。
产物：Flutter web `--release`（`build/web`，本地 `python -m http.server 8099`），
Chrome 视口 **1440×900 / DPR 1**，无头 Chrome（`--headless=new`）+ CDP 截图。

本卡一起改了三件事（同一批文件）：

1. **白天 / 黑夜双主题 + 420ms 渐变过渡**，右上角可切换；
2. **各页冗余文案删减**（判定标准：是否告诉用户下一步做什么）；
3. 审图反馈：**过渡中文字不可读**（P1-1）、**深色画布不再是导出物**（P1-2）已修，
   浅色两处小字对比度（P2-5）已提。

---

## 1. 代码结构

| 文件 | 作用 |
|---|---|
| `lib/theme/palette.dart`（新增） | `T0Palette extends ThemeExtension<T0Palette>`：40 个颜色字段分三组（面 / 前景 / deck），`light` / `dark` 两套常量，`copyWith`，自定义 `lerp`，`static of(context)` + `context.pal` |
| `lib/theme/theme_controller.dart`（新增） | `ThemeController extends ChangeNotifier` + `T0Theme extends InheritedNotifier`；没有新依赖 |
| `lib/theme/app_theme.dart` | `AppTheme.light()` / `dark()`，两套 ThemeData 都挂 `T0Palette` |
| `lib/theme/tokens.dart` | 颜色常量全删，只留字号 / 间距 / 圆角 / 字体链；`T0.h1(m, palette)` 从调色板取字色 |
| `lib/main.dart` | `theme` / `darkTheme` / `themeMode` + `builder` 里的 `AnimatedTheme(420ms, easeInOutCubic)`；`themeAnimationDuration: Duration.zero` 关掉 MaterialApp 自带 200ms，避免两段动画叠加 |
| `lib/widgets/app_shell.dart` | 顶栏右侧 36px 圆形切换按钮（sun ↔ moon，`AnimatedSwitcher` 200ms，hover 提示「切换到黑夜 / 白天」） |
| `lib/widgets/*`、`lib/features/**` | 全部改成 `context.pal.xxx`；`CustomPainter`（网格、环形进度、虚线框）从调色板取色并在 `shouldRepaint` 里比较颜色 |

约束自查（真实输出）：

```
$ grep -rn "T0\.\(paper\|ink\|green\|line\|muted\)" lib/
（空）
$ grep -rn "Color(0x" lib/
只命中 lib/theme/palette.dart（两套主题的定义处），页面与组件 0 处裸十六进制
```

### lerp 的三组字段（P1-1 的修法）

`T0Palette.lerp` 不是「所有字段一起 `Color.lerp`」——那样文字和底色会同时走到中间灰，
互相抵消（上一版 210ms 帧实测主标题 `#898387` on `#90898E` = **1.09:1**）。现在：

| 组 | 字段 | 行为 |
|---|---|---|
| 面 | `bg0 bg surface surface2 canvas line lineSoft lineStrong *_Soft grid scrim shadow shadowSoft` | 420ms 连续插值，曲线 `t^0.65`（前段快、后段收） |
| 前景 | `ink ink2 muted accent accentStrong onAccent lilac ok warn danger` | **中点（210ms）直接切换**，不交叉淡入；过渡途中向同侧 `ink` 收 95%，保证中间灰底上不糊 |
| deck | `deckBg deckPaper deckInk deckInk2 deckLine deckAccent deckAccentSoft deckWarn deckDanger deckDangerSoft deckCover deckCoverInk deckCoverAccent deckShadow` | 两套主题**完全相同**，插值等于原值 |

另外：`AnimatedContainer` 这类组件自带 120–160ms 的颜色过渡会去追一个每帧都在变的目标色，
永远慢半拍（末段实测「底色已经深了、控件还停在中间灰」→ 2.75:1）。
现在 `context.anim(base)` 在主题渐变进行中（`palette.transitioning`）直接返回 `Duration.zero`，
让组件自己的 hover 过渡让路，切完立刻对齐。

---

## 2. 过渡帧（核心验收）

`tool/shoot_theme_screens.py`：无头 Chrome + CDP，点右上角按钮后用 `Page.startScreencast` 连续收帧
（每帧带 CDP 时间戳），按动画时间挑帧。

> 拍摄细节：这台机器无头 CanvasKit 在 1440×900 只有 ~8fps，直接拍只能拿到「一个中间态 + 已落定」。
> 脚本在页面加载前注入一段**只缩放 `requestAnimationFrame` 时间戳**的垫片（0.2×，即 5 倍慢动作），
> 动画本身仍是 420ms / `easeInOutCubic`，**产品代码没有为此改任何一行**。

| 文件 | 实际动画时间 | 页面底色 |
|---|---|---|
| `10_transition_105ms.png` | 107 ms | `#CFCAC6` |
| `07_transition_120ms.png` | 117 ms | `#C9C4C1` |
| `08_transition_210ms.png` | 210 ms | `#7A737A` |
| `09_transition_300ms.png` | 304 ms | `#3C3342` |
| `11_transition_315ms.png` | 317 ms | `#38303F` |

完整采样（32 帧，`transition_timeline.txt`，动画时间 / 页面底色）：

```
 15.8 ms #F3EFE7    107.5 ms #CFCAC6    210.0 ms #7A737A    315 附近 #38303F
 50.0 ms #E8E4DD    127.5 ms #C3BEBC    250 附近  #5C5460    399.1 ms #2E2536 ← 落定
```

### 逐块对比度实测（105 / 210 / 315ms）

直接从三张 PNG 里量：每个文字块取「块内出现最多的像素」当底色、取「与底色亮度差最大的像素」当字色，
按 WCAG 相对亮度算比值。

| 区块 | 105ms | 210ms | 315ms |
|---|---|---|---|
| 主标题「把一次汇报，拆成…」 | 10.14 | 3.58 | 11.06 |
| 副标题「从材料出发…」 | 9.67 | **3.42** | 9.01 |
| 项目卡标题 | 11.22 | 4.19 | 9.39 |
| 项目卡元信息 | 10.70 | 4.00 | 7.65 |
| 右卡 eyebrow | 10.70 | 4.00 | 6.34 |
| 右卡「三步」 | 11.22 | 4.19 | 9.39 |
| 右卡 01/02/03 说明 | 11.22 | 4.19 | 9.39 |
| 主 CTA 文字 | 15.60 | 15.60 | 10.79 |
| 顶栏导航「工作台」 | 11.22 | 4.19 | 9.39 |
| 顶栏项目名 | 11.22 | 4.19 | 9.39 |
| 步骤条文字 | 9.67 | 3.42 | 7.47 |

**最小对比度：105ms = 9.67、210ms = 3.42、315ms = 6.34，全部 ≥3:1，没有任何一行文字消失。**
单元测试 `过渡全程：任一时刻文字/底的对比度都不低于 3:1` 把 t 从 0 扫到 1（201 个点）逐帧断言，
不是只验这三个采样点。

过渡中唯一可见的取舍：强调色（绿）在中点附近被收向 `ink`，短暂去饱和（`08` 里标题后半句接近墨色），
落定后恢复 `#4FB08B`/`#147A62`。这是「中间灰底 + 任意色相 = <3:1」的必然结果，代码注释里写明了原因。

---

## 3. 深色画布用固定 deck 配色（P1-2）

画布是「导出物预览」，不跟着应用外壳变深：

- 中栏画布底 `deckBg #EBE6DB`、内容页 `deckPaper #FFFDF8`、幻灯片文字 `deckInk #17211F`、
  分隔线 `deckLine #D9D4C9`、品牌绿 `deckAccent #147A62`、封面 `deckCover #17211F`——
  这些值在 `T0Palette.light` 与 `T0Palette.dark` 里**完全相同**（`test` 里断言 `lerp` 后仍等于白天值）。
- 结果：`04_dark_模块工作区.png` 里左栏 / 工具栏 / AI 面板 / 页面底色都是深紫灰，中间画布与两页幻灯片
  仍是纸白 + 深绿封面 —— 和 `03_light` 的画布一模一样，预览继续代表导出的 PPT。
- 应用外壳（导航、卡片、按钮、状态胶囊、进度环、弹层）才跟主题走。

---

## 4. 对比度表（黑夜主题，实测）

色值取自 `lib/theme/palette.dart` 的 `dark`；比值 = `(L亮+0.05)/(L暗+0.05)`。

| 文字色 | 背景色 | 实测 | 达标 | 用途 |
|---|---|---|---|---|
| ink `#F3EEF7` | bg `#2E2536` | 12.82:1 | ✅ ≥7 | 页面标题 / 正文 |
| ink `#F3EEF7` | surface `#3A2F44` | 11.01:1 | ✅ ≥7 | 卡片标题 / 正文 |
| ink `#F3EEF7` | canvas `#1F1926` | 15.00:1 | ✅ ≥7 | 画布标题 |
| ink2 `#C6BACE` | surface `#3A2F44` | 6.78:1 | ✅ ≥4.5 | 卡片说明 / 元信息 |
| ink2 `#C6BACE` | surface2 `#463A52` | 5.69:1 | ✅ ≥4.5 | 弹层说明 |
| ink2 `#C6BACE` | bg `#2E2536` | 7.89:1 | ✅ ≥4.5 | 页面说明 |
| muted `#9C8FA9` | bg `#2E2536` | 4.82:1 | ✅ ≥4.5 | 步骤条 / 弱说明 |
| accent `#4FB08B` | surface `#3A2F44` | 4.74:1 | ✅ ≥4.5 | 绿色强调字 |
| accent `#4FB08B` | bg `#2E2536` | 5.52:1 | ✅ ≥4.5 | 绿色强调字 |
| accentStrong `#63BF9C` | accentSoft `#24382F` | 5.63:1 | ✅ ≥4.5 | AI 范围胶囊 |
| ok `#6FBF9B` | accentSoft `#24382F` | 5.71:1 | ✅ ≥4.5 | 已确认胶囊 |
| warn `#E0A268` | warnSoft `#33251C` | 6.71:1 | ✅ ≥4.5 | 待确认胶囊 |
| danger `#E07A72` | dangerSoft `#331F24` | 5.28:1 | ✅ ≥4.5 | 待补充胶囊 |
| onAccent `#1B1620` | accent `#4FB08B` | 6.70:1 | ✅ ≥4.5 | 主按钮文字 |
| onAccent `#1B1620` | accentStrong `#63BF9C` | 8.00:1 | ✅ ≥4.5 | 主按钮 hover |
| lilac `#B79BD6` | lilacSoft `#3C2F49` | 5.12:1 | ✅ ≥4.5 | 选中 / 头像 / 点缀 |
| deckCoverInk `#F6F2E9` | deckCover `#17211F` | 14.76:1 | ✅ ≥7 | 封面页正文（固定 deck） |
| deckCoverAccent `#DFF0E9` | deckCover `#17211F` | 13.96:1 | ✅ ≥4.5 | 封面页强调（固定 deck） |

### 浅色小字（P2-5）

| 位置 | 改前 | 改后 |
|---|---|---|
| 「待确认」胶囊 11px | `#D56C3D` on `#FAE6DA` = 2.88 | `warn` 加深一档到 `#A8461A` = **4.89** |
| 「已就绪 4/5（含 1 待确认）」10px | `#68736F` 细笔画实测 2.41 | 提到 11px + `ink2Strong`（`#3F4A47`）= **9.03** |

两个 token 只改了字色/字号，没动版式。浅色里还剩两处历史值低于 4.5：
「待补充」胶囊 4.14、「已确认」胶囊 4.46 —— 属于 v3 既定色值，按「不扩大 diff」的要求本卡不改。

---

## 5. 白天零改动证据

新图与 `screenshots_v3` 同屏截图做颜色直方图（出现面积最大的 8 种颜色）：

| 对比 | 交集 | v3 独有 | v4 独有 |
|---|---|---|---|
| 01 工作台 | `#F6F2E9` `#FFFDF8` `#F0EDE5` `#147A62` `#17211F` `#D9D4C9` `#3B4643` `#D7D2C7` | 无 | 无 |
| 05 模块工作区 / 03_light | `#FFFDF8` `#17211F` `#F6F2E9` `#EBE6DB` `#147A62` `#D9D4C9` `#EAE5DA` `#E9E4D9` | 无 | 无 |
| 06 交付检查 / 05_light | `#FFFDF8` `#F6F2E9` `#F0EDE5` `#147A62` `#D9D4C9` `#DFF0E9` `#17211F` `#F8E5E2` | 无 | 无 |

像素数差异只来自删掉的文案、新增的切换按钮、以及 `warn` 那一档加深；
没有任何一个颜色是新出现的。

---

## 6. 文案删减（逐条）

| 页面 | 原文 | 处理 |
|---|---|---|
| 01 工作台 | 副标题 46 字「从已有材料出发…其他内容保持不动。」 | →「从材料出发，先定结构，再逐模块完善。」 |
| 01 工作台 | 右卡标题「今天只演示一条完整链路」 | →「三步」 |
| 01 工作台 | 整块「演示提示」+ 两行说明 | 整块删除（连同分隔线、间距一起收拢） |
| 02 材料输入 | 右上说明「系统只整理已有内容…标记“待补充”。」 | →「材料不足处标『待补充』，不会替你编。」 |
| 02 材料输入 | 整卡「为什么不是一键生成整套？」+ 3 行解释 | 整卡删除 |
| 02 材料输入 | 按钮「演示解析失败」（两处） | → 纯文字链接「模拟解析失败」 |
| 03 大纲确认 | note 45 字 | →「确认前可增删章节；确认后拆成模块。」 |
| 04 模块拆分 | note 41 字 | →「按表达任务分模块，不按页数切。」 |
| 04 模块拆分 | 「拖拽左侧手柄可以调整顺序」 | →「拖拽排序」 |
| 05 模块工作区 | 「默认只修改当前模块。跨模块改动需要你明确确认。」 | 删除（已有「仅当前模块」「作用范围：当前模块」两处） |
| 06 交付检查 | 「待补充模块会生成占位页…来源与状态。」 | 删除 |
| 06 交付检查 | 左卡 4 行长句 | → 一句「“结论总结”仍在等材料；4 个模块已有内容（含 1 个待确认）。” |

删完后都把腾出的空隙收掉：工作台右卡靠 `IntrinsicHeight` 与左栏对齐；材料输入右栏只剩一张卡；
工作区 AI 面板标题下不再留空行。

---

## 7. 验收命令（真实输出）

```
$ flutter analyze
Analyzing t_6a7f7037...
No issues found! (ran in 6.4s)

$ flutter test
00:10 +24: All tests passed!        # 24 个用例

$ flutter build web --release
Compiling lib\main.dart for the Web...  120.2s
√ Built build\web

$ flutter build windows --release
Building Windows application...         191.4s
√ Built build\windows\x64\runner\Release\lab5_crossplatformvisualdesignpractice.exe
```

新增测试（`test/widget_test.dart`）：

- `右上角切换主题：420ms 内是中间态，落定后是黑夜调色板` —— 点按钮后 `pump(210ms)` 断言底色既不是白天也不是黑夜，再 `pump(300ms)` 断言等于 `T0Palette.dark`。
- `黑夜调色板对比度：正文 ≥ 4.5、标题 ≥ 7` —— 第 4 节表格的 19 组配对逐条断言。
- `过渡全程：任一时刻文字/底的对比度都不低于 3:1` —— t 从 0 到 1 扫 201 帧，17 组配对逐帧断言。
- `T0Palette.lerp 逐字段给出中间态` —— 面参与插值、deck 保持不动。

---

## 8. 截图清单

| 文件 | 内容 |
|---|---|
| `01_light_工作台.png` / `02_dark_工作台.png` | 工作台（右上角切换按钮；白天太阳、黑夜月亮） |
| `03_light_模块工作区.png` / `04_dark_模块工作区.png` | 工作区三栏；深色外壳 + 固定浅色画布 |
| `05_light_交付检查.png` / `06_dark_交付检查.png` | 交付检查（进度环、三种状态胶囊、分组清单） |
| `07_transition_120ms.png` / `08_transition_210ms.png` / `09_transition_300ms.png` | 任务书要求的过渡帧 |
| `10_transition_105ms.png` / `11_transition_315ms.png` | 审图要求的 105 / 315ms 采样帧 |
| `transition_timeline.txt` | 整段过渡的 32 帧采样表 |

---

## 9. 复现

```bash
flutter build web --release
cd build/web && python -m http.server 8099 --bind 127.0.0.1     # 另开一个终端
cd ../.. && python tool/shoot_theme_screens.py                  # 出 11 张图 + transition_timeline.txt
```

脚本用 `websockets`；找不到 Chrome 时回退 Edge。
