import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/mock_data.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/focus_ring.dart';
import '../../widgets/motion_bits.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/status_dot.dart';

/// 5 · 模块工作区：左模块栏 / 中画布（深绿封面页 + 白色内容页）/ 右 AI 修改面板。
class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key});

  static const String routeName = '/workspace';

  /// 帧耗时采集（`--perf=C`，见 main.dart）用：让驱动脚本能打开/关掉真实的
  /// 「前后对比」弹层，测到的就是用户点出来的那一个，不复制第二套 UI。
  static final GlobalKey<State<WorkspacePage>> perfKey = GlobalKey<State<WorkspacePage>>();

  /// 开一次真实的「前后对比」弹层，停留 320ms 后关掉（C 组 20 次操作里的一项）
  static Future<void> perfCompareOnce() async {
    final State<WorkspacePage>? state = perfKey.currentState;
    if (state is! _WorkspacePageState || !state.mounted) return;
    final BuildContext ctx = state.context;
    final Future<void> opened = state._openCompare(ctx);
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (ctx.mounted) Navigator.of(ctx).pop();
    await opened;
  }

  /// 只开不关（`--perf=E`：弹层开着切主题，量最重的那一帧）
  static Future<void> perfOpenCompareOnly() async {
    final State<WorkspacePage>? state = perfKey.currentState;
    if (state is! _WorkspacePageState || !state.mounted) return;
    state._openCompare(state.context);
  }

  /// 关掉上面那个弹层
  static void perfCloseCompare() {
    final State<WorkspacePage>? state = perfKey.currentState;
    if (state is! _WorkspacePageState || !state.mounted) return;
    final BuildContext ctx = state.context;
    if (ctx.mounted) Navigator.of(ctx).pop();
  }

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  final T0Store _store = T0Store.instance;
  final TextEditingController _prompt = TextEditingController();

  final List<_Message> _thread = <_Message>[
    const _Message(
      author: 't0 copilot',
      text: '我已根据当前模块生成两页建议。你可以继续调整文字密度、结构顺序或重点强调。',
    ),
  ];

  /// 只在「按下 → 松开/取消」之间为 true（hover 不再改它，见 [_HoldCompare]）
  bool _holding = false;
  bool _loading = false;
  bool _aiOpen = false;

  /// 当前模块有没有 v2（编辑后的版本）。
  bool get _hasVersion2 => _store.hasEdits(_activeId);

  /// 画布此刻展示的是不是「修改前」：按住 + 这个模块确实存在 v1/v2 两版。
  /// 没有编辑过的模块只有一版，按住不应该假装有变化。
  bool get _showingBefore => _holding && _hasVersion2;

  /// 画布实际采用的版本：按住时降到 v1，松开回到 v2。
  bool get _canvasVersion2 => _hasVersion2 && !_showingBefore;

  /// 窄屏模块胶囊行的横向滚动位置：滚到最右后不再显示右侧渐隐
  final ScrollController _stripScroll = ScrollController();
  bool _stripAtEnd = false;

  // ------------------------------------------------- 左栏高亮条（G7）
  //
  // 高亮条是「一块在主栏之上滑动的面」，不是每行自己变色：所以先量出当前
  // 选中行的矩形（GlobalKey + localToGlobal，相对 Stack），再交给
  // AnimatedPositioned 滑过去。量到的矩形只在变化时 setState，不会每帧回写。
  final GlobalKey _railStackKey = GlobalKey();
  final Map<int, GlobalKey> _railKeys = <int, GlobalKey>{};
  final Map<int, Rect> _railRects = <int, Rect>{};
  bool _railMeasureScheduled = false;

  /// 「前后对比」按钮：弹层缩放的原点用它量（G7）
  final GlobalKey _compareButtonKey = GlobalKey(debugLabel: 'compare-open');

  GlobalKey _railKey(int id) =>
      _railKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'rail-$id'));

  void _scheduleRailMeasure() {
    if (_railMeasureScheduled) return;
    _railMeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _railMeasureScheduled = false;
      if (!mounted) return;
      final RenderObject? stack = _railStackKey.currentContext?.findRenderObject();
      if (stack is! RenderBox) return;
      final Map<int, Rect> next = <int, Rect>{};
      for (final int id in _store.order.value) {
        final RenderObject? box = _railKeys[id]?.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize) continue;
        next[id] = box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
      }
      if (next.isEmpty) return;
      bool changed = next.length != _railRects.length;
      if (!changed) {
        for (final MapEntry<int, Rect> entry in next.entries) {
          if (_railRects[entry.key] != entry.value) {
            changed = true;
            break;
          }
        }
      }
      if (changed) {
        setState(() {
          _railRects
            ..clear()
            ..addAll(next);
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _stripScroll.addListener(_onStripScroll);
  }

  void _onStripScroll() {
    if (!_stripScroll.hasClients) return;
    final bool atEnd = _stripScroll.position.extentAfter < 1;
    if (atEnd != _stripAtEnd) {
      setState(() => _stripAtEnd = atEnd);
    }
  }

  @override
  void dispose() {
    _stripScroll.removeListener(_onStripScroll);
    _stripScroll.dispose();
    _prompt.dispose();
    super.dispose();
  }

  static const List<String> _chips = <String>[
    '文字太多，压缩成三点，每点不超过 18 个字。',
    '把三条建议改成按优先级排列，突出路径连续。',
    '保留结论，但把版式改得更像研究报告。',
  ];

  Listenable get _state => Listenable.merge(<Listenable>[
    _store.activeModuleId,
    _store.zoom,
    _store.editedModules,
    _store.statuses,
  ]);

  @override
  Widget build(BuildContext context) {
    final T0Metrics m = context.metrics;
    return AppShell(
      activeNav: '/workspace',
      step: FlowStep.modules,
      flush: true,
      child: AnimatedBuilder(
        animation: _state,
        builder: (BuildContext context, _) {
          if (m.isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(width: 282, child: _rail(context)),
                Container(width: 1, color: context.pal.line),
                Expanded(child: _canvas(context)),
                Container(width: 1, color: context.pal.line),
                SizedBox(width: 380, child: _aiPane(context, compact: false)),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _railStrip(context),
              Expanded(
                child: Stack(
                  children: <Widget>[
                    _canvas(context),
                    if (_aiOpen) _drawer(context),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int get _activeId => _store.activeModuleId.value;

  ProjectModule get _activeModule => _store.moduleOf(_activeId);

  SlideContent get _activeSlide => slideContents[_activeId]!;

  // ------------------------------------------------------------ 左栏
  Widget _rail(BuildContext context) {
    // 量一次高亮条该落在哪一行（post-frame；量到的值真的变了才 setState）
    _scheduleRailMeasure();
    return Container(
      color: context.pal.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('当前项目', style: context.tLabel),
                const SizedBox(height: 8),
                Text(
                  _store.projectName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.tH2.copyWith(fontSize: 20 * context.s),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(child: _BarProgress(value: _store.progress)),
                    const SizedBox(width: 8),
                    // 带上数字，让这条线读起来是进度而不是没画完的下划线
                    Text(
                      '${_store.confirmedCount}/${_store.total}',
                      style: context.tMono.copyWith(fontSize: 9 * context.s),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              // 滚动统一口径（B7）：桌面 Clamping / 窄屏 Bouncing
              physics: t0ScrollPhysics(context),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Stack(
                key: _railStackKey,
                children: <Widget>[
                  // 高亮条：位置 / 长度变化 240ms standard 滑到新项（不再瞬切）
                  if (_railRects[_activeId] case final Rect rect)
                    AnimatedPositioned(
                      duration: T0Motion.dur(context, T0Motion.base),
                      curve: T0Motion.standard,
                      left: 0,
                      right: 0,
                      top: rect.top,
                      height: rect.height,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.pal.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.pal.line),
                            boxShadow: context.pal.softShadow,
                          ),
                        ),
                      ),
                    ),
                  Column(
                    children: <Widget>[
                      for (final int id in _store.order.value)
                        _RailItem(
                          boxKey: _railKey(id),
                          module: _store.moduleOf(id),
                          status: _store.statusOf(id),
                          active: id == _activeId,
                          pagesText:
                              '${_store.moduleOf(id).pages} 页 · ${_store.statusOf(id).label}',
                          onTap: () => _store.setActiveModule(id),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                PrimaryButton(
                  label: '交付检查',
                  arrow: true,
                  dense: true,
                  expand: true,
                  onPressed: () => go(context, '/delivery'),
                ),
                // 按钮上移一格 + 下方留说明，避免和画布底部的「模块目标」信息条
                // 落在同一水平带上、两个绿块并排打架
                // 按钮再上移一格，彻底离开底部「模块目标」信息条所在水平带
                const SizedBox(height: 10),
                Text(
                  '交付前会逐项检查未完成模块',
                  textAlign: TextAlign.center,
                  style: context.tMeta.copyWith(fontSize: 9.5 * context.s),
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _railStrip(BuildContext context) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: context.pal.surface,
        border: Border(bottom: BorderSide(color: context.pal.line)),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ListView(
              controller: _stripScroll,
              physics: t0ScrollPhysics(context),
              scrollDirection: Axis.horizontal,
              // 右侧多留 4px：滚到最右时最后一个胶囊不再顶到屏幕边
              padding: const EdgeInsets.fromLTRB(12, 11, 16, 11),
              children: <Widget>[
                for (final int id in _store.order.value)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _store.setActiveModule(id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: id == _activeId ? context.pal.bg : context.pal.surface,
                          borderRadius: BorderRadius.circular(T0.pillRadius),
                          border: Border.all(
                            color: id == _activeId ? context.pal.lineStrong : context.pal.line,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            StatusDot(status: _store.statusOf(id), size: 6),
                            const SizedBox(width: 8),
                            Text(
                              '${_store.moduleOf(id).number} ${_store.moduleOf(id).title}',
                              style: context.tBody.copyWith(
                                fontSize: 12 * context.s,
                                fontWeight: id == _activeId
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 右缘渐隐：让被屏幕切掉的第 5 个胶囊读起来是「还能横向滚动」，
          // 而不是被裁坏；滚到最右后自动收掉
          if (!_stripAtEnd)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: 28,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: <Color>[
                        context.pal.surface.withValues(alpha: 0),
                        context.pal.surface.withValues(alpha: 0.92),
                        context.pal.surface,
                      ],
                      stops: const <double>[0, 0.6, 1],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ 中间画布
  Widget _canvas(BuildContext context) {
    final T0Metrics m = context.metrics;
    return Container(
      color: context.pal.deckBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _toolbar(context),
          Expanded(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) {
                      final double pad = m.isMobile ? 14 : 28;
                      // 窄屏把整页缩到可视宽度（min(用户缩放, 适配比例)），避免画布被裁成半页
                      final double fit = (box.maxWidth - pad * 2) / 720;
                      final double scale = math.min(_store.zoom.value, fit);
                      final double slideWidth = 720 * scale;
                      // 左右留白必须相等：可用宽度够就居中（左 = 右 = (宽-幻灯片)/2），
                      // 不够就退到最小 28px，由横向滚动承接，绝不出现「左 96 右 10」
                      final double side = math.max(
                        pad,
                        (box.maxWidth - slideWidth) / 2,
                      );
                      return SingleChildScrollView(
                        physics: t0ScrollPhysics(context),
                        // 底部多留一条页脚的高度（≈72）：滚到底时白页最后一行
                        // 不会被「模块目标」信息条压着切半
                        padding: EdgeInsets.only(top: pad, bottom: pad + 72),
                        child: SingleChildScrollView(
                          physics: t0ScrollPhysics(context),
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(horizontal: side),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              _scaledSlide(
                                context,
                                _slideCover(context, edited: _canvasVersion2),
                                scale: scale,
                                version2: _canvasVersion2,
                              ),
                              const SizedBox(height: 20),
                              _scaledSlide(
                                context,
                                _slideContent(context, edited: _canvasVersion2),
                                scale: scale,
                                version2: _canvasVersion2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // 提示条「正在看修改前」：出现 120ms fade + 高度展开（收起反着来）
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: T0Motion.dur(context, T0Motion.hint),
                        switchInCurve: T0Motion.standard,
                        switchOutCurve: T0Motion.exit,
                        transitionBuilder: (
                          Widget child,
                          Animation<double> animation,
                        ) =>
                            FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axisAlignment: -1,
                            child: child,
                          ),
                        ),
                        child: _showingBefore
                            ? const _HoldHint(key: ValueKey<String>('hold-hint'))
                            : const SizedBox(
                                key: ValueKey<String>('hold-hint-off'),
                                width: 0,
                                height: 0,
                              ),
                      ),
                    ),
                  ),
                ),
                if (_loading)
                  Positioned.fill(
                    // 骨架 shimmer：斜向高光带 1.2s 循环横扫；底色是最浅的纸色 surface
                    child: _CanvasSkeleton(
                      zoom: _store.zoom.value,
                      child: Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          color: context.pal.surface,
                          borderRadius: BorderRadius.circular(T0.cardRadius),
                          border: Border.all(color: context.pal.line),
                          boxShadow: context.pal.floatShadow,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: context.pal.accent,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('正在处理当前模块', style: context.tH3),
                            const SizedBox(height: 4),
                            Text('读取模块目标、来源材料和修改要求…', style: context.tMeta),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _canvasFoot(context),
        ],
      ),
    );
  }

  /// 顶部工具栏：三段式（左面包屑 / 中缩放 / 右操作）。
  /// 组内间距 8，组间 24；撤销重做收进右操作组，不再孤立地悬在中间。
  Widget _toolbar(BuildContext context) {
    final T0Metrics m = context.metrics;
    final double zoom = _store.zoom.value;
    // 徽章跟着画布走：按住看修改前时显示 v1，松开回 v2
    final bool edited = _canvasVersion2;

    final Widget crumbs = m.isMobile
        ? Text(
            _activeModule.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.tBody.copyWith(
              fontSize: 12 * context.s,
              fontWeight: FontWeight.w600,
            ),
          )
        : RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: context.tMeta.copyWith(fontSize: 11 * context.s),
              children: <InlineSpan>[
                TextSpan(text: '${_activeModule.group} / '),
                TextSpan(
                  text: _activeModule.title,
                  style: TextStyle(
                    fontFamily: T0.sansFamily,
                    fontFamilyFallback: T0.sansFallback,
                    fontWeight: FontWeight.w600,
                    color: context.pal.ink,
                  ),
                ),
                TextSpan(text: ' / 第 $_activeId 模块'),
              ],
            ),
          );

    final Widget zoomGroup = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(T0.pillRadius),
        border: Border.all(color: context.pal.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _IconSquare(
            icon: Icons.remove,
            tooltip: '缩小',
            dense: true,
            onTap: () => _store.setZoom(zoom - 0.06),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${(zoom * 100).round()}%',
              textAlign: TextAlign.center,
              style: context.tMono.copyWith(
                fontSize: 10.5 * context.s,
                color: context.pal.ink,
              ),
            ),
          ),
          _IconSquare(
            icon: Icons.add,
            tooltip: '放大',
            dense: true,
            onTap: () => _store.setZoom(zoom + 0.06),
          ),
        ],
      ),
    );

    final List<Widget> actions = <Widget>[
      _IconSquare(
        icon: Icons.undo,
        tooltip: '撤销',
        onTap: () {
          _store.revertEdit(_activeId);
          showT0Toast(context, '已撤销上一次修改，回到版本 1。');
        },
      ),
      const SizedBox(width: 8),
      _IconSquare(
        icon: Icons.redo,
        tooltip: '重做',
        onTap: () {
          _store.applyEdit(_activeId);
          showT0Toast(context, '已恢复到版本 2。');
        },
      ),
      const SizedBox(width: 24),
      _HoldCompare(
        active: _holding,
        onChanged: (bool value) => setState(() => _holding = value),
      ),
      const SizedBox(width: 8),
      SecondaryButton(
        key: _compareButtonKey,
        label: '前后对比',
        dense: true,
        onPressed: () => _openCompare(context),
      ),
      const SizedBox(width: 8),
      Tooltip(
        message: edited ? '当前是版本 2' : '当前是版本 1',
        child: Text(
          edited ? 'v2' : 'v1',
          style: context.tMono.copyWith(
            fontSize: 10 * context.s,
            color: edited ? context.pal.accent : context.pal.ink2,
          ),
        ),
      ),
    ];

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.pal.surface,
        border: Border(bottom: BorderSide(color: context.pal.line)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: crumbs),
          ),
          const SizedBox(width: 24),
          zoomGroup,
          const SizedBox(width: 24),
          if (m.isMobile)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _IconSquare(
                  icon: Icons.compare_arrows,
                  tooltip: '前后对比',
                  onTap: () => _openCompare(context),
                ),
                const SizedBox(width: 8),
                SecondaryButton(
                  label: 'AI 修改',
                  dense: true,
                  onPressed: () => setState(() => _aiOpen = !_aiOpen),
                ),
              ],
            )
          else
            Row(mainAxisSize: MainAxisSize.min, children: actions),
        ],
      ),
    );
  }

  Widget _canvasFoot(BuildContext context) {
    final T0Metrics m = context.metrics;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: context.pal.surface,
        border: Border(top: BorderSide(color: context.pal.line)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '模块目标：${_activeModule.desc}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tBody.copyWith(
                    fontSize: 12 * context.s,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '来源：${_activeModule.source} · 预计 ${_activeModule.pages} 页',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tMeta.copyWith(fontSize: 10.5 * context.s),
                ),
              ],
            ),
          ),
          if (!m.isMobile) ...<Widget>[
            const SizedBox(width: 12),
            const _BriefChip(text: '仅当前模块'),
            const SizedBox(width: 8),
            const _BriefChip(text: '保留历史版本'),
          ],
        ],
      ),
    );
  }

  /// 画布上的幻灯片：外层按缩放尺寸占位，内层 720×405 真实版面。
  ///
  /// [version2] 变化（按住看修改前 / 松开恢复）时用 150ms 淡入淡出切换，
  /// 不做瞬切 —— 一页文字整块消失再出现会闪。
  Widget _scaledSlide(
    BuildContext context,
    Widget slide, {
    double? scale,
    bool version2 = true,
  }) {
    final double zoom = scale ?? _store.zoom.value;
    return SizedBox(
      width: 720 * zoom,
      height: 405 * zoom,
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: 720,
          height: 405,
          child: AnimatedSwitcher(
            duration: T0Motion.dur(context, T0Motion.fast),
            switchInCurve: T0Motion.standard,
            switchOutCurve: T0Motion.exit,
            // 默认 layoutBuilder 用 Stack(loose) 会让幻灯片按内容收缩；
            // 这里强制 expand，过渡期间新旧两页都保持 720×405 的排版
            layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ...previous,
                ?current,
              ],
            ),
            // 新内容额外做一次轻微上移 4px→0（720 宽版面坐标，屏幕上按缩放等比），不做放大
            transitionBuilder: (Widget child, Animation<double> animation) {
              final CurvedAnimation curved = CurvedAnimation(
                parent: animation,
                curve: T0Motion.standard,
                reverseCurve: T0Motion.exit,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 4 / 405),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<bool>(version2),
              child: slide,
            ),
          ),
        ),
      ),
    );
  }

  /// 幻灯片页眉小标（`t0 / CONTROLLED SLIDES`、页码）：sans 12px。
  ///
  /// 原来 8–9px 等宽（Cascadia Mono）—— 纸卡按 720×405 画、再按 71% 缩到屏幕上，
  /// 8px 只剩 5.7px，数字 `0` 的中孔糊死，肉眼读成「t8」（r6 遗留 P2）。
  /// 换 sans 12px 后：100% 缩放下 12px，默认 71% 缩放下 8.5px，`0` 的中孔可辨。
  TextStyle _eyebrow(Color color) => TextStyle(
        fontFamily: T0.sansFamily,
        fontFamilyFallback: T0.sansFallback,
        fontSize: 12,
        letterSpacing: 1.0,
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// 幻灯片页眉右上角的页码写法（r8）：舞台、深绿封面页、对比弹层缩略图三处共用。
  ///
  /// 原来舞台写 `t0 / 04`、另外两处只写 `04`，同一张幻灯片右上角两种写法；
  /// 页码只在这里拼，三处都调它，别再各自拼字符串。
  String _deckPageLabel(String number) => 't0 / $number';

  /// 深绿封面页
  Widget _slideCover(BuildContext context, {required bool edited}) {
    final SlideContent slide = _activeSlide;
    final String title = edited ? slide.compressedTitle : slide.title;
    final String accent = edited ? slide.compressedAccent : slide.accent;
    final bool missing = _store.statusOf(_activeId) == ModuleStatus.missing;

    return Container(
      // 封面页在两套主题里都保持深底：用 cover / coverInk，不跟随 ink
      decoration: BoxDecoration(
        color: context.pal.deckCover,
        boxShadow: context.pal.deckCoverShadow,
      ),
      padding: const EdgeInsets.fromLTRB(44, 30, 44, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                't0 / CONTROLLED SLIDES',
                style: _eyebrow(context.pal.deckCoverInk.withValues(alpha: 0.66)),
              ),
              const Spacer(),
              Text(
                _deckPageLabel(slide.number),
                style: _eyebrow(context.pal.deckCoverInk.withValues(alpha: 0.66)),
              ),
            ],
          ),
          if (missing) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: context.pal.deckDangerSoft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '待补充原始材料',
                style: TextStyle(
                  fontFamily: T0.sansFamily,
                  fontFamilyFallback: T0.sansFallback,
                  fontSize: 9,
                  color: context.pal.deckDanger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                slide.number,
                style: TextStyle(
                  fontFamily: T0.serifFamily,
                  fontFamilyFallback: T0.serifFallback,
                  fontSize: 86,
                  height: 0.9,
                  fontWeight: FontWeight.w700,
                  color: context.pal.deckCoverInk.withValues(alpha: 0.16),
                ),
              ),
              const SizedBox(width: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  slide.group,
                  style: TextStyle(
                    fontFamily: T0.sansFamily,
                    fontFamilyFallback: T0.sansFallback,
                    fontSize: 9.5,
                    letterSpacing: 3,
                    color: context.pal.deckCoverAccent.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RichText(
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                fontFamily: T0.serifFamily,
                fontFamilyFallback: T0.serifFallback,
                fontSize: 35,
                height: 1.24,
                fontWeight: FontWeight.w700,
                color: context.pal.deckCoverInk,
              ),
              children: <InlineSpan>[
                TextSpan(text: title),
                TextSpan(
                  text: accent,
                  style: TextStyle(color: context.pal.deckCoverAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            slide.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: T0.sansFamily,
              fontFamilyFallback: T0.sansFallback,
              fontSize: 11,
              height: 1.85,
              color: context.pal.deckCoverInk.withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          Row(
            children: <Widget>[
              Text(
                edited ? '版本 2 · 结构压缩版' : '版本 1 · 当前页',
                style: TextStyle(
                  fontFamily: T0.monoFamily,
                  fontFamilyFallback: T0.monoFallback,
                  fontSize: 8,
                  color: context.pal.deckCoverInk.withValues(alpha: 0.45),
                ),
              ),
              const Spacer(),
              Text(
                missing ? '不会自动编造内容' : 't0 办公 · 可编辑页面',
                style: TextStyle(
                  fontFamily: T0.monoFamily,
                  fontFamilyFallback: T0.monoFallback,
                  fontSize: 8,
                  color: context.pal.deckCoverInk.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 白色内容页
  Widget _slideContent(BuildContext context, {required bool edited}) {
    final SlideContent slide = _activeSlide;

    return Container(
      color: context.pal.deckPaper,
      padding: const EdgeInsets.fromLTRB(44, 28, 44, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                edited ? '结构压缩版' : 't0 / CONTROLLED SLIDES',
                // 纸卡按 720×405 画、再 FittedBox 缩到 71%：中文小标 15px → 屏幕上 10.7px
                // （13px 只剩 9.2px，低于 r4 定的「屏幕 ≥10px」）；英文小标走 _eyebrow(12px)
                // → 屏幕上 8.5px，`0` 的中孔不再糊成「t8」。
                style: edited
                    ? TextStyle(
                        fontFamily: T0.sansFamily,
                        fontFamilyFallback: T0.sansFallback,
                        fontSize: 15,
                        height: 1.1,
                        letterSpacing: 0.8,
                        color: context.pal.deckInk2,
                      )
                    : _eyebrow(context.pal.deckInk2),
              ),
              const Spacer(),
              Text(
                _deckPageLabel(slide.number),
                style: _eyebrow(context.pal.deckInk2),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                fontFamily: T0.serifFamily,
                fontFamilyFallback: T0.serifFallback,
                fontSize: 30,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: context.pal.deckInk,
              ),
              children: <InlineSpan>[
                TextSpan(
                  // 版本 1 保留标题里作者写好的换行：原来这里 replaceAll('\n','') 把
                  // 「把“停留”作为设计单位，/ 而不只是增加」压成一行，30px 下第二行只剩
                  // 「量。」两个字的孤尾。保留换行就是两行均衡断句（与上方封面页一致）。
                  text: edited ? slide.compressedTitle : slide.title,
                ),
                TextSpan(
                  text: edited ? slide.compressedAccent : slide.accent,
                  style: TextStyle(color: context.pal.deckAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!edited)
            Text(
              slide.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: T0.sansFamily,
                fontFamilyFallback: T0.sansFallback,
                fontSize: 10,
                height: 1.8,
                color: context.pal.deckInk2,
              ),
            ),
          // r8：版本 2 的「标题分隔线」不再单独画一条，改成首行的上边框（见下方 Border.top）：
          // 三行统一「线在行顶」——线到标题的间距三条一致（屏幕 6px，要求 7±1）。
          // 这里只留等量留白（原 12 + 1px 线 + 12），
          // 行高 45px 与改前一致。版本 1（三栏）仍用独立分隔线。
          if (edited)
            const SizedBox(height: 25)
          else ...<Widget>[
            const SizedBox(height: 12),
            Container(height: 1, color: context.pal.deckLine),
            const SizedBox(height: 12),
          ],
          if (edited)
            Expanded(
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < slide.rows.length; i++)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          // r8：三条分隔线全部由行的上边框画（含首行），
                          // 线到各自标题的间距因此一致（屏幕实测 6 / 6 / 6px）
                          border: Border(
                            top: BorderSide(color: context.pal.deckLine),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              (i + 1).toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontFamily: T0.monoFamily,
                                fontFamilyFallback: T0.monoFallback,
                                fontSize: 9,
                                color: context.pal.deckAccent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    slide.rows[i].title,
                                    style: TextStyle(
                                      fontFamily: T0.sansFamily,
                                      fontFamilyFallback: T0.sansFallback,
                                      fontSize: 13,
                                      height: 1.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.pal.deckInk,
                                    ),
                                  ),
                                  Text(
                                    slide.rows[i].text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: T0.sansFamily,
                                      fontFamilyFallback: T0.sansFallback,
                                      fontSize: 10.5,
                                      height: 1.6,
                                      color: context.pal.deckInk2,
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
            )
          else
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                // 三栏等分 + 栏间统一 18px 间距：色线在 Expanded 里、不再套 Padding。
                // 原来前两栏套了 Padding(right:18)、末栏 right:0，色线被裁成
                // 159/159/174（末栏多 15px）；改成 spacing 后三栏同宽，
                // 色线与正文行宽一起对齐。
                spacing: 18,
                children: <Widget>[
                  for (int i = 0; i < slide.columns.length; i++)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            height: 2,
                            // 首栏线用品牌绿 deckAccent（原型 #147A62），二三栏橙/蓝不变
                            color: i == 0
                                ? context.pal.deckAccent
                                : (i == 1 ? context.pal.deckWarn : context.pal.deckLilac),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            slide.columns[i].title,
                            style: TextStyle(
                              fontFamily: T0.sansFamily,
                              fontFamilyFallback: T0.sansFallback,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: context.pal.deckInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            slide.columns[i].text,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: T0.sansFamily,
                              fontFamilyFallback: T0.sansFallback,
                              fontSize: 10.5,
                              height: 1.7,
                              color: context.pal.deckInk2,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Text(
                edited
                    ? slide.versionNote
                    : '来源：${slide.source.replaceAll('来源：', '')}',
                style: TextStyle(
                  fontFamily: T0.monoFamily,
                  fontFamilyFallback: T0.monoFallback,
                  fontSize: 7.5,
                  color: context.pal.deckInk2,
                ),
              ),
              const Spacer(),
              Text(
                edited ? '版本 2' : '版本 1',
                style: TextStyle(
                  fontFamily: T0.monoFamily,
                  fontFamilyFallback: T0.monoFallback,
                  fontSize: 7.5,
                  color: context.pal.deckInk2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ 对比
  Future<void> _openCompare(BuildContext context) {
    // 从「前后对比」按钮位置锚点弹出：scale 0.94→1 + fade，220ms enter / 160ms exit
    return Navigator.of(context).push<void>(
      t0DialogRoute<void>(
        context: context,
        barrierLabel: '前后对比',
        scaleFrom: 0.94,
        alignment: _compareOrigin(context),
        builder: (BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: PaperCard(
          floating: true,
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('修改前后对比', style: context.tH2),
                          const SizedBox(height: 4),
                          Text(
                            '当前操作只作用于“${_activeModule.title}”模块，其他模块保持不变。',
                            style: context.tMeta,
                          ),
                        ],
                      ),
                    ),
                    _IconSquare(
                      icon: Icons.close,
                      tooltip: '关闭',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // 两栏按可用宽度平分：整组右端和按钮右端对齐（原来固定 396 宽，
                // 整组比内容区短 52px，右侧多出 77px 留白）
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints box) {
                    final Widget before = T0Enter(
                      duration: T0Motion.dialogIn,
                      offset: const Offset(12, 0),
                      child: _CompareBox(
                        label: '修改前',
                        version: '版本 1',
                        child: _compareSlide(context, before: true),
                      ),
                    );
                    // 右页晚 40ms 进场，两页各带 +12px 横向位移
                    final Widget after = T0Enter(
                      delay: T0Motion.staggerComparePane,
                      duration: T0Motion.dialogIn,
                      offset: const Offset(12, 0),
                      child: _CompareBox(
                        label: '修改后',
                        version: '版本 2',
                        child: _compareSlide(context, before: false),
                      ),
                    );
                    // 窄屏放不下并排两栏时竖排，避免各栏被压到 200px 以下
                    if (box.maxWidth < 700) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          before,
                          const SizedBox(height: 16),
                          after,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: before),
                        const SizedBox(width: 16),
                        Expanded(child: after),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    SecondaryButton(
                      label: '回到上一版',
                      dense: true,
                      onPressed: () {
                        _store.revertEdit(_activeId);
                        Navigator.of(context).pop();
                        showT0Toast(context, '已回到版本 1，修改可以重新应用。');
                      },
                    ),
                    const SizedBox(width: 10),
                    PrimaryButton(
                      label: '保留当前版本',
                      dense: true,
                      onPressed: () {
                        _store.applyEdit(_activeId);
                        Navigator.of(context).pop();
                        showT0Toast(context, '已保留版本 2。');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  /// 弹层缩放的锚点：「前后对比」按钮在屏幕上的相对位置（−1..1）。
  /// 量不到按钮（例如窄屏的图标入口）就退回居中。
  Alignment _compareOrigin(BuildContext context) {
    final RenderObject? box = _compareButtonKey.currentContext?.findRenderObject();
    final Size screen = MediaQuery.sizeOf(context);
    if (box is! RenderBox || !box.hasSize || screen.isEmpty) return Alignment.center;
    final Offset center = box.localToGlobal(box.size.center(Offset.zero));
    return Alignment(
      (center.dx / screen.width * 2 - 1).clamp(-1.0, 1.0),
      (center.dy / screen.height * 2 - 1).clamp(-1.0, 1.0),
    );
  }

  Widget _compareSlide(BuildContext context, {required bool before}) {
    final SlideContent slide = _activeSlide;
    final String title = before ? slide.title : slide.compressedTitle;
    final String accent = before ? slide.accent : slide.compressedAccent;
    return Container(
      color: before ? context.pal.surface : context.pal.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                before ? 't0 / CONTROLLED SLIDES' : '结构压缩版',
                // 与画布上的页眉小标同一套：7px 等宽在这块 396px 宽的缩略预览里
                // 「0」的中孔也糊，一起换成 sans 9px（比画布上的 12px 小一号，
                // 因为这里没有 FittedBox 缩放，1:1 显示）。
                style: TextStyle(
                  fontFamily: T0.sansFamily,
                  fontFamilyFallback: T0.sansFallback,
                  fontSize: 9,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                  color: context.pal.deckInk2,
                ),
              ),
              const Spacer(),
              Text(
                // 与舞台同一套页码写法（r8）：缩略图右上角也写 `t0 / 04`
                _deckPageLabel(slide.number),
                style: TextStyle(
                  fontFamily: T0.sansFamily,
                  fontFamilyFallback: T0.sansFallback,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: context.pal.deckInk2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                fontFamily: T0.serifFamily,
                fontFamilyFallback: T0.serifFallback,
                fontSize: 19,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: context.pal.deckInk,
              ),
              children: <InlineSpan>[
                TextSpan(text: before ? title : title),
                TextSpan(
                  text: accent,
                  style: TextStyle(color: context.pal.deckAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: context.pal.deckLine),
          const SizedBox(height: 8),
          if (before)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int i = 0; i < slide.columns.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i == slide.columns.length - 1 ? 0 : 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            height: 2,
                            // 与 05 舞台同一个色序（首栏 deckAccent），弹层缩略图不再走 ink
                            color: i == 0
                                ? context.pal.deckAccent
                                : (i == 1 ? context.pal.deckWarn : context.pal.deckLilac),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            slide.columns[i].title,
                            style: TextStyle(
                              fontFamily: T0.sansFamily,
                              fontFamilyFallback: T0.sansFallback,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                              color: context.pal.deckInk,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            slide.columns[i].text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: T0.sansFamily,
                              fontFamilyFallback: T0.sansFallback,
                              fontSize: 7.5,
                              height: 1.6,
                              color: context.pal.deckInk2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          else
            Column(
              children: <Widget>[
                for (int i = 0; i < slide.rows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          (i + 1).toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontFamily: T0.monoFamily,
                            fontFamilyFallback: T0.monoFallback,
                            fontSize: 7,
                            color: context.pal.deckAccent,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '${slide.rows[i].title}：${slide.rows[i].text}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: T0.sansFamily,
                              fontFamilyFallback: T0.sansFallback,
                              fontSize: 7.5,
                              height: 1.6,
                              color: context.pal.deckInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ 右栏 AI
  Widget _aiPane(BuildContext context, {required bool compact}) {
    final bool edited = _store.hasEdits(_activeId);
    return Container(
      color: context.pal.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'AI 修改',
                      style: context.tH2.copyWith(fontSize: 18 * context.s),
                    ),
                    const Spacer(),
                    if (compact)
                      _IconSquare(
                        icon: Icons.close,
                        tooltip: '收起',
                        onTap: () => setState(() => _aiOpen = false),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.pal.accentSoft,
                        borderRadius: BorderRadius.circular(T0.pillRadius),
                      ),
                      child: Text(
                        '作用范围：当前模块',
                        style: context.tMeta.copyWith(
                          fontSize: 9.5 * context.s,
                          color: context.pal.accentStrong,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              physics: t0ScrollPhysics(context),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: <Widget>[
                for (final _Message message in _thread) ...<Widget>[
                  _MessageBubble(message: message),
                  const SizedBox(height: 10),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final String chip in _chips)
                      _PromptChip(
                        text: chip,
                        onTap: () {
                          _prompt.text = chip;
                          _prompt.selection = TextSelection.collapsed(
                            offset: chip.length,
                          );
                          showT0Toast(context, '已填入输入框，还没有提交。');
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  edited ? '当前为版本 2，可随时撤销回到版本 1。' : '当前为版本 1，应用修改后会生成版本 2。',
                  style: context.tMeta.copyWith(fontSize: 10 * context.s),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: _prompt,
                  minLines: 2,
                  maxLines: 3,
                  textAlignVertical: TextAlignVertical.top,
                  style: context.tBody.copyWith(
                    fontSize: 12 * context.s,
                    height: 1.7,
                  ),
                  decoration: AppTheme.field(
                    context,
                    hint: '例如：文字太多，压缩成三点；保留“路径连续”作为最重要的一条。',
                    hintMaxLines: 3,
                    padding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 10),
                if (_store.statusOf(_activeId) == ModuleStatus.missing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SecondaryButton(
                      label: '补充并重新生成',
                      dense: true,
                      expand: true,
                      onPressed: () => _apply(supplement: true),
                    ),
                  ),
                Row(
                  children: <Widget>[
                    // 一屏只留一个实心主按钮（左栏的「交付检查」）；
                    // 「应用修改」是同级动作，改描边样式，避免两块绿互相抢
                    Expanded(
                      child: SecondaryButton(
                        label: '应用修改',
                        dense: true,
                        expand: true,
                        onPressed: () => _apply(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SecondaryButton(
                        label: '确认本模块',
                        dense: true,
                        expand: true,
                        onPressed: () {
                          _store.setStatus(_activeId, ModuleStatus.done);
                          showT0Toast(
                            context,
                            '「${_activeModule.title}」已确认，进度 ${_store.confirmedCount}/${_store.total}。',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawer(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            onTap: () => setState(() => _aiOpen = false),
            child: Container(color: context.pal.scrim.withValues(alpha: 0.28)),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: 340,
          child: Material(
            color: context.pal.surface,
            elevation: 8,
            child: _aiPane(context, compact: true),
          ),
        ),
      ],
    );
  }

  Future<void> _apply({bool supplement = false}) async {
    final String text = _prompt.text.trim();
    if (text.isEmpty) {
      showT0Toast(context, '先写一句修改要求，或点一个建议 chip。');
      return;
    }
    setState(() {
      _loading = true;
      _thread.add(_Message(author: '我', text: text));
    });
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    _store.applyEdit(_activeId);
    if (_store.statusOf(_activeId) == ModuleStatus.missing) {
      _store.setStatus(_activeId, ModuleStatus.review);
    }
    setState(() {
      _loading = false;
      _thread.add(
        _Message(
          author: 't0 copilot',
          text: supplement
              ? '已按“$text”补充当前模块，结论页标记为待确认，其余模块没有改动。'
              : '已按“$text”重写当前模块的 ${_activeModule.pages} 页，其他模块未改动。',
        ),
      );
      _prompt.clear();
    });
    showT0Toast(context, '已应用到当前模块，其他模块未改动。');
  }
}

// ------------------------------------------------------------------ 小组件
class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.module,
    required this.status,
    required this.active,
    required this.pagesText,
    required this.onTap,
    this.boxKey,
  });

  final ProjectModule module;
  final ModuleStatus status;
  final bool active;
  final String pagesText;
  final VoidCallback onTap;

  /// 给高亮条量尺用的 key（量的是这块 Container，不含上下间距）
  final Key? boxKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            key: boxKey,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              // 透明描边不是装饰：它和原来一样占 1px 内边距，
              // 选中行的高亮改由上面那条滑动的面来画。去掉这行会让每行矮 2px、窄 2px。
              border: Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 18,
                  child: Text(
                    module.number,
                    style: context.tMono.copyWith(fontSize: 9.5 * context.s),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        module.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tBody.copyWith(
                          fontSize: 12 * context.s,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pagesText,
                        style: context.tMeta.copyWith(
                          fontSize: 9.5 * context.s,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                StatusDot(status: status, size: 7),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarProgress extends StatelessWidget {
  const _BarProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    // 整条是可见的进度轨道（context.pal.line），绿色是已完成段；
    // 原来轨道用 canvas 色几乎看不见，只剩 60% 的绿线，像标题下方没加载完的下划线
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 3,
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: ColoredBox(color: context.pal.line)),
            FractionallySizedBox(
              widthFactor: value.clamp(0, 1).toDouble(),
              child: Container(height: 3, color: context.pal.accentFill),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconSquare extends StatefulWidget {
  const _IconSquare({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.dense = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool dense;

  @override
  State<_IconSquare> createState() => _IconSquareState();
}

class _IconSquareState extends State<_IconSquare> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final double size = widget.dense ? 24 : 30;
    final Widget button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? context.pal.bg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            widget.icon,
            size: widget.dense ? 13 : 15,
            color: _hover ? context.pal.ink : context.pal.ink2,
          ),
        ),
      ),
    );
    final Widget ringed = T0FocusRing(radius: 8, onActivate: widget.onTap, child: button);
    if (widget.tooltip == null) return ringed;
    return Tooltip(message: widget.tooltip!, child: ringed);
  }
}

class _HoldCompare extends StatefulWidget {
  const _HoldCompare({required this.active, required this.onChanged});

  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  State<_HoldCompare> createState() => _HoldCompareState();
}

class _HoldCompareState extends State<_HoldCompare> {
  @override
  Widget build(BuildContext context) {
    // 只有「按下 → 松开」两件事控制状态：
    // · 不用 MouseRegion.onEnter/onExit —— 鼠标划过就切版本，用户根本没按住；
    // · 用 Listener 而不是 GestureDetector —— 指针按下时 Flutter 把后续事件
    //   固定派发给同一路命中结果，所以按住后拖出按钮再松手，onPointerUp 仍会到达，
    //   状态不会卡在「修改前」；右键按下也一样（PointerDownEvent 不区分按键）。
    // 按下态文案会从「按住看修改前」换成「修改前」。文案一变，按钮宽度就从 110 缩到 78，
    // 右对齐时左边界右移 32px —— 手指按下去的地方按钮在缩。这里用 Stack 垫一层
    // 透明的长文案占位：两种状态宽度都按最长那句排，按下只换底色 / 描边，不动几何。
    final TextStyle labelStyle = context.tMeta.copyWith(
      fontSize: 10.5 * context.s,
      color: widget.active ? context.pal.surface : context.pal.ink2,
    );
    return Listener(
      onPointerDown: (_) => widget.onChanged(true),
      onPointerUp: (_) => widget.onChanged(false),
      onPointerCancel: (_) => widget.onChanged(false),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: T0Motion.dur(context, T0Motion.hint),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.active ? context.pal.ink : context.pal.bg,
            borderRadius: BorderRadius.circular(T0.pillRadius),
            border: Border.all(color: widget.active ? context.pal.ink : context.pal.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.visibility_outlined,
                size: 13,
                color: widget.active ? context.pal.surface : context.pal.ink2,
              ),
              const SizedBox(width: 6),
              Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  if (widget.active)
                    Opacity(
                      opacity: 0,
                      child: Text('按住看修改前', style: labelStyle),
                    ),
                  Text(widget.active ? '修改前' : '按住看修改前', style: labelStyle),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 按住期间画布上方的一行提示：不遮挡内容、不接指针，
/// 只说明「现在看的是修改前」，与「前后对比」的弹层区分开。
class _HoldHint extends StatelessWidget {
  const _HoldHint({super.key});

  @override
  Widget build(BuildContext context) {
    // 16px 高的细胶囊：卡在画布顶部内边距（28px）里，不压卡面（审图 P2-⑤）
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      decoration: BoxDecoration(
        color: context.pal.accentSoft,
        borderRadius: BorderRadius.circular(T0.pillRadius),
        border: Border.all(color: context.pal.accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        '正在看修改前',
        style: context.tMeta.copyWith(
          fontSize: 10 * context.s,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: context.pal.accentStrong,
        ),
      ),
    );
  }
}

class _BriefChip extends StatelessWidget {
  const _BriefChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.pal.bg,
        borderRadius: BorderRadius.circular(T0.pillRadius),
        border: Border.all(color: context.pal.line),
      ),
      child: Text(
        text,
        style: context.tMeta.copyWith(fontSize: 10 * context.s),
      ),
    );
  }
}

class _Message {
  const _Message({required this.author, required this.text});

  final String author;
  final String text;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final bool user = message.author == '我';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: user ? context.pal.accentSoft : context.pal.bg,
        borderRadius: BorderRadius.circular(T0.innerRadius),
        border: Border.all(
          color: user ? context.pal.accent.withValues(alpha: 0.18) : context.pal.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            // 品牌小写：与顶栏 t0 一致，不再出现大写 TO COPILOT
            message.author,
            style: context.tMono.copyWith(
              fontSize: 8 * context.s,
              letterSpacing: 1.2,
              // t0 copilot 这行 8px mono：浅色底上用 stepMuted（4.95），别再落到 ink2 的 4.40
              color: user ? context.pal.accentStrong : context.pal.stepMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message.text,
            style: context.tBody.copyWith(
              fontSize: 12 * context.s,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptChip extends StatefulWidget {
  const _PromptChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  State<_PromptChip> createState() => _PromptChipState();
}

class _PromptChipState extends State<_PromptChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: T0Motion.dur(context, T0Motion.hint),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hover ? context.pal.accentSoft : context.pal.surface,
            borderRadius: BorderRadius.circular(T0.pillRadius),
            border: Border.all(
              color: _hover ? context.pal.accent.withValues(alpha: 0.45) : context.pal.line,
            ),
          ),
          child: Text(
            widget.text,
            style: context.tMeta.copyWith(
              fontSize: 10 * context.s,
              color: _hover ? context.pal.accentStrong : context.pal.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompareBox extends StatelessWidget {
  const _CompareBox({
    required this.label,
    required this.version,
    required this.child,
  });

  final String label;
  final String version;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 宽度交给父级（弹层里是 Expanded，两栏平分可用宽度）
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: <Widget>[
              Text(
                label,
                style: context.tBody.copyWith(
                  fontSize: 11.5 * context.s,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // 版本号跟紧自己的标签（原来用 Spacer 顶到右端，两栏只隔 28px，
              // 顺读成了「版本 1 修改后」—— 审图 14:40 第 3 条）
              const SizedBox(width: 8),
              Text(
                version,
                style: context.tMono.copyWith(fontSize: 9 * context.s),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.pal.canvas,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.pal.line),
          ),
          padding: const EdgeInsets.all(10),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(width: 720, height: 405, child: child),
            ),
          ),
        ),
      ],
    );
  }
}

/// 生成中的画布骨架：两张与真实幻灯片同尺寸的纸板 + 斜向高光带。
///
/// 底色用 palette 里最浅的纸色（surface），条块用 canvas —— 不用灰。
/// 高光带由 [T0ShimmerBand] 一帧一画，骨架本身不重建。
class _CanvasSkeleton extends StatelessWidget {
  const _CanvasSkeleton({required this.zoom, required this.child});

  final double zoom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    final double width = 720 * zoom;
    final double height = 405 * zoom;
    return ColoredBox(
      color: pal.bg.withValues(alpha: 0.78),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: <Widget>[
                  _SkeletonSlide(
                    zoom: zoom,
                    width: width,
                    height: height,
                    rows: 0,
                  ),
                  const SizedBox(height: 20),
                  _SkeletonSlide(
                    zoom: zoom,
                    width: width,
                    height: height,
                    rows: 3,
                  ),
                ],
              ),
            ),
          ),
          Center(child: child),
        ],
      ),
    );
  }
}

class _SkeletonSlide extends StatelessWidget {
  const _SkeletonSlide({
    required this.zoom,
    required this.width,
    required this.height,
    required this.rows,
  });

  final double zoom;
  final double width;
  final double height;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    // 条块分两档（B5）：标题短（0.22/0.40）、正文长（0.72~0.56）。
    // 两条 shimmer 的盒子宽度差 2~3 倍，同一个 1.2s 周期下横扫速度
    // （px/s = 3 × 盒宽 / 周期）自然与条块宽度成正比 —— 长条扫得快，
    // 短条扫得慢，视觉上像同一道光从上往下走过，而不是几条各自闪。
    final Widget titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _bar(pal, width * 0.22, 8 * zoom),
        SizedBox(height: 14 * zoom),
        _bar(pal, width * 0.40, 18 * zoom),
      ],
    );
    final Widget bodyBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 封面骨架（rows == 0）也留一条长条：两档宽度的对比在两张板上都成立
        for (int i = 0; i < (rows == 0 ? 1 : rows); i++) ...<Widget>[
          _bar(pal, width * (0.72 - i * 0.08), 6 * zoom),
          SizedBox(height: 8 * zoom),
        ],
      ],
    );
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(28 * zoom),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: T0ShimmerBand(child: titleBlock),
          ),
          const Spacer(),
          T0ShimmerBand(child: bodyBlock),
        ],
      ),
    );
  }

  Widget _bar(T0Palette pal, double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: pal.canvas,
          borderRadius: BorderRadius.circular(3),
        ),
      );
}
