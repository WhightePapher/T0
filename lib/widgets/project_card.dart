import 'package:flutter/material.dart';

import '../models/mock_data.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'progress_ring.dart';

/// 最近项目卡片：缩略图块 + 标题 + 元信息 + 环形进度。
class ProjectCard extends StatefulWidget {
  const ProjectCard({super.key, required this.project, this.onTap});

  final RecentProject project;
  final VoidCallback? onTap;

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    final RecentProject project = widget.project;
    final double progress = project.done / project.total;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: context.anim(const Duration(milliseconds: 160)),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(T0.cardRadius),
            border: Border.all(color: _hover ? pal.lineStrong : pal.line),
            boxShadow: _hover ? pal.floatShadow : null,
          ),
          child: Row(
            children: <Widget>[
              _ProjectThumb(dark: project.dark),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tH3.copyWith(fontSize: 16 * context.s, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 2,
                      children: <Widget>[
                        Text(project.kind, style: context.tMeta),
                        _Dot(),
                        Text('${project.modules} 个模块', style: context.tMeta),
                        _Dot(),
                        Text(project.edited, style: context.tMeta),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 环里已经写着「3/5」，旁边再说一次「已确认 3/5」是同一个数重复两遍。
              // 这里只留口径（「个模块」），分数交给环；字号 / 字色与交付页那句一致
              // （11px · ink2Strong），两页并排看能对上。
              Text(
                '已确认 ${project.done} 个模块',
                style: context.tMeta.copyWith(
                  fontSize: 11 * context.s,
                  color: pal.ink2Strong,
                ),
              ),
              const SizedBox(width: 10),
              ProgressRing(
                value: progress,
                size: 46,
                strokeWidth: 4,
                child: Text(
                  '${project.done}/${project.total}',
                  style: context.tMono.copyWith(
                    fontSize: 11 * context.s,
                    fontWeight: FontWeight.w600,
                    color: pal.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: context.pal.lineStrong,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ProjectThumb extends StatelessWidget {
  const _ProjectThumb({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    // 缩略图在两种主题里都保持深底封面（用 cover / coverInk，不是 ink / paper）
    final Color base = dark
        ? Color.lerp(pal.deckCover, pal.deckInk2, 0.45)!
        : pal.deckCover;
    return Container(
      width: 74,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _Bar(width: 44, color: pal.deckCoverInk.withValues(alpha: 0.9)),
          _Bar(width: 34, color: pal.deckCoverInk.withValues(alpha: 0.55)),
          _Bar(width: 24, color: pal.deckAccent),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 3,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }
}
