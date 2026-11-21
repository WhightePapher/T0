import 'package:flutter/material.dart';

import '../../models/mock_data.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/focus_ring.dart';
import '../../widgets/motion_bits.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/status_dot.dart';

/// 4 · 模块拆分：5 个模块卡片，可拖拽排序，状态三态可切换。
class ModulesPage extends StatelessWidget {
  const ModulesPage({super.key});

  static const String routeName = '/modules';

  @override
  Widget build(BuildContext context) {
    final T0Metrics m = context.metrics;
    return AppShell(
      activeNav: '/workspace',
      step: FlowStep.modules,
      child: PageBody(
        children: <Widget>[
          const FlowHead(
            eyebrow: 'Step 03 · Modules',
            title: '大纲已经变成 5 个可控模块。',
            note: '按表达任务分模块，不按页数切。',
          ),
          const SizedBox(height: 24),
          if (m.isDesktop)
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: _ModuleList()),
                SizedBox(width: 24),
                SizedBox(width: 322, child: _StructureCard()),
              ],
            )
          else
            const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _ModuleList(),
                SizedBox(height: 20),
                _StructureCard(),
              ],
            ),
        ],
      ),
    );
  }
}

class _ModuleList extends StatelessWidget {
  const _ModuleList();

  @override
  Widget build(BuildContext context) {
    final T0Store store = T0Store.instance;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[store.order, store.statuses]),
      builder: (BuildContext context, _) {
        final List<int> order = store.order.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '${order.length} 个可控模块',
                  style: context.tBody.copyWith(
                    fontSize: 12.5 * context.s,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '拖拽排序',
                  style: context.tMeta.copyWith(fontSize: 11 * context.s),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: order.length,
              onReorderItem: store.move,
              proxyDecorator:
                  (Widget child, int index, Animation<double> animation) =>
                      Material(
                        color: Colors.transparent,
                        child: Transform.scale(scale: 1.01, child: child),
                      ),
              itemBuilder: (BuildContext context, int index) {
                final int id = order[index];
                final ProjectModule module = store.moduleOf(id);
                // 错峰入场：i*40ms，fade + 上移 6px，280ms（只播首帧一次）
                return T0Enter(
                  key: ValueKey<int>(id),
                  delay: T0Motion.staggerModule * index,
                  duration: T0Motion.moduleCardIn,
                  offset: const Offset(0, 6),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ModuleCard(
                      index: index,
                      module: module,
                      status: store.statusOf(id),
                      onOpen: () {
                        store.setActiveModule(id);
                        go(context, '/workspace');
                      },
                      onCycleStatus: () {
                        store.cycleStatus(id);
                        showT0Toast(
                          context,
                          '「${module.title}」已切换为 ${store.statusOf(id).label}，进度环同步更新。',
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _ModuleCard extends StatefulWidget {
  const _ModuleCard({
    required this.index,
    required this.module,
    required this.status,
    required this.onOpen,
    required this.onCycleStatus,
  });

  final int index;
  final ProjectModule module;
  final ModuleStatus status;
  final VoidCallback onOpen;
  final VoidCallback onCycleStatus;

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final ProjectModule module = widget.module;
    final Widget card = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) {
          setState(() => _down = false);
          widget.onOpen();
        },
        child: AnimatedScale(
          // 按下 0.98 → 抬起，再走页面转场（G1）
          scale: _down ? 0.98 : 1,
          duration: T0Motion.dur(context, T0Motion.instant),
          curve: T0Motion.standard,
          child: AnimatedContainer(
            duration: T0Motion.dur(context, T0Motion.fast),
            // hover 抬升 1px（B2）
            transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: context.pal.surface,
              borderRadius: BorderRadius.circular(T0.cardRadius),
              border: Border.all(color: _hover ? context.pal.lineStrong : context.pal.line),
              // 双层阴影常驻（B1），hover 加深（B2）
              boxShadow: _hover ? context.pal.floatShadowHover : context.pal.floatShadow,
            ),
            child: Row(
              children: <Widget>[
                ReorderableDragStartListener(
                  index: widget.index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 16,
                        color: _hover ? context.pal.ink2 : context.pal.lineStrong,
                      ),
                    ),
                  ),
                ),
                Text(
                  module.number,
                  style: TextStyle(
                    fontFamily: T0.serifFamily,
                    fontFamilyFallback: T0.serifFallback,
                    fontSize: 24 * context.s,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: context.pal.accent,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        module.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tBody.copyWith(
                          fontSize: 13.5 * context.s,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        module.desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tMeta.copyWith(fontSize: 11 * context.s),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${module.pages} 页',
                      style: context.tMeta.copyWith(
                        fontSize: 11.5 * context.s,
                        color: context.pal.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      module.source,
                      style: context.tMeta.copyWith(fontSize: 10 * context.s),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onCycleStatus,
                    child: Tooltip(
                      message: '点击切换状态',
                      child: StatusChip(status: widget.status),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: _hover ? context.pal.ink : context.pal.lineStrong,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return T0FocusRing(radius: T0.cardRadius, onActivate: widget.onOpen, child: card);
  }
}

class _StructureCard extends StatelessWidget {
  const _StructureCard();

  @override
  Widget build(BuildContext context) {
    final T0Store store = T0Store.instance;
    return PaperCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('整套结构', style: context.tLabel),
          const SizedBox(height: 10),
          Text(
            '从问题到建议，逐段推进',
            style: context.tH3.copyWith(
              fontSize: 15 * context.s,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < moduleSeeds.length; i++) ...<Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: context.pal.lineStrong),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: context.tMono.copyWith(
                      fontSize: 9 * context.s,
                      color: context.pal.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    moduleSeeds[i].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tBody.copyWith(fontSize: 12 * context.s),
                  ),
                ),
                Text(
                  '${moduleSeeds[i].pages} 页',
                  style: context.tMeta.copyWith(fontSize: 10.5 * context.s),
                ),
              ],
            ),
            if (i != moduleSeeds.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                child: Container(width: 1, height: 12, color: context.pal.line),
              ),
          ],
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: store.statuses,
            builder: (BuildContext context, _) => Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '当前完成',
                  style: context.tMeta.copyWith(fontSize: 11 * context.s),
                ),
                const Spacer(),
                Text(
                  '${store.confirmedCount}/${store.total}',
                  style: TextStyle(
                    fontFamily: T0.serifFamily,
                    fontFamilyFallback: T0.serifFallback,
                    fontSize: 24 * context.s,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: context.pal.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: '进入模块制作',
            expand: true,
            dense: true,
            onPressed: () => go(context, '/workspace'),
          ),
        ],
      ),
    );
  }
}
