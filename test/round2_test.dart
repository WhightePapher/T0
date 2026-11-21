import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab5_crossplatformvisualdesignpractice/features/delivery/delivery_page.dart';
import 'package:lab5_crossplatformvisualdesignpractice/main.dart';
import 'package:lab5_crossplatformvisualdesignpractice/models/mock_data.dart';
import 'package:lab5_crossplatformvisualdesignpractice/perf/launch_args.dart';
import 'package:lab5_crossplatformvisualdesignpractice/theme/app_theme.dart';
import 'package:lab5_crossplatformvisualdesignpractice/theme/palette.dart';
import 'package:lab5_crossplatformvisualdesignpractice/theme/tokens.dart';
import 'package:lab5_crossplatformvisualdesignpractice/widgets/focus_ring.dart';
import 'package:lab5_crossplatformvisualdesignpractice/widgets/project_card.dart';

/// 第二轮回归：A 组（可测的帧采集入口）与 B 组（视觉细节）各挑一条硬断言。
///
/// 每条都断言「行为」而不是「跑过」：焦点环真的画出来了、等宽数字真的挂上了、
/// 阴影真的变成两层、hover 真的上移 1px、`?perf=` 真的被解析成场景名。
void main() {
  setUp(T0Store.instance.reset);

  group('A1 启动参数：args 与查询串共用一套解析', () {
    test('?perf= 与 ?route= 从查询串进入', () {
      final T0LaunchArgs launch = T0LaunchArgs.parse(
        const <String>[],
        const <String, String>{'perf': 'theme', 'route': '/delivery', 'motion': '6'},
      );
      expect(launch.perf, 'theme');
      expect(launch.route, '/delivery');
      expect(launch.motionScale, 6);
    });

    test('args 优先，空值不覆盖', () {
      final T0LaunchArgs launch = T0LaunchArgs.parse(
        const <String>['--perf=dialog', '--route=', '--motion=abc'],
        const <String, String>{'perf': 'works', 'route': '/outline', 'motion': '2'},
      );
      expect(launch.perf, 'dialog');
      // --route= 是空值 → 退回查询串
      expect(launch.route, '/outline');
      // --motion=abc 解析失败 → 退回查询串
      expect(launch.motionScale, 2);
    });

    test('都没有时为 null（正常启动不注册任何采集回调）', () {
      final T0LaunchArgs launch = T0LaunchArgs.parse(
        const <String>[],
        const <String, String>{},
      );
      expect(launch.perf, isNull);
      expect(launch.route, isNull);
      expect(launch.motionScale, isNull);
    });
  });

  group('B1 阴影：light 两层 / dark 1px 提亮描边', () {
    test('light 的 floatShadow 是 key light + ambient 两层', () {
      final List<BoxShadow> shadows = T0Palette.light.floatShadow;
      expect(shadows.length, 2);
      expect(shadows[0].blurRadius, 18);
      expect(shadows[0].offset, const Offset(0, 2));
      expect(shadows[1].blurRadius, 48);
      expect(shadows[1].offset, const Offset(0, 18));
      // 两层都从同一个 shadow 色派生，alpha 都比原色低
      expect(shadows[0].color.a, lessThan(T0Palette.light.shadow.a));
      expect(shadows[1].color.a, lessThan(shadows[0].color.a));
    });

    test('dark 换成 1px 描边（0 模糊 + 1px 扩散），hover 更亮', () {
      final List<BoxShadow> rest = T0Palette.dark.floatShadow;
      expect(rest.length, 1);
      expect(rest.single.blurRadius, 0);
      expect(rest.single.spreadRadius, 1);
      expect(T0Palette.dark.floatShadowHover.first.color.a,
          greaterThanOrEqualTo(rest.single.color.a));
    });
  });

  testWidgets('B4 焦点环：FocusNode 拿到焦点后可见（2px / deckAccent / offset 2）',
      (WidgetTester tester) async {
    final FocusNode node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: T0FocusRing(
              focusNode: node,
              radius: 18,
              child: const SizedBox(width: 120, height: 40),
            ),
          ),
        ),
      ),
    );

    T0FocusRingPainter ring() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((CustomPaint paint) => paint.foregroundPainter)
        .whereType<T0FocusRingPainter>()
        .first;

    expect(ring().visible, isFalse);
    node.requestFocus();
    await tester.pump();
    expect(ring().visible, isTrue);
    expect(ring().strokeWidth, 2);
    expect(ring().offset, 2);
    expect(ring().color, T0Palette.light.deckAccent);
  });

  testWidgets('B2 hover 抬升：鼠标进入后卡片上移 1px 且阴影加深',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: T0Metrics(
          width: 1440,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 420,
                child: ProjectCard(project: recentProjects.first),
              ),
            ),
          ),
        ),
      ),
    );

    AnimatedContainer container() => tester.widget<AnimatedContainer>(
          find.descendant(of: find.byType(ProjectCard), matching: find.byType(AnimatedContainer)).first,
        );

    expect(container().transform!.getTranslation().y, 0);

    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(ProjectCard)));
    await tester.pumpAndSettle();

    expect(container().transform!.getTranslation().y, -1);
    final BoxDecoration decoration = container().decoration! as BoxDecoration;
    expect(decoration.boxShadow!.length, 2);
  });

  testWidgets('B3 等宽数字：交付页百分比用 tabular figures', (WidgetTester tester) async {
    await tester.pumpWidget(const T0App(initialRoute: DeliveryPage.routeName));
    await tester.pumpAndSettle();

    final Finder percent = find.byWidgetPredicate((Widget widget) {
      return widget is Text && (widget.data ?? '').endsWith('%');
    });
    expect(percent, findsOneWidget);
    final Text text = tester.widget<Text>(percent);
    expect(text.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  testWidgets('B7 滚动：桌面 Clamping / 窄屏 Bouncing', (WidgetTester tester) async {
    late ScrollPhysics desktop;
    late ScrollPhysics mobile;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: T0Metrics(
          width: 1440,
          child: Builder(builder: (BuildContext context) {
            desktop = t0ScrollPhysics(context);
            return const SizedBox.shrink();
          }),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: T0Metrics(
          width: 500,
          child: Builder(builder: (BuildContext context) {
            mobile = t0ScrollPhysics(context);
            return const SizedBox.shrink();
          }),
        ),
      ),
    );
    expect(desktop, isA<ClampingScrollPhysics>());
    expect(mobile, isA<BouncingScrollPhysics>());
  });
}
