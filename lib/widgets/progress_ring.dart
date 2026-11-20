import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';

/// 环形进度（CustomPaint）。值来自「已确认模块数 / 总数」。
///
/// 颜色在 build 里从当前调色板取（不传就是 accent / canvas），
/// 并交给 painter 在 shouldRepaint 里比较 —— 这样主题渐变的每一帧都会重绘。
///
/// 动效（G3 / G8 共用）：首次出现时弧线从 0 扫到目标值 [T0Motion.ring]（600ms
/// standard）；给了 [counter] 的话，环中心数字跟着同一个插值值 count-up（取整），
/// 两者天然同步。重建只发生在 `TweenAnimationBuilder` 的 builder 里 ——
/// CustomPaint 与中心文字，不碰卡片 / 页面。
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 46,
    this.strokeWidth = 4,
    this.color,
    this.track,
    this.child,
    this.counter,
  });

  final double value;
  final double size;
  final double strokeWidth;

  /// 不传就用主题主色
  final Color? color;

  /// 不传就用主题画布色
  final Color? track;
  final Widget? child;

  /// 环中心数字的 count-up：入参是当前插值到的 0..1 进度（取整显示交给调用点）。
  /// 给了它就优先于 [child]。
  final Widget Function(BuildContext context, double value)? counter;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    final Color trackColor = track ?? pal.canvas;
    // 弧线是粗填充：过渡中段底色被压到中灰时，绿弧几乎融进卡面（实测 1.35:1）。
    // 这里按「当前卡片底色」把弧色往黑 / 白里推一档，保证弧对底 ≥3:1；
    // 环里的数字用 ink，对卡面本来就有 9:1 以上，不受影响。
    final Color ringColor = T0Palette.readableFill(
      color ?? pal.accentFill,
      trackColor,
      min: 3.0,
    );
    final double target = value.clamp(0, 1).toDouble();

    Widget content(double v) => SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CustomPaint(
            painter: _RingPainter(
              value: v,
              strokeWidth: strokeWidth,
              color: ringColor,
              track: trackColor,
            ),
          ),
          if (counter != null)
            Center(child: counter!(context, v))
          else if (child != null)
            Center(child: child),
        ],
      ),
    );

    // 时长为 0（主题渐变中 / 减弱动效）时 TweenAnimationBuilder 直接落在终值上，
    // 不会因为换了分支而重播一次 sweep。
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: T0Motion.dur(context, T0Motion.ring),
      curve: T0Motion.standard,
      builder: (BuildContext context, double v, Widget? _) => content(v),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.strokeWidth,
    required this.color,
    required this.track,
  });

  final double value;
  final double strokeWidth;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = (size.shortestSide - strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);

    final Paint trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(size.center(Offset.zero), radius, trackPaint);

    if (value <= 0) return;

    final Paint arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.color != color ||
      oldDelegate.track != track ||
      oldDelegate.strokeWidth != strokeWidth;
}
