import 'package:flutter/material.dart';

import '../models/mock_data.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';

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
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.status, this.size = 8, this.ring = false});

  final ModuleStatus status;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final Color color = statusColor(status, context.pal);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring ? Colors.transparent : color,
        border: ring ? Border.all(color: color, width: 1.4) : null,
      ),
    );
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
