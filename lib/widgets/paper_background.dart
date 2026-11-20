import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/tokens.dart';

/// 底色 + 极淡网格。
///
/// 颜色从 [T0Palette] 取：切主题时父级 AnimatedTheme 每帧给出中间态调色板，
/// 这里重建 painter 并靠 shouldRepaint 比较颜色触发重绘，网格才会跟着渐变
/// （否则动画期间不重绘，看起来就是瞬切）。
class PaperBackground extends StatelessWidget {
  const PaperBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    return CustomPaint(
      painter: _PaperGridPainter(bg: pal.bg, grid: pal.grid),
      child: child,
    );
  }
}

class _PaperGridPainter extends CustomPainter {
  const _PaperGridPainter({required this.bg, required this.grid});

  final Color bg;

  /// 已带透明度的网格色：白天是墨色 5%，黑夜是 lineSoft（更暗、更沉）
  final Color grid;

  static const double _cell = 44;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    final Paint gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += _cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += _cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperGridPainter oldDelegate) =>
      oldDelegate.bg != bg || oldDelegate.grid != grid;
}

/// 虚线框：底部「从一份材料开始」入口、材料拖入区都用它。
class DashedBox extends StatelessWidget {
  const DashedBox({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = T0.cardRadius,
    this.color,
    this.fill,
    this.dash = 7,
    this.gap = 5,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// 不传就跟随主题的 lineStrong
  final Color? color;
  final Color? fill;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        radius: radius,
        color: color ?? context.pal.lineStrong,
        fill: fill,
        dash: dash,
        gap: gap,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.radius,
    required this.color,
    required this.fill,
    required this.dash,
    required this.gap,
  });

  final double radius;
  final Color color;
  final Color? fill;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    // 描边居中在路径上，直接取 Offset.zero & size 会让虚线比实线卡边框左/上多出 1px；
    // 缩进 0.5px 后虚线外沿与卡边框同一条 x（审图 P2-② 的「左边界对齐」）
    final RRect rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Radius.circular(radius),
    );
    if (fill != null) {
      canvas.drawRRect(rect, Paint()..color = fill!);
    }

    final Path path = Path()..addRRect(rect);
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = (distance + dash).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, next), stroke);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.fill != fill ||
      oldDelegate.radius != radius;
}
