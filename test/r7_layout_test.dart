import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab5_crossplatformvisualdesignpractice/main.dart';
import 'package:lab5_crossplatformvisualdesignpractice/models/mock_data.dart';

/// r7 的版面契约（都是「按像素可证」的三条）：
///   1. 05 纸张卡末行与页脚分隔线间距 ≥20px（默认缩放 0.71，未滚动）；
///   2. press_02 纸卡三栏色线完全等长（= 三栏同宽）；
///   3. 按住「按住看修改前」的瞬间按钮不变形（宽度 / 左边界不动）。
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

  testWidgets('默认缩放 0.71：05 纸张卡末行与页脚分隔线间距 ≥20px', (WidgetTester tester) async {
    await pumpWorkspace(tester);

    expect(T0Store.instance.zoom.value, 0.71);

    // 页脚（_canvasFoot）上下 padding 各 14px，所以上边框 = 首行 row 的 top - 14
    final Rect footRow = tester.getRect(
      find.ancestor(of: find.textContaining('模块目标：'), matching: find.byType(Row)).first,
    );
    final double dividerY = footRow.top - 14;

    // 第三项正文（v2 压缩版最后一行就是它）
    final Rect lastRow = tester.getRect(find.text('让座椅、界面和活动区互相形成观看关系。'));
    final double gap = dividerY - lastRow.bottom;
    expect(gap, greaterThanOrEqualTo(20.0),
        reason: '末行字底 ${lastRow.bottom.toStringAsFixed(1)} / 页脚分隔线 '
            '${dividerY.toStringAsFixed(1)} / 间距 ${gap.toStringAsFixed(1)}px');
  });

  testWidgets('press_02 纸卡三栏色线等长（三栏同宽，末栏不再多 15px）', (WidgetTester tester) async {
    // v1（未压缩）才走三栏布局
    T0Store.instance.revertEdit(4);
    await pumpWorkspace(tester);

    final List<double> widths = <double>[
      for (final String title in <String>['路径连续', '边界可读', '视线有落点'])
        tester.getRect(
          // 色线是 Column 的第一个子节点（Container height: 2），Column 的宽就是线长
          find
              .ancestor(of: find.text(title).first, matching: find.byType(Column))
              .first,
        ).width,
    ];
    final double spread = widths.reduce(math.max) - widths.reduce(math.min);
    expect(spread, lessThan(0.5), reason: '三栏宽度 ${widths.map((double w) => w.toStringAsFixed(1)).toList()}');
  });

  testWidgets('按住「按住看修改前」按钮不变形：宽度与左边界都不动', (WidgetTester tester) async {
    await pumpWorkspace(tester);

    Finder button() => find
        .ancestor(of: find.text('按住看修改前').first, matching: find.byType(AnimatedContainer))
        .first;

    final Rect idle = tester.getRect(button());

    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.down(tester.getCenter(find.text('按住看修改前').first));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 按下后文案已换成「修改前」，按钮矩形必须与松开态逐像素相同
    expect(find.text('修改前'), findsOneWidget);
    final Rect held = tester.getRect(
      find
          .ancestor(of: find.text('修改前'), matching: find.byType(AnimatedContainer))
          .first,
    );
    expect((held.width - idle.width).abs(), lessThan(0.5),
        reason: '宽 ${idle.width.toStringAsFixed(1)} → ${held.width.toStringAsFixed(1)}');
    expect((held.left - idle.left).abs(), lessThan(0.5),
        reason: '左边界 ${idle.left.toStringAsFixed(1)} → ${held.left.toStringAsFixed(1)}');

    await mouse.up();
    await tester.pumpAndSettle();
  });
}
