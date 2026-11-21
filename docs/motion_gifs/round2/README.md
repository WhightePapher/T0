# round2 · 视觉与帧证据（第二轮）

一条命令重跑（仓库根目录）：

```bash
export PATH=/data/flutter/bin:$PATH
flutter build web --profile
python3 tool/capture_round2.py
# 只重出某一段：python3 tool/capture_round2.py --only=focus
```

| 文件 | 拍的是什么 | 帧数 | 放慢 |
|---|---|---|---|
| `01_card_shadow_hover.gif` | 工作台项目卡：双层阴影（key light 18/2 + ambient 48/18）+ hover 时整体上移 1px、阴影加深 | 33 | 3× |
| `02_focus_ring.gif` | 工作区里连按 Tab：焦点环（2px · `deckAccent` · offset 2）依次落到顶栏导航、图标按钮、前后对比胶囊… | 10 | 1× |
| `03_skeleton_rhythm.gif` | 点「应用修改」后的骨架屏：标题短条 + 正文长条两档宽度，两条光带速度不同（长条扫得快） | 79 | 1.5× |
| `04_dialog_before_after.gif` | 前后对比弹层：左＝`feat/motion` 旧构建，右＝`perf/round2`，按**动画进度**（纸白像素量）对齐，不是按墙钟 | 6 | 4× |

说明：

- 抓帧用 `Page.startScreencast`（每次合成收一帧），headless 走 SwiftShader，一次合成 30–100ms，
  所以 01 / 03 / 04 在截图进程里用 `?motion=N` 放慢；线上令牌与曲线一行没改。
- `04` 的两侧是**两套真实构建**：左边从 `feat/motion` 用 `git worktree` 检出后
  `flutter build web --profile`（`T0_BEFORE_DIR` 可覆盖，默认 `/tmp/t0_before/build/web`）。
  标签上的 `raster p95` 取自 `docs/帧耗时_before.json` / `帧耗时_after.json`。
- `manifest.json` 里有每段 GIF 的帧数、尺寸与放慢倍数。
