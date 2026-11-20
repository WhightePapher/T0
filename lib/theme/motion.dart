import 'package:flutter/material.dart';

import 'palette.dart';

/// 全项目唯一的运动语言：四档时长 + 三族曲线。
///
/// 约定（和颜色一样严格）：
/// * 页面里**不许再写裸的 `Duration(milliseconds: …)`**，一律从这里取；
/// * 所有时长都经 [`T0Motion.dur`] 出口 —— 它内部调 `context.anim`，
///   主题渐变进行中归零（否则组件动画会去追每帧都在变的目标色），
///   `MediaQuery.disableAnimations` 为真时也归零（系统减弱动效）；
/// * 曲线只用 [enter] / [exit] / [standard] 三族，不引入第四种。
class T0Motion {
  const T0Motion._();

  // ------------------------------------------------------------ 时长：四档
  /// 按压、微反馈
  static const Duration instant = Duration(milliseconds: 90);

  /// 内容替换、状态切换
  static const Duration fast = Duration(milliseconds: 150);

  /// 页面转场、卡片入场
  static const Duration base = Duration(milliseconds: 240);

  /// 整屏级
  static const Duration slow = Duration(milliseconds: 380);

  // ------------------------------------------------------- 各组的命名时长
  /// G1 新页进入
  static const Duration pageIn = base;

  /// G1 旧页退出
  static const Duration pageOut = Duration(milliseconds: 180);

  /// G2 页面标题切换 / G4 tab 指示器滑动
  static const Duration title = Duration(milliseconds: 200);

  /// G2 当前步骤圆点一次性脉冲
  static const Duration stepPulse = Duration(milliseconds: 320);

  /// G3 项目卡片入场
  static const Duration cardIn = Duration(milliseconds: 320);

  /// G3 / G8 进度环 sweep
  static const Duration ring = Duration(milliseconds: 600);

  /// G6 模块卡片入场
  static const Duration moduleCardIn = Duration(milliseconds: 280);

  /// G4 解析失败卡片展开
  static const Duration failCard = Duration(milliseconds: 220);

  /// G7 / G8 弹层进入
  static const Duration dialogIn = Duration(milliseconds: 220);

  /// G7 / G8 弹层退出
  static const Duration dialogOut = Duration(milliseconds: 160);

  /// G5 / G7 提示条（120ms 淡入 + 高度展开）
  static const Duration hint = Duration(milliseconds: 120);

  /// G6 / G8 勾选描线
  static const Duration checkStroke = Duration(milliseconds: 300);

  /// G6 待补充状态点呼吸
  static const Duration breathe = Duration(milliseconds: 1600);

  /// G7 骨架 shimmer 横扫
  static const Duration shimmer = Duration(milliseconds: 1200);

  /// G9 Toast 进出
  static const Duration toast = Duration(milliseconds: 200);

  /// G9 Toast 停留
  static const Duration toastHold = Duration(milliseconds: 2400);

  /// G5 章节行让位（新增/移除时的行高动画）
  static const Duration rowResize = base;

  /// G5 新增行 green-soft 高亮淡出
  static const Duration highlightFade = Duration(milliseconds: 3000);

  // ------------------------------------------------------------ 错峰间隔
  static const Duration staggerCard = Duration(milliseconds: 45);
  static const Duration staggerModule = Duration(milliseconds: 40);
  static const Duration staggerOutline = Duration(milliseconds: 30);
  static const Duration staggerCheck = Duration(milliseconds: 60);
  static const Duration staggerComparePane = Duration(milliseconds: 40);

  // ------------------------------------------------------------ 曲线三族
  /// 无过冲的出场：起步快、收尾稳（页面、卡片、弹层进入）
  static const Curve enter = Cubic(0.16, 1, 0.30, 1);

  /// 退场
  static const Curve exit = Curves.easeInCubic;

  /// 尺寸 / 位置 / 颜色沿用现有观感
  static const Curve standard = Curves.easeOutCubic;

  /// 统一出口：组件动画的时长都从这里拿。
  ///
  /// 内部走 `context.anim(...)`：主题渐变中为 0、系统减弱动效时为 0。
  static Duration dur(BuildContext context, Duration base) =>
      context.anim(scaled(base));

  /// 抓帧用的放慢倍数（默认 1，线上行为不变）。
  ///
  /// 由 `main()` 从 `--motion=6`（桌面）或 `?motion=6`（web 截图）读入：
  /// headless chromium 走 SwiftShader，一次合成要 80–140ms，150ms 的 cross-fade
  /// 只够抓 1–2 帧；放慢 6 倍才能拿到 8 帧的 contact sheet。
  /// **只影响截图证据里看到的速度，令牌值 / 曲线一个都没改。**
  static double captureScale = 1;

  static Duration scaled(Duration base) => captureScale == 1
      ? base
      : Duration(microseconds: (base.inMicroseconds * captureScale).round());

  /// 系统是否要求减弱动效（循环类动画据此直接停住，不留静态阴影差异）
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// 抖动（帧内取整）用：把 0..1 的进度换成整数显示，避免逐帧小数抖动。
  static int tick(double progress, int total) => (progress * total).round();
}

/// 无限循环动画（`missing` 呼吸、骨架 shimmer）的总开关。
///
/// 为什么需要它：`AnimationController.repeat()` 会一直排帧，
/// widget 测试里的 `pumpAndSettle()` 就永远等不到「静止」。
/// `test/flutter_test_config.dart` 在测试入口把它关掉（等价于无动效环境），
/// 应用运行时保持 true —— 线上仍然是真循环。
class T0Loops {
  const T0Loops._();

  static bool enabled = true;
}
