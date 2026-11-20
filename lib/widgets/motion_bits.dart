import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';

/// 弹层路由：scale + fade 进入（[T0Motion.dialogIn]），退出 [T0Motion.dialogOut]。
///
/// 用 `PageRouteBuilder(opaque: false)` 而不是 `showGeneralDialog`：
/// 后者的 exit 时长不可控（固定跟 enter 一样），而这一轮要的是 220 进 / 160 退。
Route<T> t0DialogRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
  String barrierLabel = '关闭',
  double scaleFrom = 0.96,
  Alignment alignment = Alignment.center,
}) {
  return PageRouteBuilder<T>(
    opaque: false,
    barrierDismissible: dismissible,
    barrierLabel: barrierLabel,
    barrierColor: context.pal.scrim.withValues(alpha: 0.4),
    transitionDuration: T0Motion.scaled(T0Motion.dialogIn),
    reverseTransitionDuration: T0Motion.scaled(T0Motion.dialogOut),
    pageBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondary,
    ) => builder(context),
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondary,
      Widget child,
    ) {
      // 主题渐变中 / 减弱动效：直接落位
      if (T0Motion.dur(context, T0Motion.dialogIn) == Duration.zero) return child;
      final CurvedAnimation curved = CurvedAnimation(
        parent: animation,
        curve: T0Motion.enter,
        reverseCurve: T0Motion.exit,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: scaleFrom, end: 1).animate(curved),
          alignment: alignment,
          child: child,
        ),
      );
    },
  );
}

/// 入场动画：fade + 位移（可选缩放），一次性播放，支持错峰延时。
///
/// 只重建 [AnimatedBuilder] 里那一层 `Opacity / Transform`，[child] 整棵子树
/// 通过 `AnimatedBuilder.child` 传进去 —— 入场期间卡片的 build 不会每帧重跑。
class T0Enter extends StatefulWidget {
  const T0Enter({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration,
    this.offset = const Offset(0, 8),
    this.scaleFrom,
    this.curve = T0Motion.enter,
    this.play = true,
  });

  final Widget child;

  /// 错峰延时（`i * 45ms` 这类）
  final Duration delay;

  /// 不传用 [T0Motion.base]
  final Duration? duration;

  /// 起始位移，[Offset.zero] 就是纯淡入
  final Offset offset;

  /// 起始缩放（不传就不缩放）
  final double? scaleFrom;

  final Curve curve;
  final bool play;

  @override
  State<T0Enter> createState() => _T0EnterState();
}

class _T0EnterState extends State<T0Enter> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration ?? T0Motion.base,
  );
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Duration d = T0Motion.dur(context, widget.duration ?? T0Motion.base);
    if (_c.duration != d) _c.duration = d;
    if (!_started) {
      _started = true;
      if (!widget.play || d == Duration.zero) {
        // 减弱动效 / 主题渐变中：直接在落位值上，不做动画
        _c.value = 1;
      } else if (widget.delay == Duration.zero) {
        _c.forward();
      } else {
        _timer = Timer(widget.delay, () {
          if (mounted) _c.forward();
        });
      }
    } else if (d == Duration.zero && _c.value < 1) {
      // 动画播到一半时用户切主题：让路，直接落位
      _timer?.cancel();
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double t = widget.curve.transform(_c.value.clamp(0.0, 1.0));
        final Widget faded = Opacity(opacity: t, child: child);
        final Widget shifted = Transform.translate(
          offset: widget.offset * (1 - t),
          child: faded,
        );
        final double? from = widget.scaleFrom;
        return IgnorePointer(
          ignoring: t <= 0,
          child: from == null
              ? shifted
              : Transform.scale(scale: from + (1 - from) * t, child: shifted),
        );
      },
    );
  }
}

/// 勾选描线：用 [CustomPainter] 把一条对勾按 [progress] 0→1 描出来（不贴图）。
class T0CheckStroke extends StatelessWidget {
  const T0CheckStroke({
    super.key,
    required this.progress,
    required this.color,
    this.strokeWidth = 2,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CheckPainter(
        progress: progress.clamp(0.0, 1.0),
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final Path path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.71)
      ..lineTo(size.width * 0.79, size.height * 0.31);
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final PathMetric metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// 24px 勾选徽章：淡底圆 + 300ms 描线。交付检查列表逐条打勾用它。
class T0CheckBadge extends StatefulWidget {
  const T0CheckBadge({
    super.key,
    this.size = 24,
    this.delay = Duration.zero,
    this.done = true,
  });

  final double size;

  /// 逐条打勾的错峰延时
  final Duration delay;

  /// false：勾画完的静止态（例如已经确认过的旧项）
  final bool done;

  @override
  State<T0CheckBadge> createState() => _T0CheckBadgeState();
}

class _T0CheckBadgeState extends State<T0CheckBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: T0Motion.checkStroke,
  );
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Duration d = T0Motion.dur(context, T0Motion.checkStroke);
    if (_c.duration != d) _c.duration = d;
    if (!_started) {
      _started = true;
      if (!widget.done || d == Duration.zero) {
        _c.value = 1;
      } else if (widget.delay == Duration.zero) {
        _c.forward();
      } else {
        _timer = Timer(widget.delay, () {
          if (mounted) _c.forward();
        });
      }
    } else if (d == Duration.zero && _c.value < 1) {
      _timer?.cancel();
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: pal.accentSoft),
      child: Padding(
        padding: EdgeInsets.all(widget.size * 0.2),
        child: AnimatedBuilder(
          animation: _c,
          builder: (BuildContext context, _) => T0CheckStroke(
            progress: _c.value,
            color: pal.accent,
            strokeWidth: math.max(1.6, widget.size * 0.1),
          ),
        ),
      ),
    );
  }
}

/// 骨架 shimmer：一条 1.2s 循环的斜向高光带横扫 [child] 区域。
///
/// 只在 [AnimatedBuilder] 里重画一排像素，child（骨架块）不重建。
class T0ShimmerBand extends StatefulWidget {
  const T0ShimmerBand({
    super.key,
    required this.child,
    this.duration = T0Motion.shimmer,
  });

  final Widget child;
  final Duration duration;

  @override
  State<T0ShimmerBand> createState() => _T0ShimmerBandState();
}

class _T0ShimmerBandState extends State<T0ShimmerBand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_running) return;
    _running = true;
    // 减弱动效 / 主题渐变中 / 测试环境：不循环（静止骨架，不闪）
    final Duration d = T0Motion.dur(context, widget.duration);
    if (d == Duration.zero || !T0Loops.enabled) {
      _c.value = 0;
    } else {
      _c.duration = d;
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color highlight = context.pal.surface;
    return ClipRect(
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (BuildContext context, Widget? child) => Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            ?child,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BandPainter(progress: _c.value, color: highlight),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BandPainter extends CustomPainter {
  const _BandPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double skew = size.height * 0.6;
    final double x = (-1 + 3 * progress) * size.width;
    const double band = 150;
    final Path path = Path()
      ..moveTo(x, size.height)
      ..lineTo(x + band, size.height)
      ..lineTo(x + band + skew, 0)
      ..lineTo(x + skew, 0)
      ..close();
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.62),
          color.withValues(alpha: 0),
        ],
        stops: const <double>[0, 0.5, 1],
      ).createShader(path.getBounds());
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BandPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
