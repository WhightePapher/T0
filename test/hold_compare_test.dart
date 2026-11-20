import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab5_crossplatformvisualdesignpractice/main.dart';
import 'package:lab5_crossplatformvisualdesignpractice/models/mock_data.dart';

/// 「按住看修改前」的交互契约（r6 / P0）：
///   1. 悬浮不改变任何东西 —— 画布仍是 v2，也没有提示；
///   2. 按住 → 画布真的降到 v1（封面页脚变「版本 1 · 当前页」）+ 出现「正在看修改前」；
///   3. 按住后拖出按钮再松手 → 复位回 v2（不能卡在修改前）；
///   4. 右键按下也算按住（PointerDown 不分键），松手同样复位。
void main() {
  setUp(T0Store.instance.reset);

  Future<void> pumpWorkspace(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const T0App(initialRoute: '/workspace'));
    await tester.pumpAndSettle();
  }

  /// AnimatedSwitcher 是 150ms：先出一帧建立切换，再 advance 两帧后淡出的旧页才摘掉
  Future<void> settleFade(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder holdButton() => find.text('按住看修改前');

  testWidgets('悬浮 3 秒不切版本，按住才切到 v1 并给出提示', (WidgetTester tester) async {
    await pumpWorkspace(tester);

    // 模块 4 默认是 v2
    expect(find.text('版本 2 · 结构压缩版'), findsOneWidget);
    expect(find.text('正在看修改前'), findsNothing);

    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    // ① 只是悬浮：3 秒内不出现提示、画布仍是 v2
    await mouse.moveTo(tester.getCenter(holdButton()));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('正在看修改前'), findsNothing);
    expect(find.text('版本 2 · 结构压缩版'), findsOneWidget);
    expect(find.text('版本 1 · 当前页'), findsNothing);

    // ② 按住：画布切到 v1 + 提示出现
    await mouse.down(tester.getCenter(holdButton()));
    await settleFade(tester);
    expect(find.text('正在看修改前'), findsOneWidget);
    expect(find.text('版本 1 · 当前页'), findsOneWidget);
    expect(find.text('版本 2 · 结构压缩版'), findsNothing);

    // ③ 拖出按钮再松手：必须复位
    await mouse.moveTo(const Offset(40, 40));
    await mouse.up();
    await settleFade(tester);
    expect(find.text('正在看修改前'), findsNothing);
    expect(find.text('版本 2 · 结构压缩版'), findsOneWidget);
    expect(find.text('版本 1 · 当前页'), findsNothing);
  });

  testWidgets('右键按下同样进入修改前，松开复位', (WidgetTester tester) async {
    await pumpWorkspace(tester);

    // 用 TestPointer 显式带 kSecondaryMouseButton 发一次按下：
    // createGesture 的 buttons 只在 addPointer 生效，右键事件送不到 Listener
    final TestPointer right = TestPointer(7, PointerDeviceKind.mouse, kSecondaryMouseButton);
    final Offset center = tester.getCenter(holdButton());
    await tester.sendEventToBinding(right.hover(center));
    await tester.sendEventToBinding(right.down(center));
    await settleFade(tester);
    expect(find.text('正在看修改前'), findsOneWidget);
    expect(find.text('版本 1 · 当前页'), findsOneWidget);

    await tester.sendEventToBinding(right.up());
    await settleFade(tester);
    expect(find.text('正在看修改前'), findsNothing);
    expect(find.text('版本 2 · 结构压缩版'), findsOneWidget);
  });

  testWidgets('没编辑过的模块按住不假装有变化', (WidgetTester tester) async {
    await pumpWorkspace(tester);

    // 切到模块 1（只有 v1）
    T0Store.instance.setActiveModule(1);
    await tester.pumpAndSettle();
    expect(find.text('版本 1 · 当前页'), findsOneWidget);

    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.down(tester.getCenter(holdButton()));
    await settleFade(tester);

    expect(find.text('正在看修改前'), findsNothing);
    expect(find.text('版本 1 · 当前页'), findsOneWidget);

    await mouse.up();
    await settleFade(tester);
  });
}
