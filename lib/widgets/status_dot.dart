import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/mock_data.dart';
import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'motion_bits.dart';

/// 状态色全部走调色板：白天是品牌绿 / 橙 / 红，黑夜里换成深底可读的对应色。
Color statusColor(ModuleStatus status, T0Palette pal) => switch (status) {
  ModuleStatus.done => pal.ok,
  ModuleStatus.review => pal.warn,
  ModuleStatus.missing => pal.danger,
};

Color statusSoftColor(ModuleStatus status, T0Palette pal) => switch (status) {
  ModuleStatus.done => pal.accentSoft,
  ModuleStatus.review => pal.warnSoft,
  ModuleStatus.missing => pal.dangerSoft,
};

/// 三色状态点：已确认（绿实心）/ 待确认（橙）/ 待补充（红）。
///
/// 两条生命感（G6）：
/// * `missing`（待补充）呼吸脉冲 scale 1↔1.15，1.6s 循环 easeInOut ——
///   只有「需要你动手」的那一项在动；
/// * `done` 首次出现时打勾描线 300ms（[T0CheckStroke] 的 CustomPainter），
///   不贴图、不循环；`review` 保持静止。
///
/// 减弱动效（`MediaQuery.disableAnimations`）下两者都停在落位值上。
class StatusDot extends StatefulWidget {
  const StatusDot({super.key, required this.status, this.size = 8, this.ring = false});

  final ModuleStatus status;
  final double size;
  final bool ring;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot> with TickerProviderStateMixin {
  /// missing 的呼吸
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: T0Motion.breathe,
  );

  /// done 的勾选描线（一次性）
  late final AnimationController _check = AnimationController(
    vsync: this,
    duration: T0Motion.checkStroke,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _syncMotion(restartCheck: widget.status == ModuleStatus.done);
    }
  }

  void _syncMotion({bool restartCheck = false}) {
    final Duration breath = T0Motion.dur(context, T0Motion.breathe);
    final bool still = breath == Duration.zero;
    // 呼吸（循环类动画：无动效环境 / 测试环境下降级为静止）
    if (widget.status == ModuleStatus.missing && !still && T0Loops.enabled) {
      if (_breath.duration != breath) _breath.duration = breath;
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    } else {
      _breath.stop();
      _breath.value = 0;
    }
    // 打勾
    final Duration checkDur = T0Motion.dur(context, T0Motion.checkStroke);
    if (_check.duration != checkDur) _check.duration = checkDur;
    if (widget.status == ModuleStatus.done) {
      if (still || checkDur == Duration.zero) {
        _check.value = 1;
      } else if (restartCheck || _check.value == 0) {
        _check.forward(from: 0);
      }
    } else {
      _check.value = 0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _check.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = statusColor(widget.status, context.pal);
    final bool done = widget.status == ModuleStatus.done;
    final bool breathing = widget.status == ModuleStatus.missing;

    Widget dot = Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.ring ? Colors.transparent : color,
        border: widget.ring ? Border.all(color: color, width: 1.4) : null,
      ),
      child: done && !widget.ring
          ? AnimatedBuilder(
              animation: _check,
              builder: (BuildContext context, _) => T0CheckStroke(
                progress: _check.value,
                color: context.pal.surface,
                strokeWidth: math.max(1.2, widget.size * 0.16),
              ),
            )
          : null,
    );

    if (breathing) {
      dot = AnimatedBuilder(
        animation: _breath,
        child: dot,
        builder: (BuildContext context, Widget? child) {
          // 只在绘制层放大，布局尺寸仍是 size
          final double t = Curves.easeInOut.transform(_breath.value);
          return Transform.scale(scale: 1 + 0.15 * t, child: child);
        },
      );
    }
    return dot;
  }
}

/// 状态胶囊：点 + 文案 + 淡底。
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.deliveryWording = false,
    this.dense = false,
  });

  final ModuleStatus status;
  final bool deliveryWording;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    final String label = deliveryWording ? status.deliveryLabel : status.label;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: statusSoftColor(status, pal),
        borderRadius: BorderRadius.circular(T0.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StatusDot(status: status, size: 6),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.tMeta.copyWith(
              color: statusColor(status, pal),
              fontWeight: FontWeight.w600,
              fontSize: 11 * context.s,
            ),
          ),
        ],
      ),
    );
  }
}
