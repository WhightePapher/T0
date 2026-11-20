# REVIEW REQUEST · Lab5 r8（分支 `wt/t_b538b3f0`）

- 分支：**`wt/t_b538b3f0`**（worktree `D:/Projects/Lab5_CrossPlatformVisualDesignPractice/.worktrees/t_b538b3f0`，基线 `96a2f05`，本批提交 `2ab7ef8`）
- 范围：只收 2 件事（#1 幻灯片页眉页码写法统一 / #2 05 纸卡首条分隔线间距）+ 上一轮被抓的 `press_01_light.png` 证据要求；不加功能、不动布局骨架、不动两条已登记的已知项
- 证据：`docs/screenshots_v12/`（7 张图 + `BUILD_HASH` + `measurements.txt` + `positions.json` + `README.md`）；逐条改动、行号、改前改后实测在 `README.md`
- 出图口径：1440×900 / DPR 1；`build/web/main.dart.js` md5 `967d434fc378e47e0e35838bf0e711b1`（脚本落盘前比对了磁盘与 HTTP，一致才出图）

## 1. 四条验收命令的真实输出

### ① `flutter analyze`

```
$ flutter analyze
Analyzing t_b538b3f0...
No issues found! (ran in 4.6s)
```

### ② `flutter test`

```
$ flutter test
00:19 +66: .../test/topbar_test.dart: 切主题 白天 ↔ 黑夜：这一段的字色 / 底色跟着变，位置不变
00:20 +67: All tests passed!
```

本轮是 1 行级文案 + 1 处盒模型重排，没有新增测试文件；现有 67 条全绿。

### ③ `flutter build web --release`

```
$ flutter build web --release
Compiling lib\main.dart for the Web...                            136.7s
√ Built build\web
$ md5sum build/web/main.dart.js
967d434fc378e47e0e35838bf0e711b1 *build/web/main.dart.js
```

（量尺注释里把「7px」改成实测的「6px」后重建过一次，md5 与改前一字不差 —— 纯注释改动不进产物。）

### ④ `python tool/shoot_v12.py http://127.0.0.1:8130/index.html`（尾部）

```
main.dart.js  disk=967d434fc378 http=967d434fc378 OK
05_workspace_light.png  md5=ef2463be846b  166KB
05_dividers_2x.png  md5=3c5a39394b4e  14KB
header_stage_2x.png  md5=197301719755  0KB
header_cover_2x.png  md5=d69164a74ddf  0KB
modal_compare.png  md5=41f805d348fb  155KB
header_modal_2x.png  md5=3a8ba5eee19b  2KB
press_01_light.png  md5=3da214ddc925  177KB
已整目录替换 → D:\Projects\...\.worktrees\t_b538b3f0\docs\screenshots_v12
```

证据绑定：

```
$ python C:\Users\98343\AppData\Local\hermes\workspace\check_shots.py \
    --project D:/Projects/Lab5_CrossPlatformVisualDesignPractice/.worktrees/t_b538b3f0 \
    --shots docs/screenshots_v12
[ok] 证据已绑定：7 张图，md5=967d434fc378…，无旧图
```

### ⑤ 分支与工作区

```
$ git branch --show-current
wt/t_b538b3f0
$ git status --porcelain | wc -l
0
$ git log --oneline -1
2ab7ef8 fix(r8): 页眉页码统一走 _deckPageLabel（舞台/封面/弹层三处）+ 05 纸卡三条分隔线改行上边框，线到标题 16/7/7→6/6/6
```

## 2. 逐条结论

| # | 结论 | 一句话证据（详细数字见 `README.md`） |
|---|---|---|
| #1 页眉页码写法 | **已修** | 新增 `_deckPageLabel(n) => 't0 / $n'`，舞台纸卡（884）、深绿封面页（734）、弹层缩略图（1225）三处都调它；语义树三处节点同为 `t0 / 04`；封面页墨迹宽 **11px→30px**、弹层缩略图 **6px→16px**（`header_stage_2x.png`、`header_cover_2x.png`、`header_modal_2x.png`） |
| #2 首条分隔线间距 | **已修** | 三条线到各自标题 **16 / 7 / 7 → 6 / 6 / 6**（极差 0，要求 7±1）；线 y=633/678/723（间距 45/45），标题 y=639/684/729（行距 45/45 未变），卡底到页脚线仍 34px（`05_dividers_2x.png`、`05_workspace_light.png`） |
| 证据要求 press_01 | **已重拍** | 点「撤销」后 0.35s 取样带深色像素 **7923**（正对照）→ 等满 3.2s 后成图 **0**；同一张图里悬浮胶囊 x=821..931（宽 110px）证明 hover 生效（`press_01_light.png`） |

**#1 比任务书多做一处**：任务书写「舞台 vs 弹层缩略图」两处，但「同一张幻灯片右上角」一共三处同款页眉行，深绿封面页那处（734 行）原来也是裸 `04`，因此一并收进 `_deckPageLabel`。理由与取舍写在 `README.md` §1：只改两处的话，封面与纸卡在同一屏里仍是两种写法（`press_01_light.png` 顶部两张卡直接并列）。仍是 1 行级改动，未改骨架。

## 3. 需要 owner 决定 / 已知项（本轮一个像素都没动）

1. 对比弹层缩略图正文约 9–10px（71% 下）——已登记，未动。
2. 纸卡页脚那行字面高 4px（71% 下）——已登记，未动。
3. 两条都可留到下一轮；如果决定动，建议单独开卡量版心，不要和这轮的 1 行级改动混在一起。

## 4. 复核入口

```bash
cd D:/Projects/Lab5_CrossPlatformVisualDesignPractice/.worktrees/t_b538b3f0
git log --oneline -3            # 2ab7ef8 / 96a2f05
flutter analyze && flutter test
cat docs/screenshots_v12/measurements.txt
```
