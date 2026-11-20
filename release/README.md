# Lab5 · 交付产物

三个平台各一个目录，入口文件都在本目录，双击即可。

```
release\
├─ 启动 Lab5（Windows）.bat      → 打开 Windows 桌面版
├─ 启动 Lab5（Web）.bat          → 起本地服务 + 自动开浏览器
├─ Windows\                     Lab5办公.exe + flutter_windows.dll + data\
├─ Web\                         index.html + 全部前端资源 + serve.py
└─ Android\                     Lab5办公.apk（拷到手机上安装）
```

## 各平台怎么开

**Windows 桌面版**
```
双击  启动 Lab5（Windows）.bat
或    直接进 Windows\ 双击 Lab5办公.exe
```
整个 `Windows\` 目录必须一起拷走（exe 离开 dll 和 data 打不开）。

**Web 版**
```
双击  启动 Lab5（Web）.bat
```
会打开一个黑窗口跑本地服务，浏览器自动弹到 `127.0.0.1:8777`（端口被占会自动换）。
**黑窗口关掉 = 服务停止**。不能直接双击 `Web\index.html`，Flutter web 用 fetch 加载资源，`file://` 会被浏览器拦掉。

**Android**
```
把 Android\Lab5办公.apk 传到手机安装
```
首次安装需允许「安装未知来源应用」。

## 版本

```
构建时间    2026-11-12 晚（主题系统 + 文案精简后的版本）
平台        Windows x64 / Web / Android arm64
```
