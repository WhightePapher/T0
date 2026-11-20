# t0办公 · 跨平台高保真应用（实验五）

把「t0办公」实验四的交互原型，做成可运行的跨平台高保真应用：六个界面（工作台 / 材料输入 / 大纲确认 / 模块拆分 / 模块工作区 / 交付检查）走完整流程，桌面三栏、窄屏抽屉、手机单列都成立。

- 视觉与交互说明：`docs/视觉设计说明.md`
- 六页 1440×900 实拍：`docs/screenshots/`

## 运行

```bash
flutter pub get
flutter run -d chrome          # 浏览器里直接跑
flutter build web --release    # 产物 build/web，本地静态服务打开
```

`build/web` 建议用静态服务器打开（`python -m http.server --directory build/web 8765`，然后访问 `http://localhost:8765`），浏览器直开 `index.html` 受 file:// 跨域限制。

桌面端（Windows）需要本机安装 Visual Studio「使用 C++ 的桌面开发」：

```bash
flutter build windows --release   # 产物 build/windows/x64/runner/Release/*.exe
```

## 验收

```bash
flutter analyze                  # 0 issue
flutter test                     # 18 个用例：六页在 1440×900 / 500×900 下均无溢出 + 交付分组 + 字体令牌
flutter build web --release
python tool/font_coverage.py     # 缺字自检，必须输出 missing: 0
```

字体全部随 `assets/fonts/` 打包（OFL 许可的 Noto Sans SC / Noto Serif SC 子集 + Cascadia Mono 拉丁子集），
由 `tool/prepare_fonts.py` 生成，构建机不需要 fontTools。

## 目录

```
lib/
  main.dart                 入口 + 命名路由（240ms 淡入上移）
  theme/tokens.dart         颜色 / 字号 / 间距 / 圆角 / 打包字体家族名
  theme/app_theme.dart      ThemeData
  widgets/                  app_shell / paper_background / section_label /
                            primary_button / ghost_button / status_dot /
                            progress_ring / project_card
  features/                 workbench / intake / outline / modules /
                            workspace / delivery
  models/mock_data.dart     固定示例数据 + ValueNotifier 状态
assets/fonts/               打包字体（T0Sans / T0Serif / T0Mono）
tool/
  prepare_fonts.py          从系统字体生成子集 + 静态字重（开发期脚本）
  font_coverage.py          缺字自检（纯标准库读 cmap）
docs/screenshots_v2/        修复后实拍：六屏 1440×900 + 窄屏 + hover + 前后对比
```

约束：只用 flutter sdk + cupertino_icons，无状态管理库、无远程资源、无位图界面；颜色与字号全部取自 `tokens.dart`。
