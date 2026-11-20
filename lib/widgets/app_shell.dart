import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/mock_data.dart';
import '../theme/palette.dart';
import '../theme/theme_controller.dart';
import '../theme/tokens.dart';
import 'paper_background.dart';
import 'primary_button.dart';
import 'section_label.dart';

/// 流程步骤：材料输入 → 大纲确认 → 模块制作 → 交付检查。
enum FlowStep {
  input(1, '材料输入'),
  outline(2, '大纲确认'),
  modules(3, '模块制作'),
  delivery(4, '交付检查');

  const FlowStep(this.order, this.label);

  final int order;
  final String label;
}

/// 五步流程的路由白名单：只有落在这些路由上，顶栏才认为「人在项目里」。
///
/// 工作台（[`/workbench`]、`/`）和未知路由都不在其中 —— 顶栏右侧只留
/// 主题按钮 + 加号，不再显示项目名与「已自动保存」。
const Set<String> kProjectRoutes = <String>{
  '/intake',
  '/outline',
  '/modules',
  '/workspace',
  '/delivery',
};

/// 当前路由是不是「在项目里」。
///
/// 判断依据是 `ModalRoute.settings.name`（由 main.dart 的 onGenerateRoute 写入），
/// 不是页面自己 setState 传下来的布尔：每个流程页各自建一棵 AppShell，路由名
/// 天然跟着页面走，从项目返回工作台时工作台那棵树从来没有显示过这一块，
/// 也就不存在「残留」。
bool inProjectRoute(BuildContext context) {
  final String? name = ModalRoute.of(context)?.settings.name;
  if (name == null) return false;
  return kProjectRoutes.contains(name);
}

/// 页面骨架：顶部导航 + 步骤条 + 纸底内容区 + 响应式断点注入。
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    this.activeNav,
    this.step,
    this.showStep = false,
    this.flush = false,
  });

  final Widget child;

  /// 当前导航项路由名，用于高亮
  final String? activeNav;

  /// 非空时显示步骤条
  final FlowStep? step;

  /// true：即使 step 为 null 也占住步骤条的高度（工作台用它，避免切页整体跳 48px）
  final bool showStep;

  /// true：内容自己管理滚动（模块工作区三栏）
  final bool flush;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 1440;
        return T0Metrics(
          width: width,
          child: Scaffold(
            backgroundColor: context.pal.bg,
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  _TopBar(activeNav: activeNav),
                  if (step != null || showStep) _StepBar(current: step),
                  Expanded(child: PaperBackground(child: child)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ 顶部导航
class _TopBar extends StatelessWidget {
  const _TopBar({this.activeNav});

  final String? activeNav;

  @override
  Widget build(BuildContext context) {
    final T0Metrics m = context.metrics;
    final T0Palette pal = context.pal;
    return Container(
      key: const Key('topbar'),
      height: m.isMobile ? 58 : 72,
      padding: EdgeInsets.symmetric(horizontal: m.isMobile ? 14 : 24),
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border(bottom: BorderSide(color: pal.line)),
      ),
      child: m.isMobile
          ? _buildMobile(context)
          : m.isDesktop
          ? _buildDesktop(context)
          : _buildTablet(context),
    );
  }

  /// 右侧「在项目里」这一整块（项目名 + 已自动保存）。
  ///
  /// 不在项目路由上时返回空列表，连间距一起省略 —— 删完头像后右侧只剩
  /// 主题按钮 + 加号，不会留一段空白。元素都是右对齐的（前面有 Spacer 吃空间），
  /// 所以这块出现 / 消失时，右边的按钮不会横向跳动。
  List<Widget> _projectSegment(BuildContext context) {
    if (!inProjectRoute(context)) return const <Widget>[];
    return <Widget>[
      Text(
        T0Store.instance.projectName,
        key: const Key('topbar-project-name'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.tBody.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(width: T0.s16),
      const _SaveState(key: Key('topbar-save')),
      const SizedBox(width: T0.s16),
    ];
  }

  Widget _buildDesktop(BuildContext context) {
    return Row(
      children: <Widget>[
        const _BrandMark(),
        const SizedBox(width: 14),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '办公',
              style: context.tH3.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
            Text(
              'CONTROLLED AI SLIDES',
              style: context.tMono.copyWith(
                fontSize: 8,
                letterSpacing: 1.8,
                color: context.pal.muted,
              ),
            ),
          ],
        ),
        const SizedBox(width: 32),
        _NavSegmented(activeNav: activeNav),
        const Spacer(),
        // 右侧固定顺序：项目名 / 已自动保存 / 主题按钮 / 加号，相邻间距统一 16px
        ..._projectSegment(context),
        const _ThemeToggle(key: Key('topbar-theme')),
        const SizedBox(width: T0.s16),
        _RoundIconButton(
          key: const Key('topbar-add'),
          icon: Icons.add,
          tooltip: '新建项目',
          onTap: () => go(context, '/intake'),
        ),
      ],
    );
  }

  Widget _buildTablet(BuildContext context) {
    return Row(
      children: <Widget>[
        const _BrandMark(),
        const SizedBox(width: 12),
        Text(
          '办公',
          style: context.tH3.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
        const Spacer(),
        _NavSegmented(activeNav: activeNav, compact: true),
        const SizedBox(width: T0.s16),
        ..._projectSegment(context),
        const _ThemeToggle(key: Key('topbar-theme')),
        const SizedBox(width: T0.s16),
        _RoundIconButton(
          key: const Key('topbar-add'),
          icon: Icons.add,
          tooltip: '新建项目',
          onTap: () => go(context, '/intake'),
        ),
      ],
    );
  }

  Widget _buildMobile(BuildContext context) {
    final bool inProject = inProjectRoute(context);
    return Row(
      children: <Widget>[
        const _BrandMark(),
        if (inProject) ...<Widget>[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              T0Store.instance.projectName,
              key: const Key('topbar-project-name'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tBody.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const StatusDotPulse(),
          const SizedBox(width: 10),
        ] else
          const Spacer(),
        const _ThemeToggle(key: Key('topbar-theme')),
        const SizedBox(width: 8),
        _RoundIconButton(
          key: const Key('topbar-add'),
          icon: Icons.menu,
          tooltip: '菜单',
          onTap: () => _showMenu(context),
        ),
      ],
    );
  }

  void _showMenu(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: context.pal.scrim.withValues(alpha: 0.35),
      builder: (BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        alignment: Alignment.topRight,
        insetPadding: const EdgeInsets.only(top: 70, right: 12, left: 12),
        child: PaperCard(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          floating: true,
          width: 230,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _MenuRow(
                icon: Icons.home_outlined,
                label: '工作台',
                onTap: () {
                  Navigator.of(context).pop();
                  go(context, '/workbench');
                },
              ),
              _MenuRow(
                icon: Icons.grid_view_outlined,
                label: '当前项目',
                onTap: () {
                  Navigator.of(context).pop();
                  go(context, '/workspace');
                },
              ),
              _MenuRow(
                icon: Icons.help_outline,
                label: '帮助',
                onTap: () {
                  Navigator.of(context).pop();
                  showHelpDialog(context);
                },
              ),
              const Divider(height: 12),
              _MenuRow(
                icon: Icons.add,
                label: '从材料开始新建',
                onTap: () {
                  Navigator.of(context).pop();
                  go(context, '/intake');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 16, color: pal.muted),
            const SizedBox(width: 10),
            Text(
              label,
              style: context.tBody.copyWith(fontSize: 13, color: pal.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pal.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: pal.ink, width: 1.2),
      ),
      child: Text(
        't0',
        style: TextStyle(
          fontFamily: T0.serifFamily,
          fontFamilyFallback: T0.serifFallback,
          fontSize: 15,
          height: 1,
          fontWeight: FontWeight.w700,
          color: pal.ink,
        ),
      ),
    );
  }
}

class _NavSegmented extends StatelessWidget {
  const _NavSegmented({this.activeNav, this.compact = false});

  final String? activeNav;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: pal.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pal.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _NavItem(
            icon: Icons.home_outlined,
            label: '工作台',
            active: activeNav == '/workbench',
            compact: compact,
            onTap: () => go(context, '/workbench'),
          ),
          _NavItem(
            icon: Icons.grid_view_outlined,
            label: '当前项目',
            active: activeNav == '/workspace',
            compact: compact,
            onTap: () => go(context, '/workspace'),
          ),
          _NavItem(
            icon: Icons.help_outline,
            label: '帮助',
            active: false,
            compact: compact,
            onTap: () => showHelpDialog(context),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    final bool active = widget.active;
    final bool compact = widget.compact;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: context.anim(const Duration(milliseconds: 140)),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            // hover 用整块 surface + line 描边（和 active 同形但字重不变），
            // 截图里能明确看出悬停反馈
            color: active || _hover ? pal.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: active || _hover ? pal.line : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                widget.icon,
                size: 14,
                color: active || _hover ? pal.ink : pal.muted,
              ),
              if (!compact) ...<Widget>[
                const SizedBox(width: 7),
                Text(
                  widget.label,
                  style: context.tBody.copyWith(
                    fontSize: 12,
                    color: active || _hover ? pal.ink : pal.muted,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveState extends StatelessWidget {
  const _SaveState({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: context.pal.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text('已自动保存', style: context.tMeta.copyWith(fontSize: 11)),
      ],
    );
  }
}

/// 移动端顶栏的绿点。
class StatusDotPulse extends StatelessWidget {
  const StatusDotPulse({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: context.pal.accent, shape: BoxShape.circle),
    );
  }
}

/// 白天 / 黑夜切换：36px 圆形按钮，太阳 ↔ 月亮交叉淡入。
/// 位置：顶部导航右侧、加号左边（r3 删掉头像组后最右一组是 主题 / 加号）。
///
/// 图标是 **CustomPaint 自绘**，不是 `Icons.light_mode_outlined`：
/// Windows release 的增量构建会沿用 `build/.../fonts/MaterialIcons-Regular.otf`
/// 里的旧子集（图标字体不随 Dart 代码变化而失效），一旦那个子集里没有
/// 0xf162 / 0xef9f，按钮就只剩一个空的描边圆 —— 也就是 P1 里那个「白天模式空圆圈」。
/// 自绘之后这条字体链路彻底断掉，任何构建方式都能画出太阳 / 月亮。
class _ThemeToggle extends StatefulWidget {
  const _ThemeToggle({super.key});

  @override
  State<_ThemeToggle> createState() => _ThemeToggleState();
}

class _ThemeToggleState extends State<_ThemeToggle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    final ThemeController controller = T0Theme.of(context);
    final bool dark = controller.isDark;
    return Tooltip(
      message: dark ? '切换到白天' : '切换到黑夜',
      waitDuration: const Duration(milliseconds: 240),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: controller.toggle,
          child: AnimatedContainer(
            duration: context.anim(const Duration(milliseconds: 140)),
            width: T0.iconButtonSize,
            height: T0.iconButtonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hover ? pal.bg : Colors.transparent,
              border: Border.all(color: _hover ? pal.lineStrong : pal.line),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _ThemeGlyph(
                key: ValueKey<String>(dark ? 'theme-glyph-moon' : 'theme-glyph-sun'),
                dark: dark,
                color: _hover ? pal.ink : pal.ink2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 16px 的太阳 / 月亮，两笔就够：自绘，不读任何图标字体。
class _ThemeGlyph extends StatelessWidget {
  const _ThemeGlyph({super.key, required this.dark, required this.color});

  final bool dark;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(16),
      painter: _ThemeGlyphPainter(dark: dark, color: color),
    );
  }
}

class _ThemeGlyphPainter extends CustomPainter {
  const _ThemeGlyphPainter({required this.dark, required this.color});

  final bool dark;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 全部按 16×16 的比例算，尺寸变了也等比缩放
    final double u = size.shortestSide / 16;
    final Offset c = Offset(size.width / 2, size.height / 2);
    final Paint paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    if (dark) {
      // 月亮：大圆减掉偏移的小圆 = 月牙
      final Path moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: c, radius: 6.9 * u)),
        Path()..addOval(
          Rect.fromCircle(
            center: c + Offset(3.4 * u, -3.6 * u),
            radius: 6.3 * u,
          ),
        ),
      );
      canvas.drawPath(moon, paint);
      return;
    }

    // 太阳：实心圆心 + 8 条光芒
    canvas.drawCircle(c, 3.05 * u, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25 * u
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final double a = i * math.pi / 4;
      final Offset dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * (4.9 * u), c + dir * (6.9 * u), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ThemeGlyphPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.color != color;
}

class _RoundIconButton extends StatefulWidget {
  const _RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<_RoundIconButton> createState() => _RoundIconButtonState();
}

class _RoundIconButtonState extends State<_RoundIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    final Widget button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: context.anim(const Duration(milliseconds: 140)),
          width: T0.iconButtonSize,
          height: T0.iconButtonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover ? pal.bg : Colors.transparent,
            border: Border.all(color: _hover ? pal.lineStrong : pal.line),
          ),
          child: Icon(widget.icon, size: 16, color: pal.ink),
        ),
      ),
    );
    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}

// ------------------------------------------------------------------ 步骤条
/// 细线式流程步骤条：不铺底色，与内容区同宽（左右 96），只占 48px 高度。
/// 工作台传入 current == null，整条置灰占位，切页时内容不会整体跳。
class _StepBar extends StatelessWidget {
  const _StepBar({required this.current});

  final FlowStep? current;

  @override
  Widget build(BuildContext context) {
    final T0Metrics m = context.metrics;
    final T0Palette pal = context.pal;
    final List<Widget> children = <Widget>[];
    for (final FlowStep step in FlowStep.values) {
      final int state = current == null
          ? -1
          : step.order.compareTo(current!.order);
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _StepDot(step: step, state: state),
            const SizedBox(width: 8),
            Text(
              step.label,
              style: context.tBody.copyWith(
                fontSize: 12 * (m.isMobile ? 0.95 : 1),
                color: step == current
                    ? pal.accent
                    : (state > 0 ? pal.ink : pal.stepMuted),
                fontWeight: step == current ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      );
      if (step != FlowStep.values.last) {
        children.add(
          Container(
            width: m.isMobile ? 22 : 64,
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: current == null
                ? pal.line
                : (state < 0 ? pal.lineStrong : pal.line),
          ),
        );
      }
    }

    return Container(
      height: m.isMobile ? 44 : 48,
      color: pal.bg,
      padding: EdgeInsets.symmetric(horizontal: m.gutter),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: T0.maxContentWidth),
          child: SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: children),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.step, required this.state});

  final FlowStep step;

  /// >0 已完成，0 当前，<0 未开始
  final int state;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    final bool active = state == 0;
    final bool done = state > 0;
    // 未开始的圈也要看得见：以前描边用 line（白天 1.32:1，几乎等于没有），
    // 数字用 muted；现在两者都走 stepMuted，圈和数字一起 ≥4.9。
    final Color border = active || done ? pal.accent : pal.stepMuted;
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // 小圆点也是填充：过渡里用 accentFill，字用 onFill（和主按钮同一套）
        color: active ? pal.accentFill : Colors.transparent,
        border: Border.all(color: border, width: 1.2),
      ),
      child: Text(
        '${step.order}',
        style: TextStyle(
          fontFamily: T0.sansFamily,
          fontFamilyFallback: T0.sansFallback,
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w600,
          color: active
              ? T0Palette.onFill(pal.accentFill)
              : (done ? pal.accent : pal.stepMuted),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 页头
/// 流程页头：eyebrow + h1 + 右侧说明段。
class FlowHead extends StatelessWidget {
  const FlowHead({
    super.key,
    required this.eyebrow,
    required this.title,
    this.note,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String? note;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final T0Metrics m = context.metrics;
    final Widget heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionLabel(text: eyebrow),
        const SizedBox(height: 14),
        Text(title, style: context.tH1),
      ],
    );

    if (m.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          heading,
          if (note != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(note!, style: context.tMeta.copyWith(height: 1.6)),
          ],
          if (trailing != null) ...<Widget>[
            const SizedBox(height: 12),
            trailing!,
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(child: heading),
        if (note != null) ...<Widget>[
          const SizedBox(width: 40),
          SizedBox(
            width: m.isDesktop ? 380 : 280,
            // 说明段落与主标题按「最后一行基线」对齐：
            // h1 行高 42、note 行高 1.7×12，底对齐后 note 基线还差 2px，这里补掉。
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                note!,
                textAlign: TextAlign.right,
                // 浅色底上次级说明统一 stepMuted（白天 4.95 / 黑夜 7.36），不留 4.40 的特例
                style: context.tMeta.copyWith(
                  height: 1.7,
                  color: context.pal.stepMuted,
                ),
              ),
            ),
          ),
        ],
        if (trailing != null) ...<Widget>[const SizedBox(width: 20), trailing!],
      ],
    );
  }
}

// ------------------------------------------------------------------ 页面容器
/// 标准页面内容：独立滚动、最大宽 1360、左右留白 96。
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.children,
    this.maxWidth = T0.maxContentWidth,
    this.top = 44,
    this.bottom = 56,
  });

  final List<Widget> children;
  final double maxWidth;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final T0Metrics m = context.metrics;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(m.gutter, top, m.gutter, bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// 卡片：18 圆角、1px line、浮起时才加阴影。
/// 颜色默认取主题 surface / line，阴影也来自调色板（深色里是更黑的扩散，不是亮边）。
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.floating = false,
    this.color,
    this.borderColor,
    this.radius = T0.cardRadius,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool floating;

  /// 不传就跟随主题（floating 时用 surface2）
  final Color? color;
  final Color? borderColor;
  final double radius;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final T0Palette pal = context.pal;
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (floating ? pal.surface2 : pal.surface),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? pal.line),
        boxShadow: floating ? pal.floatShadow : null,
      ),
      child: child,
    );
  }
}

// ------------------------------------------------------------------ 导航与提示
void go(BuildContext context, String route) {
  Navigator.of(context).pushNamed(route);
}

void showHelpDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: context.pal.scrim.withValues(alpha: 0.35),
    builder: (BuildContext context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: PaperCard(
        width: 520,
        floating: true,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SectionLabel(text: 'Help · 使用说明'),
            const SizedBox(height: 12),
            Text('五步走完一次汇报', style: context.tH2),
            const SizedBox(height: 12),
            Text(
              '材料输入 → 大纲确认 → 模块拆分 → 模块制作 → 交付检查。'
              '每一次修改只作用在当前模块，其他模块保持不动；'
              '材料不足时系统不会编造结论，而是标记为「待补充」。',
              style: context.tBody.copyWith(fontSize: 13, color: context.pal.muted),
            ),
            const SizedBox(height: 16),
            const _HelpRow(label: '页面切换', text: '主按钮推进流程，240ms 淡入 + 上移 8px'),
            const _HelpRow(label: '模块状态', text: '点状态胶囊可在已确认 / 待确认 / 待补充之间切换'),
            const _HelpRow(label: '前后对比', text: '工作区里按住「按住查看修改前」，或点「前后对比」看两版'),
            const _HelpRow(label: '导出', text: '交付检查底部按钮，未完成模块会被明确列出'),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 120,
                child: PrimaryButton(
                  label: '知道了',
                  dense: true,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HelpRow extends StatelessWidget {
  const _HelpRow({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: context.tMeta.copyWith(
                color: context.pal.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(text, style: context.tMeta.copyWith(height: 1.6)),
          ),
        ],
      ),
    );
  }
}

OverlayEntry? _toastEntry;

/// 底部居中轻提示。
void showT0Toast(BuildContext context, String message) {
  if (_toastEntry != null && _toastEntry!.mounted) {
    _toastEntry!.remove();
  }
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  final OverlayEntry entry = OverlayEntry(
    builder: (BuildContext context) {
      final T0Palette pal = context.pal;
      return Positioned(
        left: 16,
        right: 16,
        bottom: 36,
        child: IgnorePointer(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: pal.ink,
                borderRadius: BorderRadius.circular(T0.pillRadius),
                boxShadow: pal.floatShadow,
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: T0.sansFamily,
                  fontFamilyFallback: T0.sansFallback,
                  fontSize: 13,
                  height: 1.4,
                  color: pal.surface,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  _toastEntry = entry;
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 2400), () {
    if (entry.mounted) {
      entry.remove();
    }
    if (identical(_toastEntry, entry)) {
      _toastEntry = null;
    }
  });
}
