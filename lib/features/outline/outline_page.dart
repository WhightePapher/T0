import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/mock_data.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/motion_bits.dart';
import '../../widgets/primary_button.dart';

/// 3 · 大纲确认：中央大纲树（可折叠）+ 素材摘要 + 右侧结构建议。
class OutlinePage extends StatefulWidget {
  const OutlinePage({super.key});

  static const String routeName = '/outline';

  @override
  State<OutlinePage> createState() => _OutlinePageState();
}

class _Suggestion {
  const _Suggestion({
    required this.chapterIndex,
    required this.title,
    required this.text,
    required this.point,
    this.pages,
  });

  final int chapterIndex;
  final String title;
  final String text;
  final String point;

  /// 采纳后写进大纲的页数；null 表示这条建议不动页数
  final String? pages;
}

class _OutlinePageState extends State<OutlinePage> {
  final T0Store _store = T0Store.instance;
  final Set<int> _expanded = <int>{};
  final List<bool?> _handled = <bool?>[null, null];
  /// 采纳前的章节页数，撤销时按原值还原
  final Map<int, String> _pagesBefore = <int, String>{};

  /// 正在收起的章节行（行高 1→0，其余行跟着平滑让位）
  int? _collapsing;
  Timer? _collapseTimer;

  /// 新增行的高亮（green-soft 3s 淡出）
  int? _highlight;
  int _highlightSeed = 0;

  /// 「重新生成」：整列先淡到 0.6，再逐行重新入场
  bool _dim = false;
  int _regenToken = 0;

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  /// 删除：先让这一行高度收到 0（其余行平滑让位），240ms 后再真删。
  void _removeChapter(BuildContext context, int index, int length) {
    if (length <= 3) {
      showT0Toast(context, '至少保留 3 个章节，才能形成完整汇报结构。');
      return;
    }
    if (_collapsing != null) return;
    setState(() => _collapsing = index);
    _collapseTimer?.cancel();
    _collapseTimer = Timer(T0Motion.dur(context, T0Motion.rowResize), () {
      if (!mounted) return;
      setState(() {
        _store.removeChapter(index);
        _collapsing = null;
        _expanded.clear();
      });
      showT0Toast(context, '章节已移除，后面的内容会重新排序。');
    });
  }

  void _addChapter(BuildContext context) {
    _store.addChapter();
    setState(() {
      _highlight = _store.outline.value.length - 1;
      _highlightSeed++;
    });
    showT0Toast(context, '已新增一个章节，确认前都可以继续调整。');
  }

  /// 重新生成：整列淡到 0.6（120ms）→ 逐行重新入场（stagger 30ms）。
  Future<void> _regenerate(BuildContext context) async {
    if (_dim) return;
    setState(() => _dim = true);
    await Future<void>.delayed(T0Motion.dur(context, T0Motion.hint));
    if (!mounted || !context.mounted) return;
    setState(() {
      _dim = false;
      _regenToken++;
    });
    showT0Toast(context, '已按当前材料重新生成，结构未发生大变化。');
  }

  static const List<_Suggestion> _suggestions = <_Suggestion>[
    _Suggestion(
      chapterIndex: 2,
      title: '第 3 章拆成两页',
      text: '冲突类型与现场证据分成两页，避免一页塞太多判断。',
      point: '现场证据：三个时段的观察记录与照片编号',
      // 采纳后才把第 3 章从 1 页写成 2 页
      pages: '2 页',
    ),
    _Suggestion(
      chapterIndex: 5,
      title: '结论前补一句可引用判断',
      text: '结论章目前只有框架，缺少一条能直接引用的实地判断。',
      point: '结论句：公共空间的质量取决于人能不能自然地停下来',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final T0Metrics m = context.metrics;

    final Widget outlineCard = ValueListenableBuilder<List<OutlineItem>>(
      valueListenable: _store.outline,
      builder: (BuildContext context, List<OutlineItem> items, _) =>
          _outlineCard(context, items),
    );

    final Widget source = _sourceCard(context);
    final Widget suggestion = _suggestionCard(context);

    return AppShell(
      activeNav: '/workspace',
      step: FlowStep.outline,
      child: PageBody(
        children: <Widget>[
          const FlowHead(
            eyebrow: 'Step 02 · Outline',
            title: '先改结构，不急着做页面。',
            note: '确认前可增删章节；确认后拆成模块。',
          ),
          const SizedBox(height: 26),
          if (m.isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(width: 252, child: source),
                const SizedBox(width: 22),
                Expanded(child: outlineCard),
                const SizedBox(width: 22),
                SizedBox(width: 306, child: suggestion),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                outlineCard,
                const SizedBox(height: 20),
                suggestion,
                const SizedBox(height: 20),
                source,
              ],
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ 素材摘要
  Widget _sourceCard(BuildContext context) {
    return PaperCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('素材摘要', style: context.tLabel),
          const SizedBox(height: 10),
          Text(
            '城市公共空间调研.docx',
            style: context.tH3.copyWith(
              fontSize: 14 * context.s,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '14 页 · 约 6,800 字\n已提取 6 个主要观点',
            style: context.tMeta.copyWith(
              fontSize: 11.5 * context.s,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: context.pal.accentSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: context.pal.accent, width: 2)),
            ),
            child: Text(
              '“空间使用冲突并不只来自设施数量不足，还与路径连续性和边界清晰度有关。”',
              style: context.tBody.copyWith(
                fontSize: 11.5 * context.s,
                height: 1.75,
                color: context.pal.accentStrong,
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final String line in <String>['原始材料已保留', '观点可追溯', '缺失信息将标记待补充'])
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: context.pal.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: context.tMeta.copyWith(fontSize: 11.5 * context.s),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ 大纲
  Widget _outlineCard(BuildContext context, List<OutlineItem> items) {
    return PaperCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
            child: Row(
              // 左侧「共 N 个章节…」与右侧「+ 新增章节」在同一行垂直居中，
              // 文字基线不再比按钮中心低 14px
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '汇报大纲',
                        style: context.tH3.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '共 ${items.length} 个章节，建议拆为 5 个制作模块',
                        style: context.tMeta.copyWith(
                          fontSize: 11.5 * context.s,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SecondaryButton(
                  label: '新增章节',
                  icon: Icons.add,
                  dense: true,
                  onPressed: () => _addChapter(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            // 整列淡到 0.6 再逐行入场（「重新生成」时）
            child: AnimatedOpacity(
              opacity: _dim ? 0.6 : 1,
              duration: T0Motion.dur(context, T0Motion.hint),
              curve: T0Motion.standard,
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < items.length; i++)
                    T0Enter(
                      // token 变了就换 key → 重新入场（重新生成时逐行 stagger 30ms）
                      key: ValueKey<String>('chapter-$_regenToken-$i'),
                      delay: T0Motion.staggerOutline * i,
                      duration: T0Motion.base,
                      offset: const Offset(0, 6),
                      // 首次进入不做错峰入场：页面转场已经在做，别叠两层
                      play: _regenToken > 0,
                      child: _ChapterRow(
                        index: i,
                        item: items[i],
                        expanded: _expanded.contains(i),
                        last: i == items.length - 1,
                        collapsing: _collapsing == i,
                        highlightSeed: _highlight == i ? _highlightSeed : null,
                        onToggle: () => setState(() {
                          if (_expanded.contains(i)) {
                            _expanded.remove(i);
                          } else {
                            _expanded.add(i);
                          }
                        }),
                        onRemove: () => _removeChapter(context, i, items.length),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: context.metrics.isMobile
                ? Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      SecondaryButton(
                        label: '上一步',
                        dense: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      GhostButton(
                        label: '重新生成',
                        onPressed: () => _regenerate(context),
                      ),
                      PrimaryButton(
                        label: '确认大纲，拆成模块',
                        arrow: true,
                        dense: true,
                        onPressed: () => go(context, '/modules'),
                      ),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      SecondaryButton(
                        label: '上一步',
                        dense: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      GhostButton(
                        label: '重新生成',
                        onPressed: () => _regenerate(context),
                      ),
                      const Spacer(),
                      PrimaryButton(
                        label: '确认大纲，拆成模块',
                        arrow: true,
                        dense: true,
                        onPressed: () => go(context, '/modules'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ 结构建议
  Widget _suggestionCard(BuildContext context) {
    final int handled = _handled.where((bool? value) => value != null).length;
    return PaperCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('结构建议', style: context.tLabel),
          const SizedBox(height: 10),
          Text(
            '两条结构建议',
            style: context.tH3.copyWith(
              fontSize: 15 * context.s,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '来自材料与同类汇报结构的对比，采纳后才会写进大纲。',
            style: context.tMeta.copyWith(
              fontSize: 11 * context.s,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < _suggestions.length; i++) ...<Widget>[
            _suggestionBlock(context, i),
            if (i != _suggestions.length - 1) const SizedBox(height: 14),
          ],
          if (handled == _suggestions.length) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              '建议已处理完，可以确认大纲并拆分模块。',
              style: context.tMeta.copyWith(
                fontSize: 11 * context.s,
                color: context.pal.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _suggestionBlock(BuildContext context, int index) {
    final _Suggestion suggestion = _suggestions[index];
    final bool? state = _handled[index];
    final bool adopted = state == true;
    final bool ignored = state == false;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: adopted ? context.pal.accentSoft : (ignored ? context.pal.bg : context.pal.bg),
        borderRadius: BorderRadius.circular(T0.innerRadius),
        border: Border.all(
          color: adopted ? context.pal.accent.withValues(alpha: 0.3) : context.pal.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            suggestion.title,
            style: context.tBody.copyWith(
              fontSize: 12.5 * context.s,
              fontWeight: FontWeight.w600,
              color: ignored ? context.pal.ink2 : context.pal.ink,
              decoration: ignored
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
              decorationColor: context.pal.lineStrong,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            suggestion.text,
            style: context.tMeta.copyWith(
              fontSize: 11 * context.s,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 10),
          if (state == null)
            Row(
              // 采纳是 46px 高的胶囊，忽略是纯文字：给文字按钮同高容器，
              // 两者视觉中心才对得上（原来差 3px）
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 72,
                  child: PrimaryButton(
                    label: '采纳',
                    dense: true,
                    expand: true,
                    onPressed: () {
                      // 采纳前记下原页数，撤销时按原值还原
                      _pagesBefore[index] =
                          _store.outline.value[suggestion.chapterIndex].pages;
                      _store.adoptSuggestion(
                        suggestion.chapterIndex,
                        suggestion.point,
                        pages: suggestion.pages,
                      );
                      setState(() {
                        _handled[index] = true;
                        _expanded.add(suggestion.chapterIndex);
                      });
                      showT0Toast(
                        context,
                        '已采纳，要点写进了第 ${suggestion.chapterIndex + 1} 章'
                        '${suggestion.pages == null ? '' : '，页数改为 ${suggestion.pages}'}。',
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 46,
                  child: Center(
                    child: GhostButton(
                      label: '忽略',
                      onPressed: () {
                        setState(() => _handled[index] = false);
                        showT0Toast(context, '已忽略这条建议，大纲保持不变。');
                      },
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: <Widget>[
                Icon(
                  adopted ? Icons.check : Icons.remove,
                  size: 13,
                  color: adopted ? context.pal.accent : context.pal.ink2,
                ),
                const SizedBox(width: 5),
                Text(
                  adopted ? '已采纳' : '已忽略',
                  style: context.tMeta.copyWith(
                    fontSize: 11 * context.s,
                    color: adopted ? context.pal.accent : context.pal.ink2,
                  ),
                ),
                const Spacer(),
                GhostButton(
                  label: '撤销',
                  onPressed: () {
                    _store.revertSuggestion(
                      suggestion.chapterIndex,
                      suggestion.point,
                      pages: _pagesBefore[index],
                    );
                    _pagesBefore.remove(index);
                    setState(() => _handled[index] = null);
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChapterRow extends StatefulWidget {
  const _ChapterRow({
    required this.index,
    required this.item,
    required this.expanded,
    required this.last,
    required this.onToggle,
    required this.onRemove,
    this.collapsing = false,
    this.highlightSeed,
  });

  final int index;
  final OutlineItem item;
  final bool expanded;
  final bool last;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  /// 正在收起（行高 1→0，下面的行跟着平滑让位）
  final bool collapsing;

  /// 新增行高亮的种子；null = 不高亮
  final int? highlightSeed;

  @override
  State<_ChapterRow> createState() => _ChapterRowState();
}

class _ChapterRowState extends State<_ChapterRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final OutlineItem item = widget.item;
    final T0Palette pal = context.pal;

    Widget row = Container(
      decoration: BoxDecoration(
        color: _hover ? pal.bg : Colors.transparent,
        border: widget.last
            ? null
            : Border(bottom: BorderSide(color: pal.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                // 用 Material 图标而不是字符图标：字符在 CanvasKit 里没有字形会变豆腐块
                child: Icon(
                  Icons.drag_indicator,
                  size: 15,
                  color: _hover ? pal.ink2 : pal.lineStrong,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 22,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    (widget.index + 1).toString().padLeft(2, '0'),
                    style: context.tMono.copyWith(fontSize: 10 * context.s),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: context.tBody.copyWith(
                        fontSize: 13.5 * context.s,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.note} · ${item.pages}',
                      style: context.tMeta.copyWith(
                        fontSize: 11 * context.s,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                widget.expanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: _hover ? pal.ink : pal.ink2,
              ),
              const SizedBox(width: 4),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onRemove,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline,
                      size: 15,
                      color: _hover ? pal.danger : pal.lineStrong,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (widget.expanded)
            AnimatedSize(
              duration: T0Motion.dur(context, T0Motion.pageOut),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(left: 46, top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final String point in item.points)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              width: 12,
                              height: 1,
                              color: pal.accent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                point,
                                style: context.tMeta.copyWith(
                                  fontSize: 11.5 * context.s,
                                  height: 1.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    // 新增行：green-soft 高亮，3s 内淡出（只画底色，不占布局）
    final int? seed = widget.highlightSeed;
    if (seed != null) {
      row = TweenAnimationBuilder<double>(
        key: ValueKey<int>(seed),
        tween: Tween<double>(begin: 1, end: 0),
        duration: T0Motion.dur(context, T0Motion.highlightFade),
        curve: Curves.linear,
        child: row,
        builder: (BuildContext context, double v, Widget? child) => DecoratedBox(
          decoration: BoxDecoration(
            color: pal.accentSoft.withValues(alpha: 0.55 * v),
          ),
          child: child,
        ),
      );
    }

    // 删除中：行高 1→0 + 淡出，其余行随之平滑上移
    if (widget.collapsing) {
      row = TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1, end: 0),
        duration: T0Motion.dur(context, T0Motion.rowResize),
        curve: T0Motion.standard,
        child: row,
        builder: (BuildContext context, double v, Widget? child) => Align(
          alignment: Alignment.topCenter,
          heightFactor: v,
          child: ClipRect(child: Opacity(opacity: v, child: child)),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: row,
      ),
    );
  }
}
