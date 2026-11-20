import 'package:flutter/material.dart';

import '../../models/mock_data.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/motion_bits.dart';
import '../../widgets/paper_background.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/project_card.dart';
import '../../widgets/section_label.dart';

/// 1 · 工作台：巨号衬线主标题 + 绿色 CTA、最近项目、产品流程说明卡、虚线入口。
class WorkbenchPage extends StatelessWidget {
  const WorkbenchPage({super.key});

  static const String routeName = '/workbench';

  @override
  Widget build(BuildContext context) {
    final T0Metrics m = context.metrics;
    return AppShell(
      activeNav: routeName,
      // 工作台不进流程，但同样占住 48px 步骤条（置灰），保证 01→02 切页不整体跳
      showStep: true,
      child: PageBody(
        children: <Widget>[
          const _Hero(),
          SizedBox(height: m.isMobile ? 28 : 44),
          const _WorkbenchGrid(),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final T0Metrics m = context.metrics;

    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SectionLabel(text: 'Workbench · 04'),
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(text: '把一次汇报，\n拆成'),
              TextSpan(
                text: '可以控制的几步。',
                style: TextStyle(color: context.pal.accent),
              ),
            ],
          ),
          style: context.tDisplay,
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: Text(
            '从材料出发，先定结构，再逐模块完善。',
            style: context.tBody.copyWith(
              fontSize: 14 * context.s,
              height: 1.85,
              // 浅色底上的次级说明统一走 stepMuted（4.95:1），
              // 和「最近项目」、交付页右上说明同一套，不再各自为政
              color: context.pal.stepMuted,
            ),
          ),
        ),
      ],
    );

    final Widget cta = PrimaryButton(
      label: '新建一个项目',
      arrow: true,
      expand: m.isMobile,
      onPressed: () => go(context, '/intake'),
    );

    if (m.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[copy, const SizedBox(height: 20), cta],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(child: copy),
        const SizedBox(width: 32),
        Padding(padding: const EdgeInsets.only(bottom: 6), child: cta),
      ],
    );
  }
}

class _WorkbenchGrid extends StatelessWidget {
  const _WorkbenchGrid();

  @override
  Widget build(BuildContext context) {
    final T0Metrics m = context.metrics;
    if (m.isDesktop) {
      // 左右两栏等高：右栏「产品流程」卡片用 stretch 撑到与左侧整栏同高，
      // 左侧虚线入口用 Expanded 吃掉剩余空间，两侧底边落在同一条线上。
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const <Widget>[
            Expanded(child: _ProjectStack(fill: true)),
            SizedBox(width: 24),
            SizedBox(width: 322, child: _FlowAside()),
          ],
        ),
      );
    }
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[_ProjectStack(), SizedBox(height: 20), _FlowAside()],
    );
  }
}

class _ProjectStack extends StatelessWidget {
  const _ProjectStack({this.fill = false});

  /// true：桌面端等高布局，虚线入口撑满剩余高度
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('最近项目', style: context.tLabel.copyWith(color: context.pal.stepMuted)),
        const SizedBox(height: 12),
        for (int i = 0; i < recentProjects.length; i++) ...<Widget>[
          // 错峰入场：第 i 张延时 i*45ms，fade 0→1 + 上移 8→0，320ms，只播一次。
          // T0Enter 只重跑自己那一层 Opacity / Transform，卡片本体不重建。
          T0Enter(
            key: ValueKey<String>('project-${recentProjects[i].name}'),
            delay: T0Motion.staggerCard * i,
            duration: T0Motion.cardIn,
            offset: const Offset(0, 8),
            child: ProjectCard(
              project: recentProjects[i],
              onTap: () => go(context, recentProjects[i].route),
            ),
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 2),
        if (fill)
          Expanded(child: _NewProjectEntry())
        else
          _NewProjectEntry(),
      ],
    );
  }
}

class _NewProjectEntry extends StatefulWidget {
  @override
  State<_NewProjectEntry> createState() => _NewProjectEntryState();
}

class _NewProjectEntryState extends State<_NewProjectEntry> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => go(context, '/intake'),
        child: DashedBox(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          fill: _hover ? context.pal.surface : null,
          color: _hover ? context.pal.accent : context.pal.lineStrong,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _hover ? context.pal.accent : context.pal.lineStrong),
                  ),
                  child: Icon(
                    Icons.add,
                    size: 18,
                    color: _hover ? context.pal.accent : context.pal.ink2,
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('从一份材料开始', style: context.tH3),
                      const SizedBox(height: 2),
                      Text('支持文档、长文本或一句主题', style: context.tMeta),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlowAside extends StatelessWidget {
  const _FlowAside();

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // 桌面端这张卡被右列拉到与左侧整栏等高（IntrinsicHeight + stretch），
        // 内容原来贴顶 → 实测上 27px / 下 94px。改成整列在卡内垂直居中，
        // 上下留白相等；卡高由左列决定、左列与文字都没动。
        // 移动端是无界高度，mainAxisSize.max 会退化成 min，不影响单列布局。
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Text('产品流程', style: context.tLabel),
          const SizedBox(height: 10),
          Text(
            '三步',
            style: context.tH3.copyWith(
              fontSize: 16 * context.s,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          const _FlowRow(
            number: '01',
            title: '先确认结构',
            text: '材料不足时不编造，先标记待补充。',
          ),
          const SizedBox(height: 16),
          const _FlowRow(
            number: '02',
            title: '按模块制作',
            text: '点击哪个模块，就只处理哪个模块。',
          ),
          const SizedBox(height: 16),
          const _FlowRow(
            number: '03',
            title: '每一步可回退',
            text: '确认后保存版本，未完成内容在交付前提醒。',
          ),
        ],
      ),
    );
  }
}

class _FlowRow extends StatelessWidget {
  const _FlowRow({
    required this.number,
    required this.title,
    required this.text,
  });

  final String number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          // 序号和标题共用一条基线，数字不再比标题高 5px
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            SizedBox(
              width: 26,
              child: Text(
                number,
                style: context.tMono.copyWith(fontSize: 10 * context.s),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: context.tBody.copyWith(
                  fontSize: 13 * context.s,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 34),
          child: Text(
            text,
            style: context.tMeta.copyWith(
              fontSize: 11.5 * context.s,
              height: 1.65,
            ),
          ),
        ),
      ],
    );
  }
}
