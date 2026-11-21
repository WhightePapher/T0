import 'package:flutter/material.dart';

import '../../models/mock_data.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/focus_ring.dart';
import '../../widgets/motion_bits.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/status_dot.dart';

/// 6 · 交付检查：整体就绪度 + 已确认 / 待确认 / 待补充分栏清单 + 导出。
class DeliveryPage extends StatelessWidget {
  const DeliveryPage({super.key});

  static const String routeName = '/delivery';

  @override
  Widget build(BuildContext context) {
    final T0Metrics m = context.metrics;
    final T0Store store = T0Store.instance;

    return AppShell(
      activeNav: '/workspace',
      step: FlowStep.delivery,
      child: PageBody(
        children: <Widget>[
          const FlowHead(
            eyebrow: 'Step 04 · Delivery',
            title: '交付前，先把没完成的说清楚。',
            // 手动断行：380px 说明栏里自动断行会把「模块」拆成「模 / 块」
            note: '导出不会悄悄略过未就绪内容。\n'
                '待确认的模块会逐项列出，\n'
                '由你决定补全还是调整导出范围。',
          ),
          const SizedBox(height: 26),
          AnimatedBuilder(
            animation: store.statuses,
            builder: (BuildContext context, _) {
              final Widget summary = _summaryCard(context, store);
              final Widget checklist = _checklistCard(context, store);
              if (m.isDesktop) {
                // 左右等高的清单 + 总览：左侧卡片撑到与右侧清单同高，
                // 两枚按钮用 Spacer 压到卡底（footer 对齐），
                // 卡片底部不再吊着一块 155px 的空白
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(width: 322, child: summary),
                      const SizedBox(width: 24),
                      Expanded(child: checklist),
                    ],
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  summary,
                  const SizedBox(height: 20),
                  checklist,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, T0Store store) {
    final T0Metrics m = context.metrics;
    final bool allDone = store.pendingCount == 0;
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: ProgressRing(
              value: store.deliveryProgress,
              size: 150,
              strokeWidth: 11,
              // 环 sweep 600ms + 百分比同步 count-up（取整显示，不逐帧抖）
              counter: (BuildContext context, double v) => Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${(v * 100).round()}%',
                    style: TextStyle(
                      fontFamily: T0.serifFamily,
                      fontFamilyFallback: T0.serifFallback,
                      fontSize: 34 * context.s,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: context.pal.ink,
                      // 等宽数字（B3）：0%→100% count-up 时百分号不跟着左右跳
                      fontFeatures: kT0TabularFigures,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '整体就绪度',
                    style: context.tMeta.copyWith(fontSize: 9.5 * context.s),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 环到「已就绪」之间的空白用一行口径说明吃掉（原来 118px 纯空）
          Text(
            '交付口径：有内容就计入（已确认 + 待确认）',
            textAlign: TextAlign.center,
            style: context.tMeta.copyWith(
              fontSize: 10.5 * context.s,
              color: context.pal.stepMuted,
            ),
          ),
          if (m.isDesktop) const Spacer(),
          const SizedBox(height: 8),
          // 把环图的口径写出来：交付口径 = 有内容（已确认 + 待确认），
          // 否则 80% 和「已确认 3」看起来互相打架
          Text(
            store.reviewCount > 0
                ? '已就绪 ${store.settledCount}/${store.total}（含 ${store.reviewCount} 待确认）'
                : '已就绪 ${store.settledCount}/${store.total}',
            textAlign: TextAlign.center,
            // 10px 细笔画在卡面上抗锯齿后掉到 2.4:1，加深一档并提到 11px
            style: context.tMeta.copyWith(
              fontSize: 11 * context.s,
              color: context.pal.ink2Strong,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            // 口径只用三个词：已就绪 / 待确认 / 待补充。
            // 「待确认」已经写在环下小字的括号里，这里不再重复一遍（上一版
            // 「（另有 1 个待确认）」和 11px 那句是同一件事的两种说法）。
            allDone ? '可以导出了' : '待补充 ${store.pendingCount} 个模块',
            textAlign: TextAlign.center,
            style: context.tH2.copyWith(fontSize: 20 * context.s, height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            // 一句话、一行：「（含 1 个待确认）」拆行后第二行只剩「待确认）。」，
            // 居中标题下方的左对齐正文看着像掉下来一截 —— 括号内容已并入上面的口径小字。
            allDone
                ? '全部模块已就绪，导出会保留来源标注。'
                : '“结论总结”仍在等材料。',
            textAlign: TextAlign.center,
            style: context.tMeta.copyWith(
              fontSize: 11 * context.s,
              height: 1.75,
            ),
          ),
          // 桌面端左卡被右侧清单撑到同高（实测多出 184px）。留白不堆在一处：
          // 环图下方一段、按钮上方一段，两段各分一半（≈92px），
          // 说明段到按钮之间的距离因此 ≤100px；移动端是无界 Column，不能放 Spacer。
          if (m.isDesktop) const Spacer(),
          PrimaryButton(
            label: '返回补全模块',
            expand: true,
            dense: true,
            onPressed: () {
              final int missingId = moduleSeeds
                  .firstWhere(
                    (ProjectModule module) =>
                        store.statusOf(module.id) == ModuleStatus.missing,
                  )
                  .id;
              store.setActiveModule(missingId);
              go(context, '/workspace');
            },
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: '导出当前范围',
            expand: true,
            dense: true,
            onPressed: () => _openExport(context, store),
          ),
        ],
      ),
    );
  }

  Widget _checklistCard(BuildContext context, T0Store store) {
    // 分组按状态来，而不是「有内容 / 没内容」：
    // 待确认的模块不能混进「已确认」，否则分组标题和胶囊颜色自相矛盾。
    final List<ProjectModule> done = <ProjectModule>[
      for (final ProjectModule module in moduleSeeds)
        if (store.statusOf(module.id) == ModuleStatus.done) module,
    ];
    final List<ProjectModule> review = <ProjectModule>[
      for (final ProjectModule module in moduleSeeds)
        if (store.statusOf(module.id) == ModuleStatus.review) module,
    ];
    final List<ProjectModule> pending = <ProjectModule>[
      for (final ProjectModule module in moduleSeeds)
        if (store.statusOf(module.id) == ModuleStatus.missing) module,
    ];
    final int unfinished = review.length + pending.length;

    return PaperCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '模块检查',
                        style: context.tH3.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '每一项都可以直接返回对应的制作步骤',
                        style: context.tMeta.copyWith(
                          fontSize: 10.5 * context.s,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unfinished > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.pal.dangerSoft,
                      borderRadius: BorderRadius.circular(T0.pillRadius),
                    ),
                    child: Text(
                      // 徽章数字 = 待确认 + 待补充，和下面两组行数一致
                      '$unfinished 项待处理',
                      style: context.tMeta.copyWith(
                        fontSize: 10.5 * context.s,
                        color: context.pal.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.pal.accentSoft,
                      borderRadius: BorderRadius.circular(T0.pillRadius),
                    ),
                    child: Text(
                      '全部已确认',
                      style: context.tMeta.copyWith(
                        fontSize: 10.5 * context.s,
                        color: context.pal.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 三组按状态依次列出：已确认 / 待确认 / 待补充
          for (int i = 0; i < 3; i++) ...<Widget>[
            if (i > 0) const Divider(height: 1),
            _group(
              context,
              const <String>['已确认', '待确认', '待补充'][i],
              <List<ProjectModule>>[done, review, pending][i],
              // 打勾按整张清单的顺序错峰 60ms，不是每组从头开始
              <int>[0, done.length, done.length + review.length][i],
            ),
          ],
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 16, 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '导出会保留“待补充”占位页，不会虚构研究结论。',
                    style: context.tMeta.copyWith(fontSize: 10.5 * context.s),
                  ),
                ),
                const SizedBox(width: 12),
                PrimaryButton(
                  label: '导出',
                  arrow: true,
                  dense: true,
                  onPressed: () => _openExport(context, store),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(
    BuildContext context,
    String title,
    List<ProjectModule> modules,
    int startIndex,
  ) {
    final T0Store store = T0Store.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
          child: Row(
            children: <Widget>[
              Text(title, style: context.tLabel),
              const SizedBox(width: 8),
              Text(
                '${modules.length}',
                style: context.tMono.copyWith(fontSize: 10 * context.s),
              ),
            ],
          ),
        ),
        if (modules.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
            child: Text(
              '暂无',
              style: context.tMeta.copyWith(fontSize: 11 * context.s),
            ),
          ),
        for (int i = 0; i < modules.length; i++)
          _CheckRow(
            module: modules[i],
            status: store.statusOf(modules[i].id),
            delay: T0Motion.staggerCheck * (startIndex + i),
            onTap: () {
              store.setActiveModule(modules[i].id);
              go(context, '/workspace');
            },
          ),
      ],
    );
  }

  void _openExport(BuildContext context, T0Store store) {
    // 导出成功弹层：scale 0.96→1 + fade，220ms enter / 160ms exit。
    // 弹层本身先停在「正在生成 PPTX」2s —— 那就是带待补充导出前的那次确认停顿。
    Navigator.of(context).push<void>(
      t0DialogRoute<void>(
        context: context,
        dismissible: false,
        barrierLabel: '导出',
        builder: (BuildContext context) => _ExportDialog(
          settled: store.settledCount,
          pending: store.pendingCount,
          total: store.total,
        ),
      ),
    );
  }
}

class _CheckRow extends StatefulWidget {
  const _CheckRow({
    required this.module,
    required this.status,
    required this.onTap,
    this.delay = Duration.zero,
  });

  final ProjectModule module;
  final ModuleStatus status;
  final VoidCallback onTap;

  /// 逐条打勾的错峰延时
  final Duration delay;

  @override
  State<_CheckRow> createState() => _CheckRowState();
}

class _CheckRowState extends State<_CheckRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Widget row = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          color: _hover ? context.pal.bg : Colors.transparent,
          padding: const EdgeInsets.fromLTRB(22, 11, 18, 11),
          child: Row(
            children: <Widget>[
              if (widget.status == ModuleStatus.done)
                // 逐条打勾：24px 徽章 + 300ms 描线，按 60ms 错峰
                T0CheckBadge(size: 24, delay: widget.delay)
              else
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusSoftColor(widget.status, context.pal),
                  ),
                  // 图标跟着状态走：待确认=时钟，待补充=感叹号
                  child: switch (widget.status) {
                    ModuleStatus.done => const SizedBox.shrink(),
                    ModuleStatus.review => Icon(Icons.schedule, size: 13, color: context.pal.warn),
                    ModuleStatus.missing => Text(
                        '!',
                        style: context.tBody.copyWith(
                          fontSize: 12 * context.s,
                          fontWeight: FontWeight.w700,
                          color: context.pal.danger,
                        ),
                      ),
                  },
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.module.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tBody.copyWith(
                        fontSize: 13 * context.s,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.module.desc} · ${widget.module.source}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tMeta.copyWith(fontSize: 10.5 * context.s),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 26,
                child: Center(
                  child: Text(
                    '${widget.module.pages} 页',
                    style: context.tMeta.copyWith(fontSize: 10.5 * context.s),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              StatusChip(status: widget.status),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 15,
                color: _hover ? context.pal.ink : context.pal.lineStrong,
              ),
            ],
          ),
        ),
      ),
    );
    return T0FocusRing(radius: 10, onActivate: widget.onTap, child: row);
  }
}

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({
    required this.settled,
    required this.pending,
    required this.total,
  });

  final int settled;
  final int pending;
  final int total;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  bool _generating = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _generating = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: PaperCard(
        width: 460,
        floating: true,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AnimatedSwitcher(
              duration: T0Motion.dur(context, T0Motion.dialogIn),
              switchInCurve: T0Motion.enter,
              switchOutCurve: T0Motion.exit,
              // 成功态：scale 0.96→1 + fade，和弹层本身同一套参数
              transitionBuilder: (Widget child, Animation<double> animation) =>
                  FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: _generating
                  ? _generatingView(context)
                  : _successView(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _generatingView(BuildContext context) {
    return Column(
      key: const ValueKey<String>('generating'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: context.pal.accent),
            ),
            const SizedBox(width: 12),
            Text(
              '正在生成 PPTX',
              style: context.tH2.copyWith(fontSize: 18 * context.s),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '${widget.total} 个模块 · 已就绪 ${widget.settled} · 待补充 ${widget.pending}',
          style: context.tMeta.copyWith(fontSize: 11.5 * context.s),
        ),
      ],
    );
  }

  Widget _successView(BuildContext context) {
    return Column(
      key: const ValueKey<String>('success'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.pal.accentSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, color: context.pal.accent, size: 20),
        ),
        const SizedBox(height: 14),
        Text('已导出 6 页', style: context.tH2.copyWith(fontSize: 20 * context.s)),
        const SizedBox(height: 8),
        Text(
          widget.pending > 0
              ? '包含 ${widget.pending} 页“待补充”占位，可在 PPTX 里继续补写。其余页面保留了来源标注。'
              : '全部页面已确认，来源标注和版本说明一并写入 PPTX。',
          style: context.tMeta.copyWith(
            fontSize: 11.5 * context.s,
            height: 1.75,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            SecondaryButton(
              label: '继续检查',
              dense: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 10),
            PrimaryButton(
              label: '完成',
              dense: true,
              onPressed: () {
                Navigator.of(context).pop();
                showT0Toast(context, '已导出 6 页，可以继续检查或下载。');
              },
            ),
          ],
        ),
      ],
    );
  }
}
