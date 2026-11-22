# 顶栏导航改版 · 取证（1440×900 / 500×900）

本轮改了三处，截图按「改动 → 图」对应：

| 图 | 证明什么 |
|---|---|
| `01-nav-desktop.png` | 顶栏分段控件只剩「工作台 / 当前项目」两项（「帮助」已删），指示块停在左格 |
| `02-nav-workspace.png` | 点「当前项目」后整屏：指示块在右格；右栏「作用范围：当前模块」，底部两枚胶囊开启态 |
| `06-nav-motion.png` | 从 24ms 到 518ms 之间连拍 4 帧：第 3 帧指示块压在两格交界处 —— 是滑过去，不是瞬跳 |
| `03-chips-on.png` | 底部长条：两枚胶囊开启（实心底 + 圆点） |
| `08-chips-off-toast.png` | 点掉「保留历史版本」后弹出的 toast：「未保留历史版本：应用修改后会覆盖 v1」 |
| `04-chips-off.png` | 同一条长条，两枚都关闭（只描边、无圆点） |
| `07-workspace-off-full.png` | 关闭后的整屏：撤销图标置灰、版本角标 `v2·覆盖`、右栏提示「v1 已被覆盖，撤销不可用」、「作用范围：整条流程」 |
| `05-nav-mobile.png` | 500×900 窄屏：顶栏走 `_buildMobile`（无分段控件），无横向溢出 |

## 复现

```bash
flutter build web --release --base-href /T0/
mkdir -p /tmp/site && ln -s "$PWD/build/web" /tmp/site/T0
(cd /tmp/site && python3 -m http.server 8099 --bind 127.0.0.1 &)
# 构建产物里的 base href 是 /T0/，所以必须挂在 /T0/ 这个子路径下，否则整页 404 白屏
python3 tool/shoot_nav2.py            # 01–05、07、08
python3 motion.py                     # 单独录滑动帧（screencast）
python3 analyze_motion.py             # 拼 06-nav-motion.png
```

`tool/shoot_nav2.py` 用 CDP 驱动 headless chromium：
点「当前项目」的坐标 (385, 36) 是按 1440 宽截图量出来的，改字号后要重新量。
