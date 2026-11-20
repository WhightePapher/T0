import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/tokens.dart';

/// eyebrow：一条 34px 细线 + 全大写小字。
class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.text,
    this.color,
    this.lineColor,
  });

  final String text;

  /// 不传就跟随主题 stepMuted / lineStrong
  final Color? color;
  final Color? lineColor;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 34, height: 1, color: lineColor ?? pal.lineStrong),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text.toUpperCase(),
            // 浅色底上 muted 只有 4.40，eyebrow 一律用 stepMuted（白天 4.95 / 黑夜 7.36）
            style: context.tEyebrow.copyWith(color: color ?? pal.stepMuted),
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ],
    );
  }
}
