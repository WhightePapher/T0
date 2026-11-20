# docs/motion_gifs · 动效帧证据

由 `tool/capture_motion.py` 生成，一条命令重跑：

```bash
flutter build web --release
xvfb-run -a python3 tool/capture_motion.py
```

- `0X_*.gif` + 同名 `0X_*.png`：四段动效的 GIF 与 contact sheet（6–10 帧，时间等距）。
- `stills/{route}_{1440x900,500x900}.png`：六个界面两档尺寸的静止态。
- `stills/drift.json`：同一页隔 400ms 再拍一张的像素差（`prefers-reduced-motion: reduce` 下全 0）。
- `manifest.json`：每段抓帧的窗口、帧数、放慢倍数、以及换算回真实的毫秒数。

**为什么 GIF 是慢动作**：抓帧跑在 headless chromium 上（SwiftShader 软件合成），一次合成要
120–200ms；150ms 的 cross-fade 只够抓 1–2 帧。所以抓帧时用 `?motion=N` 把动画放慢 6 / 16 / 10 倍
（`T0Motion.captureScale`，只影响截图进程），令牌值与曲线一行没改。GIF 的播放速度因此是真实速度的
`1/N`，`manifest.json` 里的 `real_ms` 是换回真实时长后的窗口。

逐条的时长 / 曲线 / 代码位置 / reduce-motion 行为见 [`../动效清单.md`](../动效清单.md)。
