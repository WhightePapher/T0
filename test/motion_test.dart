import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab5_crossplatformvisualdesignpractice/main.dart';
import 'package:lab5_crossplatformvisualdesignpractice/models/mock_data.dart';
import 'package:lab5_crossplatformvisualdesignpractice/theme/app_theme.dart';
import 'package:lab5_crossplatformvisualdesignpractice/theme/motion.dart';
import 'package:lab5_crossplatformvisualdesignpractice/widgets/motion_bits.dart';
import 'package:lab5_crossplatformvisualdesignpractice/widgets/progress_ring.dart';
import 'package:lab5_crossplatformvisualdesignpractice/widgets/status_dot.dart';

/// 动效回归：每条都断言「行为」，不是「有没有跑」。
///
/// 覆盖四件事：
/// 1. 令牌与减弱动效（reduce-motion 下时长为 0、直接落位）；
/// 2. 入场 / 进度环 / 步骤线这些一次性动画播完之后的落位值；
/// 3. 页面转场两层（新页进、旧页退）与 maintainState: false 的关系；
/// 4. tab 指示器滑动、大纲删行让位、Toast 生命周期、状态点呼吸。
void main() {
  Widget harness(Widget child, {bool reduced = false, Size size = const Size(900, 700)}) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: reduced),
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  setUp(T0Store.instance.reset);

  testWidgets('令牌：四档时长 + 三族曲线齐全，减弱动效下 dur 归零', (WidgetTester tester) async {
    expect(T0Motion.instant.inMilliseconds, 90);
    expect(T0Motion.fast.inMilliseconds, 150);
    expect(T0Motion.base.inMilliseconds, 240);
    expect(T0Motion.slow.inMilliseconds, 380);
    expect(T0Motion.enter, isA<Cubic>());
    expect(T0Motion.exit, Curves.easeInCubic);
    expect(T0Motion.standard, Curves.easeOutCubic);

    late Duration normal;
    await tester.pumpWidget(harness(Builder(builder: (BuildContext context) {
      normal = T0Motion.dur(context, T0Motion.base);
      return const SizedBox.shrink();
    })));
    expect(normal, const Duration(milliseconds: 240));

    late Duration reduced;
    await tester.pumpWidget(harness(Builder(builder: (BuildContext context) {
      reduced = T0Motion.dur(context, T0Motion.base);
      return const SizedBox.shrink();
    }), reduced: true));
    expect(reduced, Duration.zero);
  });

  testWidgets('入场动画：首帧透明 + 下移 8px，播完后 opacity 1 / 位移 0', (WidgetTester tester) async {
    await tester.pumpWidget(harness(
      const T0Enter(key: ValueKey<String>('enter'), offset: Offset(0, 8), child: Text('卡片')),
    ));

    double opacity() => tester
        .widget<Opacity>(
          find.descendant(of: find.byType(T0Enter), matching: find.byType(Opacity)),
        )
        .opacity;
    double dy() => tester
        .widget<Transform>(
          find.descendant(of: find.byType(T0Enter), matching: find.byType(Transform)),
        )
        .transform
        .getTranslation()
        .y;

    expect(opacity(), 0);
    expect(dy(), 8);

    await tester.pump(const Duration(milliseconds: 160));
    expect(opacity(), greaterThan(0.0));
    expect(opacity(), lessThan(1.0));

    await tester.pump(const Duration(milliseconds: 200));
    expect(opacity(), 1);
    expect(dy(), 0);
  });

  testWidgets('减弱动效：带 300ms 延时的入场动画也不排队，直接落位', (WidgetTester tester) async {
    await tester.pumpWidget(harness(
      const T0Enter(
        delay: Duration(milliseconds: 300),
        offset: Offset(0, 8),
        child: Text('卡片'),
      ),
      reduced: true,
    ));
    final Opacity opacity = tester.widget<Opacity>(
      find.descendant(of: find.byType(T0Enter), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 1);
    // 延时被跳过：立刻就是终态位置
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('卡片'), findsOneWidget);
  });

  testWidgets('进度环：600ms 内从 0 扫到 80%，中心数字同步取整', (WidgetTester tester) async {
    await tester.pumpWidget(harness(
      ProgressRing(
        value: 0.8,
        size: 150,
        counter: (BuildContext context, double v) => Text('${(v * 100).round()}%'),
      ),
    ));

    int shown() => int.parse(
      tester.widget<Text>(find.byType(Text)).data!.replaceAll('%', ''),
    );

    expect(shown(), 0);
    await tester.pump(const Duration(milliseconds: 300));
    final int mid = shown();
    expect(mid, greaterThan(0));
    expect(mid, lessThan(80));

    await tester.pump(const Duration(milliseconds: 320));
    expect(shown(), 80);
  });

  testWidgets('减弱动效：进度环不扫，直接落在目标值', (WidgetTester tester) async {
    await tester.pumpWidget(harness(
      ProgressRing(
        value: 0.8,
        size: 150,
        counter: (BuildContext context, double v) => Text('${(v * 100).round()}%'),
      ),
      reduced: true,
    ));
    expect(find.text('80%'), findsOneWidget);
  });

  testWidgets('状态点：done 首帧勾选描线未完成，300ms 后落满；减弱动效直接满', (WidgetTester tester) async {
    await tester.pumpWidget(harness(const StatusDot(status: ModuleStatus.done, size: 14)));
    double progress() =>
        tester.widget<T0CheckStroke>(find.byType(T0CheckStroke)).progress;

    expect(progress(), 0);
    await tester.pump(const Duration(milliseconds: 150));
    expect(progress(), greaterThan(0));
    expect(progress(), lessThan(1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(progress(), 1);

    await tester.pumpWidget(harness(
      const StatusDot(status: ModuleStatus.done, size: 14),
      reduced: true,
    ));
    expect(progress(), 1);
  });

  testWidgets('状态点：missing 呼吸（1↔1.15 循环）；减弱动效下静止', (WidgetTester tester) async {
    T0Loops.enabled = true;
    addTearDown(() => T0Loops.enabled = false);

    await tester.pumpWidget(harness(const StatusDot(status: ModuleStatus.missing, size: 8)));
    double scale() => tester
        .widget<Transform>(
          find.descendant(of: find.byType(StatusDot), matching: find.byType(Transform)),
        )
        .transform
        .getMaxScaleOnAxis();

    expect(scale(), closeTo(1.0, 0.01));
    await tester.pump(const Duration(milliseconds: 780));
    expect(scale(), greaterThan(1.05));

    // 把树换掉，别让循环 ticker 留到测试收尾
    await tester.pumpWidget(const SizedBox.shrink());

    // 减弱动效：不呼吸
    await tester.pumpWidget(harness(
      const StatusDot(status: ModuleStatus.missing, size: 8),
      reduced: true,
    ));
    expect(scale(), closeTo(1.0, 0.01));
    await tester.pump(const Duration(milliseconds: 800));
    expect(scale(), closeTo(1.0, 0.01));
  });

  testWidgets('页面转场：新旧两页同时在，旧页随 secondaryAnimation 淡出，落定后旧页摘掉', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const T0App());
    await tester.pumpAndSettle();
    expect(find.text('最近项目'), findsOneWidget);

    await tester.tap(find.text('新建一个项目'));
    await tester.pump(); // 起手
    await tester.pump(const Duration(milliseconds: 100));

    // 两页同时在树上 —— 旧页不是硬切掉的
    expect(find.text('最近项目'), findsOneWidget);
    expect(find.text('把材料交给我，先梳理结构。'), findsOneWidget);

    double opacityOf(String text) => tester
        .widget<Opacity>(
          find.ancestor(of: find.text(text), matching: find.byType(Opacity)).first,
        )
        .opacity;

    // 新页 fade in、旧页 fade out：两者的不透明度都在 0..1 之间
    expect(opacityOf('把材料交给我，先梳理结构。'), lessThan(1.0));
    expect(opacityOf('最近项目'), lessThan(1.0));

    await tester.pumpAndSettle();
    expect(find.text('把材料交给我，先梳理结构。'), findsOneWidget);
    // maintainState: false —— 被盖住的旧页卸载，不再留在树里
    expect(find.text('最近项目'), findsNothing);
  });

  testWidgets('材料输入：tab 指示器 200ms 滑到新位置（不是淡出淡入）', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const T0App(initialRoute: '/intake'));
    await tester.pumpAndSettle();

    // 指示器的实际位置（AnimatedAlign.alignment 是目标值，量出来的是渲染位置）
    double x() => tester
        .getTopLeft(find.descendant(
          of: find.byType(AnimatedAlign),
          matching: find.byType(FractionallySizedBox),
        ))
        .dx;
    final double start = x();

    await tester.tap(find.text('粘贴文本'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final double mid = x();

    await tester.pumpAndSettle();
    final double end = x();
    expect(mid, greaterThan(start + 1)); // 已经在滑
    expect(mid, lessThan(end - 1)); // 但还没到
    // 内容区也换了
    expect(find.text('粘贴正文'), findsOneWidget);
  });

  testWidgets('大纲：删一行时其余行平滑让位，行高收完才真删', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const T0App(initialRoute: '/outline'));
    await tester.pumpAndSettle();

    final Finder footer = find.text('确认大纲，拆成模块');
    final double before = tester.getTopLeft(footer).dy;

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump(); // 只出一帧：行高还没开始收
    expect(tester.getTopLeft(footer).dy, closeTo(before, 0.5));

    await tester.pump(const Duration(milliseconds: 80));
    final double mid = tester.getTopLeft(footer).dy;
    expect(mid, lessThan(before)); // 已经在让位（不是瞬跳，也不是原地不动）

    await tester.pumpAndSettle();
    final double after = tester.getTopLeft(footer).dy;
    expect(after, lessThan(mid)); // 收完才真删
  });

  testWidgets('入场动画期间子树不重建：只有 Opacity / Transform 每帧重跑', (WidgetTester tester) async {
    final ValueNotifier<int> builds = ValueNotifier<int>(0);
    addTearDown(builds.dispose);

    await tester.pumpWidget(harness(T0Enter(
      offset: const Offset(0, 8),
      child: _BuildProbe(builds: builds),
    )));
    final int afterFirst = builds.value;
    expect(afterFirst, greaterThan(0));

    // 沿途 4 帧：动画正卡在中间时，子树一次都不该重建
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(builds.value, afterFirst);
    // 但外层确实在动（否则这条断言没意义）
    final double dy = tester
        .widget<Transform>(find.descendant(of: find.byType(T0Enter), matching: find.byType(Transform)))
        .transform
        .getTranslation()
        .y;
    expect(dy, inExclusiveRange(0, 8));
  });

  testWidgets('Toast：200ms 上滑淡入 → 停留 → 200ms 淡出后从树上移除', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const T0App(initialRoute: '/outline'));
    await tester.pumpAndSettle();

    const String toast = '已新增一个章节，确认前都可以继续调整。';
    await tester.tap(find.text('新增章节'));
    await tester.pump();
    expect(find.text(toast), findsOneWidget);

    double opacity() => tester
        .widget<Opacity>(find.ancestor(of: find.text(toast), matching: find.byType(Opacity)).first)
        .opacity;
    expect(opacity(), 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(), greaterThan(0));
    await tester.pump(const Duration(milliseconds: 150));
    expect(opacity(), 1);

    // 停留 2.4s 后淡出，然后从 Overlay 里移除
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text(toast), findsNothing);
  });
}

/// 只统计自己被 build 了几次的探针（给「动画不重建子树」那条断言用）。
class _BuildProbe extends StatelessWidget {
  const _BuildProbe({required this.builds});

  final ValueNotifier<int> builds;

  @override
  Widget build(BuildContext context) {
    builds.value++;
    return const Text('probe');
  }
}
