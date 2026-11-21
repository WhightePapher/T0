import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'focus_ring.dart';

/// 描边胶囊次要按钮（上一步、新增章节、导出当前范围…）。
class SecondaryButton extends StatefulWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.dense = false,
    this.tone,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool dense;

  /// 不传就用主题主文字色
  final Color? tone;

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    final bool enabled = widget.onPressed != null;
    final Color tone = widget.tone ?? pal.ink;
    final Color borderColor = !enabled
        ? pal.line
        : _hover
        ? pal.lineStrong
        : pal.line;
    final Color background = _down
        ? pal.canvas
        : _hover
        ? pal.bg
        : pal.surface;

    final Widget button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                widget.onPressed!.call();
              }
            : null,
        child: AnimatedScale(
          // 按压反馈：0.985 / 90ms instant（缩放不占布局）
          scale: _down ? 0.985 : 1,
          duration: T0Motion.dur(context, T0Motion.instant),
          curve: T0Motion.standard,
          child: AnimatedContainer(
            duration: T0Motion.dur(context, T0Motion.fast),
            curve: Curves.easeOut,
            // hover 抬升 1px（B2），与主按钮同一套几何
            transform: Matrix4.translationValues(0, _hover && enabled ? -1 : 0, 0),
            width: widget.expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(
              horizontal: widget.dense ? 14 : 20,
              vertical: widget.dense ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(T0.pillRadius),
              border: Border.all(color: borderColor),
              // hover 时补一层和主按钮同源的阴影（B1/B2）
              boxShadow: _hover && enabled ? pal.floatShadowHover : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (widget.icon != null) ...<Widget>[
                  Icon(widget.icon, size: 15, color: enabled ? tone : pal.muted),
                  const SizedBox(width: 7),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tBody.copyWith(
                      color: enabled ? tone : pal.muted,
                      fontWeight: FontWeight.w500,
                      fontSize: 13 * context.s,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return T0FocusRing(
      radius: T0.pillRadius,
      enabled: enabled,
      onActivate: widget.onPressed,
      child: button,
    );
  }
}

/// 纯文字幽灵按钮：重新生成、改为粘贴文本…
class GhostButton extends StatefulWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;

  /// 不传就用主题 ink2
  final Color? color;

  @override
  State<GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<GhostButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    final bool enabled = widget.onPressed != null;
    final Widget button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                widget.onPressed!.call();
              }
            : null,
        child: AnimatedScale(
          // 按压反馈：0.985 / 90ms instant（缩放不占布局，文字按钮命中区不变）
          scale: _down ? 0.985 : 1,
          duration: T0Motion.dur(context, T0Motion.instant),
          curve: T0Motion.standard,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              widget.label,
              style: context.tBody.copyWith(
                fontSize: 13 * context.s,
                color: _hover ? pal.ink : (widget.color ?? pal.ink2),
                decoration: _hover ? TextDecoration.underline : TextDecoration.none,
                decorationColor: pal.lineStrong,
              ),
            ),
          ),
        ),
      ),
    );
    return T0FocusRing(
      radius: T0.innerRadius,
      enabled: enabled,
      onActivate: widget.onPressed,
      child: button,
    );
  }
}
