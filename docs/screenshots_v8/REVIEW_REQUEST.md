# 审图请求（批次：screenshots_v8 · r3 顶栏）

## 1. 这批是什么

r3 顶栏改动 + 上一轮审图意见的收口，涉及：

- `lib/widgets/app_shell.dart`：删掉整组圆形头像（肖 / 王 / 何 / +1，`_AvatarGroup` / `_Avatar` 已移除）；
  右侧改为 项目名 / 已自动保存 / 主题 / 加号，间距统一 16px；项目名 + 已保存在 `kProjectRoutes`
  （`/intake` `/outline` `/modules` `/workspace` `/delivery`）之外一律隐藏；两枚圆钮统一 36×36。
- `lib/theme/tokens.dart`：新增 `T0.iconButtonSize = 36`，主题 / 加号 / 菜单共用，不再各写 34 / 36。
- `lib/features/intake/intake_page.dart`：导航高亮 `activeNav` 由 `/workbench` 改为 `/workspace`（材料输入属于项目第 1 步，
  高亮「当前项目」）；「模拟解析失败」由无边框 `GhostButton` 改为 `SecondaryButton(dense: true, tone: danger)`。

没有动主题系统（palette / lerp / 动画）、没有动背景和画布、没有改其他页面文案。
审图待确认①（02 右栏「为什么不是一键生成整套？」）按你的答复**没有加回来**。

## 2. 上一轮审图两条的收口

| 意见 | 处理 | 证据 |
| --- | --- | --- |
| P1 材料输入页导航高亮「工作台」，右侧却显示项目名 | `activeNav: '/workspace'`，保留项目名 | `02_intake_topbar_strip_2x.png` 里「当前项目」是白底深字；`test/topbar_test.dart` 新增 6 条「导航高亮与项目态一致」用例（颜色比 `T0Palette.ink` / `muted`） |
| P2 两枚圆钮 36 / 34 不一致 | 统一走 `T0.iconButtonSize = 36` | 像素：主题 `1328-1363`、加号 `1380-1415`，两组都 36 宽；widget 断言 `Size(36,36)`（1440 与 500 两种宽度） |
| P2（待确认②）「模拟解析失败」没描边 | 改成和左右同形的胶囊 + 1px 描边，字色 `danger` 保留危险层级 | `07_intake_buttons_2x.png`：三个按钮同高同形，中间那个红字 |

## 3. 四张图各自证明什么

| 文件 | 证明 |
| --- | --- |
| `01_workbench_topbar.png` | 工作台右侧只剩主题按钮 + 加号：没有头像、没有「城市公共空间调研」、没有「已自动保存」；导航高亮「工作台」 |
| `02_intake_topbar.png` | 材料输入页出现「城市公共空间调研 · 已自动保存」，顺序与 16px 间距正确；导航高亮「当前项目」 |
| `03_workspace_topbar.png` | 模块工作区（`/workspace`）同样出现，说明白名单覆盖五步而不只是 `/intake` |
| `04_back_to_workbench.png` | 在材料输入页点顶栏「工作台」导航返回后这一块收起；整屏与 01 **0/1296000 差异像素、md5 相同** |

补充证据：`05/06_*_dark.png` 证明切主题时这一段跟着变（底色 `#FFFDF8 → #3A2F44`，项目名字色由深变亮、位置不变）；
`07_intake_buttons_2x.png` 是上面 P2 的按钮；`measurements.txt` 是像素扫描原始数值。

`04` 是真实点击产生的：脚本先开 Flutter 语义树，按语义节点定位顶栏「工作台」按钮（88×37 @ 282.6,35.5）再点，
不是重新打开 `#/workbench`。

## 4. 验收命令结果（分支 `wt/t_10b7ac60`）

```
$ flutter analyze
Analyzing t_10b7ac60...
No issues found! (ran in 5.0s)

$ flutter test
00:14 +57: All tests passed!          # 57 条，其中 test/topbar_test.dart 30 条

$ flutter build web --release
Compiling lib\main.dart for the Web...                            144.8s
√ Built build\web

$ flutter build windows --release
Building Windows application...
√ Built build\windows\x64\runner\Release\lab5_crossplatformvisualdesignpractice.exe
```

## 5. 重点看

- `01` / `04` 顶栏右侧是不是真的「只剩两个 36px 圆按钮」——没有留白、没有「+1」残留；
- `02` / `03` 右侧四段间距是否均匀（widget 实测 16.0 / 16.0 / 16.0），导航高亮是否为「当前项目」；
- `07` 三个并排按钮是否同形同高，「模拟解析失败」是否只是字色不同。
