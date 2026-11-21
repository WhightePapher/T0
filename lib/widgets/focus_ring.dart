import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/palette.dart';

/// 键盘焦点环（B4）：2px、颜色取 `deckAccent`、画在控件外侧 2px。
///
/// 为什么不用 Material 自带的 focusColor：全项目的可交互元素都是自绘
/// `MouseRegion + GestureDetector`，没有 InkWell 的焦点层，键盘 Tab 过来
/// 只剩浏览器/引擎默认的虚线（CanvasKit 上根本没有），所以这一层必须自己画。
///
/// 焦点环是 `foregroundPainter`：不占布局、不改 padding / 圆角，
/// 有焦点才画（`visible` 为 false 时 paint 直接 return）。
class T0FocusRing extends StatefulWidget {
  const T0FocusRing({
    super.key,
    required this.child,
    this.radius = 18,
    this.onActivate,
    this.focusNode,
    this.enabled = true,
    this.ringColor,
  });

  final Widget child;

  /// 控件本身的圆角（焦点环按它 + offset 画）
  final double radius;

  /// 键盘 Enter / Space 触发（和鼠标点击同一条回调）
  final VoidCallback? onActivate;

  final FocusNode? focusNode;
  final bool enabled;

  /// 不传就用 `deckAccent`
  final Color? ringColor;

  @override
  State<T0FocusRing> createState() => _T0FocusRingState();
}

class _T0FocusRingState extends State<T0FocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final Color color = widget.ringColor ?? context.pal.deckAccent;
    return Focus(
      focusNode: widget.focusNode,
      canRequestFocus: widget.enabled,
      onFocusChange: (bool value) {
        if (_focused != value) setState(() => _focused = value);
      },
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is! KeyDownEvent || widget.onActivate == null) {
          return KeyEventResult.ignored;
        }
        final LogicalKeyboardKey key = event.logicalKey;
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space) {
          widget.onActivate!.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: CustomPaint(
        foregroundPainter: T0FocusRingPainter(
          visible: _focused,
          color: color,
          radius: widget.radius,
        ),
        child: widget.child,
      ),
    );
  }
}

/// 焦点环画笔：2px 描边，按控件圆角 + 2px 外扩画一圈。
class T0FocusRingPainter extends CustomPainter {
  const T0FocusRingPainter({
    required this.visible,
    required this.color,
    required this.radius,
    this.strokeWidth = 2,
    this.offset = 2,
  });

  final bool visible;
  final Color color;
  final double radius;
  final double strokeWidth;

  /// 环与控件之间的空隙（设计口径：offset 2）
  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible || size.isEmpty) return;
    final Rect rect = (Offset.zero & size).inflate(offset - strokeWidth / 2);
    final RRect ring = RRect.fromRectAndRadius(
      rect,
      Radius.circular(radius + offset),
    );
    canvas.drawRRect(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant T0FocusRingPainter oldDelegate) =>
      oldDelegate.visible != visible ||
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.offset != offset;
}
