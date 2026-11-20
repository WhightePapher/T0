import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab5_crossplatformvisualdesignpractice/main.dart';
import 'package:lab5_crossplatformvisualdesignpractice/models/mock_data.dart';
import 'package:lab5_crossplatformvisualdesignpractice/theme/palette.dart';
import 'package:lab5_crossplatformvisualdesignpractice/theme/tokens.dart';
import 'package:lab5_crossplatformvisualdesignpractice/widgets/app_shell.dart';
import 'package:lab5_crossplatformvisualdesignpractice/widgets/ghost_button.dart';
import 'package:lab5_crossplatformvisualdesignpractice/widgets/primary_button.dart';

void main() {
  setUp(T0Store.instance.reset);

  testWidgets('工作台渲染巨号标题、最近项目与产品流程卡', (WidgetTester tester) async {
    await tester.pumpWidget(const T0App());
    await tester.pumpAndSettle();

    expect(find.textContaining('把一次汇报'), findsOneWidget);
    expect(find.text('三步'), findsOneWidget);
    expect(find.text('从一份材料开始'), findsOneWidget);
    // 冗余文案已删：产品理念 / 演示提示不再进页面
    expect(find.text('演示提示'), findsNothing);
    expect(find.textContaining('今天只演示'), findsNothing);
  });

  testWidgets('新建项目按钮推进到材料输入', (WidgetTester tester) async {
    await tester.pumpWidget(const T0App());
    await tester.pumpAndSettle();

    await tester.tap(find.text('新建一个项目'));
    await tester.pumpAndSettle();

    expect(find.text('把材料交给我，先梳理结构。'), findsOneWidget);
    expect(find.text('使用示例材料'), findsOneWidget);
  });

  test('模块状态循环切换驱动进度', () {
    final T0Store store = T0Store.instance;
    expect(store.confirmedCount, 3);

    store.cycleStatus(5); // 待补充 → 已确认
    expect(store.confirmedCount, 4);
    expect(store.statusOf(5), ModuleStatus.done);

    store.cycleStatus(5);
    expect(store.statusOf(5), ModuleStatus.review);
  });

  testWidgets('500px 窄屏下工作台不溢出', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const T0App());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('拆成'), findsOneWidget);
  });

  testWidgets('交付检查按状态分组，徽章数字 = 待确认 + 待补充', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const T0App(initialRoute: '/delivery'));
    await tester.pumpAndSettle();

    // 初始状态：3 已确认 / 1 待确认 / 1 待补充
    expect(find.text('已确认'), findsWidgets);
    expect(find.text('待确认'), findsWidgets);
    expect(find.text('待补充'), findsWidgets);
    expect(find.text('2 项待处理'), findsOneWidget);
    expect(find.text('设计建议'), findsOneWidget);
  });

  testWidgets('交付口径写清楚：80% = 已就绪 4/5（含 1 待确认），不再说成已确认', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const T0App(initialRoute: '/delivery'));
    await tester.pumpAndSettle();

    expect(find.text('80%'), findsOneWidget);
    // 环图下的口径小字
    expect(find.text('已就绪 4/5（含 1 待确认）'), findsOneWidget);
    // 大标题只剩「待补充 N 个模块」，不再挂第二行「（另有 1 个待确认）」
    expect(find.text('待补充 1 个模块'), findsOneWidget);
    expect(find.textContaining('另有'), findsNothing);
    expect(find.textContaining('还差'), findsNothing);
    // 说明段一句话、一行，不再出现「已有内容」这层同义词
    expect(find.text('“结论总结”仍在等材料。'), findsOneWidget);
    expect(find.textContaining('已有内容'), findsNothing);
    expect(find.textContaining('已经确认'), findsNothing);
    // v3 遗留：同一概念只用一套词（已确认 / 待确认 / 待补充），不再混「已完成 / 全部完成」
    expect(find.text('整体就绪度'), findsOneWidget);
    expect(find.textContaining('已完成'), findsNothing);
    expect(find.textContaining('全部完成'), findsNothing);
    // 来源不再抄状态词：行内只出现一次「待补充」
    expect(find.text('补一条可以引用的结论 · 尚缺材料'), findsOneWidget);
  });

  testWidgets('03 采纳「第 3 章拆成两页」后，大纲页数才从 1 页变 2 页', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const T0App(initialRoute: '/outline'));
    await tester.pumpAndSettle();

    // 初始 1 页：建议还没采纳
    expect(find.text('通行、停留与活动之间的边界冲突 · 1 页'), findsOneWidget);

    await tester.tap(find.text('采纳').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('通行、停留与活动之间的边界冲突 · 2 页'), findsOneWidget);
    expect(T0Store.instance.outline.value[2].pages, '2 页');

    // 采纳会弹 2.4s 的 toast，跑完定时器再结束，避免 pending timer
    await tester.pump(const Duration(seconds: 3));
  });

  test('字体家族名指向打包字体，不再依赖系统字体', () {
    expect(T0.sansFamily, 'T0Sans');
    expect(T0.serifFamily, 'T0Serif');
    expect(T0.monoFamily, 'T0Mono');
    // fallback 只允许在打包字体之间兜底
    for (final String name in <String>[...T0.sansFallback, ...T0.serifFallback, ...T0.monoFallback]) {
      expect(name.startsWith('T0'), isTrue, reason: '$name 不是打包字体');
    }
  });

  testWidgets('右上角切换主题：420ms 内是中间态，落定后是黑夜调色板', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const T0App());
    await tester.pumpAndSettle();

    T0Palette current() => T0Palette.of(tester.element(find.byType(AppShell)));

    // 默认白天，色值必须和旧 screenshots_v3 的暖纸底一致
    expect(current().bg, T0Palette.light.bg);
    expect(current().bg, const Color(0xFFF6F2E9));

    // 主题图标是 CustomPaint 自绘（不读 MaterialIcons 字体），用 key 定位
    await tester.tap(find.byKey(const ValueKey<String>('theme-glyph-sun')));
    await tester.pump(); // 起手
    await tester.pump(const Duration(milliseconds: 210));

    // 210ms 是 420ms 的一半略多：颜色必须是中间态，不能已经跳到黑夜
    final Color mid = current().bg;
    expect(mid, isNot(T0Palette.light.bg));
    expect(mid, isNot(T0Palette.dark.bg));

    await tester.pump(const Duration(milliseconds: 300));
    expect(current().bg, T0Palette.dark.bg);
    expect(current().ink, T0Palette.dark.ink);
    expect(find.byKey(const ValueKey<String>('theme-glyph-moon')), findsOneWidget);
    // P1 回归：主题按钮不能再依赖图标字体（Windows 增量构建会复用旧子集）
    expect(find.byIcon(Icons.dark_mode_outlined), findsNothing);
    expect(find.byIcon(Icons.light_mode_outlined), findsNothing);
  });

  test('黑夜调色板对比度：正文 ≥ 4.5、标题 ≥ 7', () {
    double channel(double c) {
      final double v = c / 255;
      return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    double luminance(Color c) =>
        0.2126 * channel(c.r * 255) + 0.7152 * channel(c.g * 255) + 0.0722 * channel(c.b * 255);

    double contrast(Color fg, Color bg) {
      final double a = luminance(fg);
      final double b = luminance(bg);
      return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
    }

    const T0Palette d = T0Palette.dark;
    final Map<String, (Color, Color, double)> pairs = <String, (Color, Color, double)>{
      'ink / bg': (d.ink, d.bg, 7),
      'ink / surface': (d.ink, d.surface, 7),
      'ink / canvas': (d.ink, d.canvas, 7),
      'ink2 / surface': (d.ink2, d.surface, 4.5),
      'ink2 / surface2': (d.ink2, d.surface2, 4.5),
      'ink2 / bg': (d.ink2, d.bg, 4.5),
      'muted / bg': (d.muted, d.bg, 4.5),
      'muted / canvas': (d.muted, d.canvas, 4.5),
      // mono / eyebrow / label 都取 muted，深色下必须也在卡面上达标
      'muted / surface': (d.muted, d.surface, 4.5),
      'muted / surface2': (d.muted, d.surface2, 4.5),
      'accent / surface': (d.accent, d.surface, 4.5),
      'accent / bg': (d.accent, d.bg, 4.5),
      'accentStrong / accentSoft': (d.accentStrong, d.accentSoft, 4.5),
      'ok / accentSoft': (d.ok, d.accentSoft, 4.5),
      'warn / warnSoft': (d.warn, d.warnSoft, 4.5),
      'danger / dangerSoft': (d.danger, d.dangerSoft, 4.5),
      // 06 材料输入：「模拟解析失败」压的是卡面（surface），不是 dangerSoft
      'danger / surface': (d.danger, d.surface, 4.5),
      'danger / surface2': (d.danger, d.surface2, 4.5),
      'onAccent / accent': (d.onAccent, d.accent, 4.5),
      'onAccent / accentStrong': (d.onAccent, d.accentStrong, 4.5),
      'lilac / lilacSoft': (d.lilac, d.lilacSoft, 4.5),
      'deckCoverInk / deckCover': (d.deckCoverInk, d.deckCover, 7),
      'deckCoverAccent / deckCover': (d.deckCoverAccent, d.deckCover, 4.5),
    };
    pairs.forEach((String label, (Color, Color, double) pair) {
      final double ratio = contrast(pair.$1, pair.$2);
      expect(ratio, greaterThanOrEqualTo(pair.$3), reason: '$label = ${ratio.toStringAsFixed(2)}');
    });
  });

  test('过渡里主按钮底色不许变成纯黑 / 纯白，字色对比度 ≥ 4.5', () {
    double channel(double c) {
      final double v = c / 255;
      return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    double lum(Color c) =>
        0.2126 * channel(c.r * 255) + 0.7152 * channel(c.g * 255) + 0.0722 * channel(c.b * 255);

    double ratio(Color fg, Color bg) {
      final double a = lum(fg);
      final double b = lum(bg);
      return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
    }

    final double lLight = lum(T0Palette.light.accentFill);
    final double lDark = lum(T0Palette.dark.accentFill);
    for (int i = 0; i <= 100; i++) {
      final double t = i / 100;
      final T0Palette p = T0Palette.light.lerp(T0Palette.dark, t);
      final double l = lum(p.accentFill);
      // accentFill 走「面」的插值：只在两端的绿之间移动，不会碰到纯黑 / 纯白
      expect(l, greaterThanOrEqualTo(math.min(lLight, lDark) - 0.002));
      expect(l, lessThanOrEqualTo(math.max(lLight, lDark) + 0.002));
      // 字色按底色亮度选，过渡全程都要过 4.5
      final double r = ratio(T0Palette.onFill(p.accentFill), p.accentFill);
      expect(r, greaterThanOrEqualTo(4.5),
          reason: 't=${t.toStringAsFixed(2)} onFill/accentFill = ${r.toStringAsFixed(2)}');
      final double rh = ratio(T0Palette.onFill(p.accentStrongFill), p.accentStrongFill);
      expect(rh, greaterThanOrEqualTo(4.5),
          reason: 't=${t.toStringAsFixed(2)} onFill/accentStrongFill = ${rh.toStringAsFixed(2)}');
    }
    // 进度环弧：过渡中段底色压到中灰时，弧对卡面仍要 ≥3:1
    for (int i = 0; i <= 100; i++) {
      final double t = i / 100;
      final T0Palette p = T0Palette.light.lerp(T0Palette.dark, t);
      final Color arc = T0Palette.readableFill(p.accentFill, p.canvas, min: 3.0);
      final double rArc = T0Palette.ratio(arc, p.canvas);
      expect(rArc, greaterThanOrEqualTo(3.0),
          reason: 't=${t.toStringAsFixed(2)} 弧/卡面 = ${rArc.toStringAsFixed(2)}');
      // 12px 次要文字（muted）在过渡中段也要 ≥4.5，且明显比 ink 暗
      final double rMuted = T0Palette.ratio(p.muted, p.surface);
      expect(rMuted, greaterThanOrEqualTo(4.5),
          reason: 't=${t.toStringAsFixed(2)} muted/surface = ${rMuted.toStringAsFixed(2)}');
      // 层级：中灰段 muted 用 #E8E4EE（比纯白的 ink 暗一档）；
      // 底色太浅、#E8E4EE 撑不到 4.5 时才会退回纯白，那时两者亮度会重合（物理上限，文档里写明）
      if (T0Palette.ratio(const Color(0xFFE8E4EE), p.surface) >= 4.5) {
        expect(lum(p.muted), lessThanOrEqualTo(lum(p.ink) + 0.001),
            reason: 't=${t.toStringAsFixed(2)} muted 不该比 ink 更亮');
      }
    }

    // 静态两套主题的外观不变：浅色白字、深色深字
    expect(T0Palette.onFill(T0Palette.light.accentFill), T0Palette.light.onAccent);
    expect(T0Palette.onFill(T0Palette.dark.accentFill), T0Palette.dark.onAccent);
  });

  test('T0Palette.lerp 逐字段给出中间态（AnimatedTheme 的前提）', () {
    final T0Palette half = T0Palette.light.lerp(T0Palette.dark, 0.5);
    expect(half.bg, isNot(T0Palette.light.bg));
    expect(half.bg, isNot(T0Palette.dark.bg));
    // 起点 / 终点必须精确等于两端，不能有半像素偏差
    expect(T0Palette.light.lerp(T0Palette.dark, 0).bg, T0Palette.light.bg);
    expect(T0Palette.light.lerp(T0Palette.dark, 1).bg, T0Palette.dark.bg);
    // 30 个字段都要参与插值：结构里任何一个漏了，切主题时它就会跳色
    expect(half.grid, isNot(T0Palette.light.grid));
    expect(half.shadow, isNot(T0Palette.light.shadow));
    // deck（画布 / 幻灯片）两套主题相同，插值后必须原样不动
    expect(half.deckPaper, T0Palette.light.deckPaper);
    expect(half.deckCover, T0Palette.light.deckCover);
  });

  test('过渡全程：任一时刻文字/底的对比度都不低于 3:1', () {
    double channel(double c) {
      final double v = c / 255;
      return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    double lum(Color c) =>
        0.2126 * channel(c.r * 255) + 0.7152 * channel(c.g * 255) + 0.0722 * channel(c.b * 255);

    double ratio(Color fg, Color bg) {
      final double a = lum(fg);
      final double b = lum(bg);
      return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
    }

    // 只要 t 落在这三条之间就开始量：过渡中点前后的每一帧都要过 3:1
    for (int i = 0; i <= 200; i++) {
      final double t = i / 200;
      final T0Palette p = T0Palette.light.lerp(T0Palette.dark, t);
      final Map<String, (Color, Color)> pairs = <String, (Color, Color)>{
        'ink / bg': (p.ink, p.bg),
        'ink / surface': (p.ink, p.surface),
        'ink / surface2': (p.ink, p.surface2),
        'ink2 / bg': (p.ink2, p.bg),
        'ink2 / surface': (p.ink2, p.surface),
        'ink2 / surface2': (p.ink2, p.surface2),
        'muted / bg': (p.muted, p.bg),
        'accent / bg': (p.accent, p.bg),
        'accent / surface': (p.accent, p.surface),
        'accentStrong / accentSoft': (p.accentStrong, p.accentSoft),
        // 主按钮 / 步骤点的字底配对：走 onFill + *Fill（onAccent 与 accent 在过渡里会一起被兜底成同一极值）
        'onFill / accentFill': (T0Palette.onFill(p.accentFill), p.accentFill),
        'onFill / accentStrongFill': (T0Palette.onFill(p.accentStrongFill), p.accentStrongFill),
        'lilac / lilacSoft': (p.lilac, p.lilacSoft),
        'ok / accentSoft': (p.ok, p.accentSoft),
        'warn / warnSoft': (p.warn, p.warnSoft),
        'danger / dangerSoft': (p.danger, p.dangerSoft),
      };
      pairs.forEach((String label, (Color, Color) pair) {
        final double r = ratio(pair.$1, pair.$2);
        expect(r, greaterThanOrEqualTo(3.0),
            reason: 't=${t.toStringAsFixed(3)} $label = ${r.toStringAsFixed(2)}');
      });
      // 步骤条用的 stepMuted 也要在过渡里站得住（08 帧同位置要求 ≥4:1，这里守 3:1 底线）
      expect(ratio(p.stepMuted, p.bg), greaterThanOrEqualTo(3.0),
          reason: 't=${t.toStringAsFixed(3)} stepMuted');
    }
  });

  test('步骤条：浅色 / 深色 12px 步骤名都 ≥ 4.5:1', () {
    double channel(double c) {
      final double v = c / 255;
      return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    double lum(Color c) =>
        0.2126 * channel(c.r * 255) + 0.7152 * channel(c.g * 255) + 0.0722 * channel(c.b * 255);

    double ratio(Color fg, Color bg) {
      final double a = lum(fg);
      final double b = lum(bg);
      return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
    }

    for (final T0Palette p in <T0Palette>[T0Palette.light, T0Palette.dark]) {
      expect(ratio(p.stepMuted, p.bg), greaterThanOrEqualTo(4.5),
          reason: 'stepMuted / bg = ${ratio(p.stepMuted, p.bg).toStringAsFixed(2)}');
    }

    // 过渡中点（AnimatedTheme 在 210ms 传给 lerp 的值 = easeInOutCubic(0.5) = 0.5）
    final T0Palette mid = T0Palette.light.lerp(T0Palette.dark, 0.5);
    expect(ratio(mid.ink, mid.bg), greaterThanOrEqualTo(4.5),
        reason: '210ms 正文 ink / bg = ${ratio(mid.ink, mid.bg).toStringAsFixed(2)}');
    expect(ratio(mid.stepMuted, mid.bg), greaterThanOrEqualTo(4.0),
        reason: '210ms 步骤条 = ${ratio(mid.stepMuted, mid.bg).toStringAsFixed(2)}');
  });

  test('mutedOnTint：彩色底上的 12px 小标两套主题都 ≥ 4.5:1', () {
    double channel(double c) {
      final double v = c / 255;
      return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    double lum(Color c) =>
        0.2126 * channel(c.r * 255) + 0.7152 * channel(c.g * 255) + 0.0722 * channel(c.b * 255);

    double ratio(Color fg, Color bg) {
      final double a = lum(fg);
      final double b = lum(bg);
      return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
    }

    for (final T0Palette p in <T0Palette>[T0Palette.light, T0Palette.dark]) {
      // 02 未选中 tab 压 tab 轨道（canvas）；文件卡 meta 压 accentSoft
      expect(ratio(p.mutedOnTint, p.canvas), greaterThanOrEqualTo(4.5),
          reason: 'mutedOnTint / canvas = ${ratio(p.mutedOnTint, p.canvas).toStringAsFixed(2)}');
      expect(ratio(p.mutedOnTint, p.accentSoft), greaterThanOrEqualTo(4.5),
          reason: 'mutedOnTint / accentSoft = ${ratio(p.mutedOnTint, p.accentSoft).toStringAsFixed(2)}');
      // 只加深了这两处：全局 muted / stepMuted 一个字没动
      expect(p.mutedOnTint, Color.lerp(p.muted, p.ink, 0.15));
    }
    // 白天实测值：轨道 4.72 / 文件卡 4.97（改前 3.95 / 4.16）
    final Color m = T0Palette.light.mutedOnTint;
    expect((m.r * 255).round(), 0x5C);
    expect((m.g * 255).round(), 0x67);
    expect((m.b * 255).round(), 0x63);
    expect(ratio(T0Palette.light.mutedOnTint, T0Palette.light.canvas), greaterThanOrEqualTo(4.6));
    expect(ratio(T0Palette.light.mutedOnTint, T0Palette.light.accentSoft), greaterThanOrEqualTo(4.6));
  });

  testWidgets('01 工作台右卡：产品流程卡内容垂直居中（上下留白差 ≤ 8px）', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const T0App());
    await tester.pumpAndSettle();

    final Rect card = tester.getRect(
      find.ancestor(of: find.text('三步'), matching: find.byType(PaperCard)),
    );
    final double top = tester.getRect(find.text('产品流程')).top - card.top;
    final double bottom =
        card.bottom - tester.getRect(find.text('确认后保存版本，未完成内容在交付前提醒。')).bottom;
    // v8 实测是上 26 / 下 94；居中后两者相等（差 ≤8）
    expect((bottom - top).abs(), lessThanOrEqualTo(8),
        reason: '上 ${top.toStringAsFixed(1)} / 下 ${bottom.toStringAsFixed(1)}');
    // 卡高由左列决定，居中不许把卡撑高
    final Rect entry = tester.getRect(find.text('从一份材料开始'));
    expect(card.bottom, greaterThan(entry.top));
  });

  testWidgets('工作台环旁补口径「已确认 3 个模块」：环里的 3/5 不重复写第二遍', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const T0App());
    await tester.pumpAndSettle();

    // 环里的数保持 3/5（= 已确认数），旁边一句只说口径、不再重复分数
    expect(find.text('3/5'), findsOneWidget);
    final Text caption = tester.widget<Text>(find.text('已确认 3 个模块'));
    expect(caption.style!.fontSize, 11);
    expect(caption.style!.color, T0Palette.light.ink2Strong);
    expect(find.text('已确认 3/5'), findsNothing);
  });

  testWidgets('05 纸张卡左上中文小标：屏幕上 ≥10px（放大后逐字可认）', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    T0Store.instance.applyEdit(1);
    await tester.pumpWidget(const T0App(initialRoute: '/workspace'));
    await tester.pumpAndSettle();

    final Text label = tester.widget<Text>(find.text('结构压缩版'));
    // 纸卡按 720×405 画、FittedBox 缩到当前缩放（默认 0.71）：
    // 屏幕像素 = fontSize × zoom。0.82 → 0.71 后 13px 只剩 9.2px，
    // 所以字号提到 15px，屏幕上仍是 10.65px。
    final double onScreen = label.style!.fontSize! * T0Store.instance.zoom.value;
    expect(onScreen, greaterThanOrEqualTo(10.0), reason: '屏幕字号 ${onScreen.toStringAsFixed(2)}px');
    expect(label.style!.fontSize, lessThanOrEqualTo(16));
  });

  testWidgets('05/06 左卡：两个按钮贴底（底部空隙 ≤ 30px）', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const T0App(initialRoute: '/delivery'));
    await tester.pumpAndSettle();

    // 左侧总览卡是第一个 PaperCard（环图 + 两按钮）
    final Rect card = tester.getRect(find.byType(PaperCard).first);
    final Rect button = tester.getRect(
      find.widgetWithText(SecondaryButton, '导出当前范围'),
    );
    // 基线：卡底 padding 22px，按钮底边应该贴到卡底附近
    expect(card.bottom - button.bottom, lessThanOrEqualTo(30),
        reason: '底部空隙 ${(card.bottom - button.bottom).toStringAsFixed(1)}px');

    // 留白分摊：说明段到按钮之间不超过 100px（不许把 184px 全堆在一处）
    final Rect note = tester.getRect(find.text('“结论总结”仍在等材料。'));
    final Rect first = tester.getRect(
      find.widgetWithText(PrimaryButton, '返回补全模块'),
    );
    expect(first.top - note.bottom, lessThanOrEqualTo(100),
        reason: '说明段到按钮 ${(first.top - note.bottom).toStringAsFixed(1)}px');
  });
}
