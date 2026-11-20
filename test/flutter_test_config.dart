import 'dart:async';

import 'package:lab5_crossplatformvisualdesignpractice/theme/motion.dart';

/// 测试入口：把「无限循环动画」总开关关掉。
///
/// 呼吸点（`status.missing`）和骨架 shimmer 用 `AnimationController.repeat()`，
/// 它会一直排帧 —— `pumpAndSettle()` 于是永远等不到静止，现有 18 个用例会在
/// 打开模块 / 工作区 / 交付页时超时。这里等价于「无动效环境」，
/// 与 `MediaQuery.disableAnimations` 走同一条降级路径（循环动画退化为静止）。
/// 动效本身的断言在 `test/motion_test.dart` 里单独把开关打开再验证。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  T0Loops.enabled = false;
  await testMain();
}
