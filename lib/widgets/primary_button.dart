import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';

/// 胶囊主按钮，自己做 hover / pressed / disabled 三态。
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.arrow = false,
    this.expand = false,
    this.dense = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool arrow;
  final bool expand;
  final bool dense;
  final IconData? icon;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    final bool enabled = widget.onPressed != null;
    // 底色走 accentFill / accentStrongFill：它们是「面」的插值，
    // 不会被过渡兜底收成纯黑 / 纯白（见 palette 里 accentFill 的注释）
    final Color background = !enabled
        ? pal.line
        : _down || _hover
        ? pal.accentStrongFill
        : pal.accentFill;
    // 字色按底色亮度算：过渡里底色是连续变亮的，硬切主题侧会出现
    // 白字压浅绿 2.4:1 / 黑字压深绿 3.7:1，两种都不达标
    final Color foreground = enabled ? T0Palette.onFill(background) : pal.muted;

    return MouseRegion(
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
          // 按压反馈：0.985 / 90ms instant。缩放不占布局，按钮命中区不变。
          scale: _down ? 0.985 : 1,
          duration: T0Motion.dur(context, T0Motion.instant),
          curve: T0Motion.standard,
          child: AnimatedContainer(
            duration: T0Motion.dur(context, T0Motion.fast),
            curve: Curves.easeOut,
            width: widget.expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(
              horizontal: widget.dense ? 18 : 26,
              vertical: widget.dense ? 10 : 15,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(T0.pillRadius),
              boxShadow: enabled && _hover ? pal.floatShadow : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (widget.icon != null) ...<Widget>[
                  Icon(widget.icon, size: 16, color: foreground),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tBody.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                      fontSize: 15 * context.s,
                    ),
                  ),
                ),
                if (widget.arrow) ...<Widget>[
                  const SizedBox(width: 10),
                  Icon(Icons.arrow_right_alt, size: 20, color: foreground),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
