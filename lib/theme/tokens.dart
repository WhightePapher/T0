import 'package:flutter/material.dart';

import 'palette.dart';

/// 设计令牌：字号、间距、圆角、字体回退链。
///
/// 约定：颜色不在这里 —— 颜色一律走 `context.pal`（[T0Palette]），
/// 这样切主题时才能被 AnimatedTheme 插值出中间态。页面里禁止写裸十六进制。
class T0 {
  const T0._();

  // ---------------------------------------------------------------- 间距
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s64 = 64;

  /// 顶栏圆形图标按钮（主题 / 加号 / 菜单）统一边长：别再各写各的 34 / 36
  static const double iconButtonSize = 36;

  // ---------------------------------------------------------------- 圆角
  static const double cardRadius = 18;
  static const double pillRadius = 999;
  static const double fieldRadius = 14;
  static const double innerRadius = 12;

  // ---------------------------------------------------------------- 字体
  // 家族名是打包进来的字体（见 pubspec.yaml 的 fonts: 与 tool/prepare_fonts.py）。
  // Flutter web（CanvasKit）读不到系统字体，所以这里不能再写 MiSans / 思源宋体这类
  // 系统名；fallback 只在同批打包字体之间兜底，永远不会去 CDN 取字。
  static const String sansFamily = 'T0Sans';
  static const List<String> sansFallback = <String>['T0Serif'];
  static const String serifFamily = 'T0Serif';
  static const List<String> serifFallback = <String>['T0Sans'];
  static const String monoFamily = 'T0Mono';
  static const List<String> monoFallback = <String>['T0Sans', 'T0Serif'];

  // ---------------------------------------------------------------- 版式
  static const double maxContentWidth = 1360;

  /// display 64/72 衬线 700，行高 1.05，字间距 -1.5
  static TextStyle display(double m, T0Palette p) => TextStyle(
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallback,
    fontSize: 64 * m,
    height: 1.05,
    letterSpacing: -1.5 * m,
    fontWeight: FontWeight.w700,
    color: p.ink,
  );

  /// h1 34/42
  static TextStyle h1(double m, T0Palette p) => TextStyle(
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallback,
    fontSize: 34 * m,
    height: 42 / 34,
    letterSpacing: -0.4 * m,
    fontWeight: FontWeight.w700,
    color: p.ink,
  );

  /// h2 22/30
  static TextStyle h2(double m, T0Palette p) => TextStyle(
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallback,
    fontSize: 22 * m,
    height: 30 / 22,
    letterSpacing: -0.2 * m,
    fontWeight: FontWeight.w700,
    color: p.ink,
  );

  /// h3 16/24 无衬线 600
  static TextStyle h3(double m, T0Palette p) => TextStyle(
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallback,
    fontSize: 16 * m,
    height: 24 / 16,
    letterSpacing: 0,
    fontWeight: FontWeight.w600,
    color: p.ink,
  );

  /// body 15/26
  static TextStyle body(double m, T0Palette p) => TextStyle(
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallback,
    fontSize: 15 * m,
    height: 26 / 15,
    fontWeight: FontWeight.w400,
    color: p.ink,
  );

  /// meta 12/18，字色 ink2（白天与旧 muted 同值，黑夜里提亮到可读）
  static TextStyle meta(double m, T0Palette p) => TextStyle(
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallback,
    fontSize: 12 * m,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
    color: p.ink2,
  );

  /// eyebrow 11/16，字间距 3，全大写
  static TextStyle eyebrow(double m, T0Palette p) => TextStyle(
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallback,
    fontSize: 11 * m,
    height: 16 / 11,
    letterSpacing: 3 * m,
    fontWeight: FontWeight.w600,
    color: p.muted,
  );

  /// 小标签 11/16，字间距 1.2
  static TextStyle label(double m, T0Palette p) => TextStyle(
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallback,
    fontSize: 11 * m,
    height: 16 / 11,
    letterSpacing: 1.2 * m,
    fontWeight: FontWeight.w600,
    color: p.muted,
  );

  /// 数字 / 版本
  static TextStyle mono(double m, T0Palette p) => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontSize: 12 * m,
    height: 18 / 12,
    letterSpacing: 0.6 * m,
    fontWeight: FontWeight.w500,
    color: p.muted,
  );
}

/// 响应式度量：断点、栏距、字号缩放。
class T0Metrics extends InheritedWidget {
  const T0Metrics({super.key, required this.width, required super.child});

  final double width;

  bool get isDesktop => width >= 1100;
  bool get isNarrow => width >= 700 && width < 1100;
  bool get isMobile => width < 700;

  /// 标题缩放：窄屏等比缩，但保底可用
  double get titleScale => isDesktop ? 1 : (isNarrow ? 0.74 : 0.52);

  /// 正文字号缩放，移动端不做过小
  double get bodyScale => isDesktop ? 1 : (isNarrow ? 0.95 : 0.9);

  /// 左右留白
  double get gutter => isDesktop ? 96 : (isNarrow ? 40 : 18);

  double get maxWidth => T0.maxContentWidth;

  @override
  bool updateShouldNotify(T0Metrics oldWidget) => oldWidget.width != width;

  static T0Metrics of(BuildContext context) {
    final T0Metrics? metrics = context
        .dependOnInheritedWidgetOfExactType<T0Metrics>();
    assert(metrics != null, '页面必须包在 AppShell 里才能读到 T0Metrics');
    return metrics!;
  }
}

/// 表格数字：进度环中心、交付页百分比这类会 count-up 的数字用它，
/// 字宽固定，数字从 3 数到 5 时不会把后面的百分号推来推去。
const List<FontFeature> kT0TabularFigures = <FontFeature>[FontFeature.tabularFigures()];

/// 滚动统一入口（B7）：桌面用 Clamping（不拖出回弹），窄屏 / 移动用 Bouncing。
ScrollPhysics t0ScrollPhysics(BuildContext context) =>
    context.metrics.isDesktop ? const ClampingScrollPhysics() : const BouncingScrollPhysics();

/// 语义化文字样式，页面里用 `context.tH1` 这种写法。
/// 字色都从当前（动画中间态的）[T0Palette] 取。
extension T0TypeContext on BuildContext {
  T0Metrics get metrics => T0Metrics.of(this);

  T0Palette get tPalette => T0Palette.of(this);

  TextStyle get tDisplay => T0.display(metrics.titleScale, tPalette);
  TextStyle get tH1 => T0.h1(metrics.titleScale, tPalette);
  TextStyle get tH2 => T0.h2(metrics.titleScale, tPalette);
  TextStyle get tH3 => T0.h3(metrics.bodyScale, tPalette);
  TextStyle get tBody => T0.body(metrics.bodyScale, tPalette);
  TextStyle get tMeta => T0.meta(metrics.bodyScale, tPalette);
  TextStyle get tEyebrow => T0.eyebrow(metrics.bodyScale, tPalette);
  TextStyle get tLabel => T0.label(metrics.bodyScale, tPalette);
  TextStyle get tMono => T0.mono(metrics.bodyScale, tPalette);

  double get s => metrics.bodyScale;
}
