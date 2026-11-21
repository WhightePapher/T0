import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 双主题调色板。
///
/// 所有颜色都必须从这里取（`context.pal.xxx`），页面里禁止出现裸十六进制：
/// 只有挂成 ThemeExtension 的颜色才能被 AnimatedTheme 逐字段 lerp 出中间态。
///
/// 三组字段，切换时的行为不一样（见 [lerp]）：
///
/// * **面**（底色 / 卡片 / 描边 / 阴影 / soft 底）：按 420ms 曲线插值；
/// * **前景**（文字 / 图标）：不插值，在 [foregroundSwitch]（35%，≈186ms）**直接切换**；
///   另外在中灰段把前景收到**亮度极值**（白天侧纯黑、黑夜侧纯白）——
///   中灰底上和任何主题色都会糊成一片（accident: #147A62 on #777077 = 1.09:1），
///   黑白两端才能守住 4.5:1；
/// * **deck**（幻灯片画布、封面、内容页）：两套主题**完全相同**。
///   画布是「导出物预览」，不跟着应用外壳变深，否则预览不再代表导出的 PPT。
class T0Palette extends ThemeExtension<T0Palette> {
  const T0Palette({
    required this.bg0,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.canvas,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.line,
    required this.lineSoft,
    required this.lineStrong,
    required this.accent,
    required this.accentStrong,
    required this.accentFill,
    required this.accentStrongFill,
    required this.accentSoft,
    required this.onAccent,
    required this.lilac,
    required this.lilacSoft,
    required this.ok,
    required this.warn,
    required this.warnSoft,
    required this.danger,
    required this.dangerSoft,
    required this.grid,
    required this.scrim,
    required this.shadow,
    required this.shadowSoft,
    required this.deckBg,
    required this.deckPaper,
    required this.deckInk,
    required this.deckInk2,
    required this.deckLine,
    required this.deckAccent,
    required this.deckAccentSoft,
    required this.deckDanger,
    required this.deckDangerSoft,
    required this.deckWarn,
    required this.deckLilac,
    required this.deckCover,
    required this.deckCoverInk,
    required this.deckCoverAccent,
    required this.deckShadow,
    this.transitioning = false,
  });

  // ------------------------------------------------------------ 底色阶梯
  /// 最深：页面最底、画布凹槽
  final Color bg0;

  /// 页面主体背景
  final Color bg;

  /// 卡片
  final Color surface;

  /// 浮起卡片 / 抽屉
  final Color surface2;

  /// 画布凹槽 / 进度轨道 / 按钮按下态
  final Color canvas;

  // ------------------------------------------------------------ 文字
  /// 主文字 / 标题
  final Color ink;

  /// 次级文字
  final Color ink2;

  /// 说明文字（三级，只在 bg / canvas 上用，卡片上用 ink2 保证对比度）
  final Color muted;

  // ------------------------------------------------------------ 线
  final Color line;
  final Color lineSoft;

  /// 强分隔线 / hover 描边 / 虚线框
  final Color lineStrong;

  // ------------------------------------------------------------ 强调
  /// 主 CTA / 进度 / 已确认（深底版绿）
  final Color accent;

  /// 绿色在 soft 底上的文字色，以及主按钮 hover / pressed
  final Color accentStrong;

  /// **填充专用**：主按钮底色 / 环形进度 / 进度条这一类的「面」。
  ///
  /// 为什么不直接用 [accent]：`accent` 是前景色，lerp 时会被兜底收向亮度极值
  /// （过渡中段变纯黑 / 纯白，见 [guardFor]）。当它是 36px 圆的描边、图标还看不出来，
  /// 但主按钮拿它当**整块底色填充**时，CTA 会在 105–120ms 变成纯黑、210ms 变成纯白，
  /// 整页闪两下。这两个字段走和 bg / surface 一样的 420ms 连续插值，不经过 anchor。
  final Color accentFill;
  final Color accentStrongFill;

  /// 绿的低饱和底
  final Color accentSoft;

  /// 主按钮上的文字色（深底主题里绿底需要深字才够对比度）
  final Color onAccent;

  /// 紫色点缀：条目标记、选中态、hover、次强调
  final Color lilac;
  final Color lilacSoft;

  // ------------------------------------------------------------ 状态
  final Color ok;
  final Color warn;
  final Color warnSoft;
  final Color danger;
  final Color dangerSoft;

  // ------------------------------------------------------------ 画面
  /// 背景网格线（深色下取 lineSoft、透明度比白天更低）
  final Color grid;

  /// 弹层遮罩（白天用墨色，黑夜用纯黑，避免深色主题里遮罩发白）
  final Color scrim;

  // ------------------------------------------------------------ 阴影
  /// 浮起卡片：0 18px 60px
  final Color shadow;

  /// 选中行：0 4px 12px
  final Color shadowSoft;

  // ------------------------------------------------------------ 画布 / 幻灯片（两套主题相同）
  /// 画布区底色（工作区中栏）
  final Color deckBg;

  /// 幻灯片内容页（纸白）
  final Color deckPaper;

  /// 幻灯片上的主文字
  final Color deckInk;

  /// 幻灯片上的次级文字
  final Color deckInk2;

  /// 幻灯片上的分隔线
  final Color deckLine;

  /// 幻灯片上的品牌绿
  final Color deckAccent;
  final Color deckAccentSoft;
  final Color deckDanger;
  final Color deckDangerSoft;
  final Color deckWarn;
  final Color deckLilac;

  /// 深绿封面页
  final Color deckCover;
  final Color deckCoverInk;
  final Color deckCoverAccent;

  /// 封面页投影
  final Color deckShadow;

  /// 主题渐变进行中（0 < t < 1）。
  ///
  /// 组件自己的 AnimatedContainer 必须让路：它每帧都在追一个移动的目标色，
  /// 会永远落后 ~150ms，切完之后底色和文字色对不上（315ms 帧实测 2.75:1）。
  final bool transitioning;

  // ------------------------------------------------------------ 阴影组合
  /// 更深的次级字：给 10~11px 的说明小字用（细笔画抗锯齿后会掉对比度）。
  /// 白天 = ink2 往 ink 靠一半（#3F4A47，卡面上 9.0:1），黑夜同理提亮。
  Color get ink2Strong => Color.lerp(ink2, ink, 0.5)!;

  /// WCAG 相对亮度
  static double _lum(Color c) => c.computeLuminance();

  /// WCAG 对比度
  static double ratio(Color a, Color b) {
    final double la = _lum(a);
    final double lb = _lum(b);
    final double hi = la > lb ? la : lb;
    final double lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// 把「填充色」推到对 [bg] 至少 [min] 的对比度：先试原色，
  /// 不够就往更黑 / 更白里推，取改动小的那一侧（二分 20 步足够细）。
  /// 用途：过渡中段弧线 / 进度条压在中灰卡面上时几乎融进去（实测 1.35:1）。
  static Color readableFill(Color fill, Color bg, {double min = 3.0}) {
    if (ratio(fill, bg) >= min) return fill;
    Color? best;
    double bestT = 2;
    for (final Color anchor in const <Color>[Color(0xFF000000), Color(0xFFFFFFFF)]) {
      for (int i = 1; i <= 20; i++) {
        final double t = i / 20;
        final Color c = Color.lerp(fill, anchor, t)!;
        if (ratio(c, bg) >= min) {
          if (t < bestT) {
            bestT = t;
            best = c;
          }
          break;
        }
      }
    }
    return best ?? (ratio(const Color(0xFF000000), bg) >= ratio(const Color(0xFFFFFFFF), bg)
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF));
  }

  /// 按底色亮度挑字色：主按钮底色在过渡里是连续变亮的，字色必须跟着底色算，
  /// 不能按主题侧硬切（否则要么白字压浅绿 2.6:1，要么深字压深绿 3.4:1）。
  ///
  /// 三段（阈值都是按 WCAG 反推的，见 test/widget_test.dart 里逐帧断言）：
  /// * L ≤ 0.178 → 设计浅字 #FFFDF8（深绿底，5.18~4.51:1）
  /// * L ≥ 0.215 → 设计深字 #1B1620（浅绿底，4.5~6.7:1）
  /// * 中间这条窄带（accent #147A62 → #4FB08B 大约只有 40ms）只有纯黑能过 4.5，
  ///   所以只在带内用 #000000；带外立刻回到设计字色。
  static Color onFill(Color fill) {
    final double l = fill.computeLuminance();
    if (l <= 0.178) return const Color(0xFFFFFDF8);
    if (l >= 0.215) return const Color(0xFF1B1620);
    return const Color(0xFF000000);
  }

  /// 步骤条专用：12px 步骤名压在同色系的 bg 上。
  ///
  /// `muted` 直接用在白天只有 4.40:1（#68736F on #F6F2E9），差 0.1 不过 12px 的 AA 线；
  /// 工作台那页以前还额外乘了 0.7 透明度，实测掉到 2.61 —— 属于令牌用错。
  /// 这里只在 muted 的基础上前推 10% 到 ink：白天 **4.95:1**、黑夜 **7.36:1**
  /// （黑夜的 muted 已在本卡提到 #B8ADC4，见下方 dark 调色板注释），
  /// 色相（灰绿 / 灰紫）不变，看上去仍比正文轻一档。
  Color get stepMuted => Color.lerp(muted, ink, 0.10)!;

  /// 12px 小标压在彩色底（tab 轨道 `canvas` / 文件卡 `accentSoft`）上专用。
  ///
  /// `ink2` / `muted` 在白天是 #68736F：压灰纸底能过（#FFFDF8 上 4.84），
  /// 但压到 tab 轨道 `#EBE6DB` 只有 3.95、压到文件卡 `#DFF0E9` 只有 4.16，
  /// 两处都不够 12px 的 AA 线。这里同样往 ink 前推 15%：
  /// 白天 **#5C6763**（轨道 4.72 / 文件卡 4.97），黑夜 **#C1B7CC**（只升不降），
  /// 色相不变；**不要**拿它替换全局 muted / stepMuted，那批配对是另一套底。
  Color get mutedOnTint => Color.lerp(muted, ink, 0.15)!;

  /// 当前底色算不算「深底」：按亮度判，不看主题名 —— 主题过渡中间态也能用。
  bool get isDarkSurface => bg.computeLuminance() < 0.2;

  /// 浮起卡片的阴影：**两层**（key light + ambient，B1）。
  ///
  /// * key light：18px / (0, 2)，贴近卡面，画边缘；
  /// * ambient：48px / (0, 18)，拉开与底面的距离。
  /// 两层都从 `shadow` 的 alpha 派生（不新增颜色值），合起来比原来那层
  /// 60px 更「有体积」，边缘却不发灰。
  ///
  /// 深色主题：影子压深底上看不见，换成 1px 提亮描边（0 模糊 + 1px 扩散，
  /// 不占布局、不改各调用点的 Border）。
  List<BoxShadow> get floatShadow => isDarkSurface
      ? <BoxShadow>[
          BoxShadow(color: lineStrong.withValues(alpha: 0.9), blurRadius: 0, spreadRadius: 1),
        ]
      : <BoxShadow>[
          BoxShadow(
            color: shadow.withValues(alpha: shadow.a * 0.62),
            blurRadius: 18,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: shadow.withValues(alpha: shadow.a * 0.45),
            blurRadius: 48,
            offset: const Offset(0, 18),
          ),
        ];

  /// hover 态：同一个几何形状，提亮 / 加深一档（B2 的「阴影加深」）
  List<BoxShadow> get floatShadowHover => isDarkSurface
      ? <BoxShadow>[
          BoxShadow(color: lineStrong, blurRadius: 0, spreadRadius: 1),
          BoxShadow(color: lilac.withValues(alpha: 0.28), blurRadius: 10, spreadRadius: 1),
        ]
      : <BoxShadow>[
          BoxShadow(
            color: shadow.withValues(alpha: shadow.a * 0.80),
            blurRadius: 18,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: shadow.withValues(alpha: shadow.a * 0.60),
            blurRadius: 54,
            offset: const Offset(0, 22),
          ),
        ];

  /// 选中行阴影
  List<BoxShadow> get softShadow => <BoxShadow>[
    BoxShadow(color: shadowSoft, blurRadius: 12, offset: const Offset(0, 4)),
  ];

  /// 封面页阴影
  List<BoxShadow> get deckCoverShadow => <BoxShadow>[
    BoxShadow(color: deckShadow, blurRadius: 28, offset: const Offset(0, 12)),
  ];

  // ------------------------------------------------------------ 白天
  static const T0Palette light = T0Palette(
    bg0: Color(0xFFEBE6DB),
    bg: Color(0xFFF6F2E9),
    surface: Color(0xFFFFFDF8),
    surface2: Color(0xFFFFFDF8), // 白天没有“更浮起”的卡片，与 surface 同值：白天零改动
    canvas: Color(0xFFEBE6DB),
    ink: Color(0xFF17211F),
    ink2: Color(0xFF68736F),
    muted: Color(0xFF68736F),
    line: Color(0xFFD9D4C9),
    lineSoft: Color(0xFFE9E4DA),
    lineStrong: Color(0xFFB9B3A6),
    accent: Color(0xFF147A62),
    accentStrong: Color(0xFF0E5F4D),
    accentFill: Color(0xFF147A62),
    accentStrongFill: Color(0xFF0E5F4D),
    accentSoft: Color(0xFFDFF0E9),
    onAccent: Color(0xFFFFFDF8),
    lilac: Color(0xFF315D9D),
    lilacSoft: Color(0xFFE6EDF8),
    ok: Color(0xFF147A62),
    warn: Color(0xFFA8461A), // 比原 #D56C3D 深一档：11px 胶囊字在 #FAE6DA 上 2.88 → 4.89
    warnSoft: Color(0xFFFAE6DA),
    danger: Color(0xFFA63F36), // 比原 #B84D43 深一档：11px 胶囊字在 #F8E5E2 上 4.14 → 5.11
    dangerSoft: Color(0xFFF8E5E2),
    grid: Color(0x0D17211F),
    scrim: Color(0xFF17211F),
    shadow: Color(0x24292F2A),
    shadowSoft: Color(0x0F292F2A),
    deckBg: Color(0xFFEBE6DB),
    deckPaper: Color(0xFFFFFDF8),
    deckInk: Color(0xFF17211F),
    deckInk2: Color(0xFF68736F),
    deckLine: Color(0xFFD9D4C9),
    deckAccent: Color(0xFF147A62),
    deckAccentSoft: Color(0xFFDFF0E9),
    deckDanger: Color(0xFFB84D43),
    deckDangerSoft: Color(0xFFF8E5E2),
    deckWarn: Color(0xFFD56C3D),
    deckLilac: Color(0xFF315D9D),
    deckCover: Color(0xFF17211F),
    deckCoverInk: Color(0xFFF6F2E9),
    deckCoverAccent: Color(0xFFDFF0E9),
    deckShadow: Color(0x33292F2A),
  );

  // ------------------------------------------------------------ 黑夜
  static const T0Palette dark = T0Palette(
    bg0: Color(0xFF241D2A),
    bg: Color(0xFF2E2536),
    surface: Color(0xFF3A2F44),
    surface2: Color(0xFF463A52),
    canvas: Color(0xFF1F1926),
    ink: Color(0xFFF3EEF7),
    ink2: Color(0xFFC6BACE),
    // 深色三级字从 #9C8FA9 提到 #B8ADC4：
    // 旧值在 surface 上 4.14:1、surface2(#463A52) 上只有 3.48:1，而 T0.mono 小字
    // （01/02/03 序号、WORKBENCH · 04、to copilot）正好落在卡面上。
    // 新值 surface 5.88:1 / surface2 4.94:1 / bg 6.84:1，仍明显暗于 ink2（5.69~7.89），层级不塌。
    muted: Color(0xFFB8ADC4),
    line: Color(0xFF52465E),
    lineSoft: Color(0xFF43384F),
    lineStrong: Color(0xFF655773),
    accent: Color(0xFF4FB08B),
    accentStrong: Color(0xFF63BF9C),
    accentFill: Color(0xFF4FB08B),
    accentStrongFill: Color(0xFF63BF9C),
    accentSoft: Color(0xFF24382F),
    onAccent: Color(0xFF1B1620),
    lilac: Color(0xFFB79BD6),
    lilacSoft: Color(0xFF3C2F49),
    ok: Color(0xFF6FBF9B),
    warn: Color(0xFFE0A268),
    warnSoft: Color(0xFF33251C),
    // #E07A72 → #F09189：深色「模拟解析失败」压卡面 #3A2F44 原来只有 4.31:1（AA 4.5 以下）。
    // 新值 surface 5.46 / surface2 4.59 / dangerSoft 6.69 / bg 6.36，浅色与红胶囊都不动。
    danger: Color(0xFFF09189),
    dangerSoft: Color(0xFF331F24),
    // 深色点阵底纹：原来 0x1A43384F 压在 bg #2E2536 上只差 1/255（等于看不见，
    // 浅色是 6/255）。1px 网格线只覆盖半个像素、alpha 实际折半，所以按实测反推：
    // 0x3D 时实测差 3/255，0x6C（108）实测差 5/255（#2E2536 → #342A3B）——
    // 看得见、又不抢内容（审图 14:40 第 2 条要 4~6/255）。
    grid: Color(0x6C43384F),
    scrim: Color(0xFF000000),
    shadow: Color(0x73000000),
    shadowSoft: Color(0x3D000000),
    // deck 与白天完全一致：画布/幻灯片是导出物预览，不跟主题变
    deckBg: Color(0xFFEBE6DB),
    deckPaper: Color(0xFFFFFDF8),
    deckInk: Color(0xFF17211F),
    deckInk2: Color(0xFF68736F),
    deckLine: Color(0xFFD9D4C9),
    deckAccent: Color(0xFF147A62),
    deckAccentSoft: Color(0xFFDFF0E9),
    deckDanger: Color(0xFFB84D43),
    deckDangerSoft: Color(0xFFF8E5E2),
    deckWarn: Color(0xFFD56C3D),
    deckLilac: Color(0xFF315D9D),
    deckCover: Color(0xFF17211F),
    deckCoverInk: Color(0xFFF6F2E9),
    deckCoverAccent: Color(0xFFDFF0E9),
    deckShadow: Color(0x33292F2A),
  );

  @override
  T0Palette copyWith({
    Color? bg0,
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? canvas,
    Color? ink,
    Color? ink2,
    Color? muted,
    Color? line,
    Color? lineSoft,
    Color? lineStrong,
    Color? accent,
    Color? accentStrong,
    Color? accentFill,
    Color? accentStrongFill,
    Color? accentSoft,
    Color? onAccent,
    Color? lilac,
    Color? lilacSoft,
    Color? ok,
    Color? warn,
    Color? warnSoft,
    Color? danger,
    Color? dangerSoft,
    Color? grid,
    Color? scrim,
    Color? shadow,
    Color? shadowSoft,
    Color? deckBg,
    Color? deckPaper,
    Color? deckInk,
    Color? deckInk2,
    Color? deckLine,
    Color? deckAccent,
    Color? deckAccentSoft,
    Color? deckDanger,
    Color? deckDangerSoft,
    Color? deckWarn,
    Color? deckLilac,
    Color? deckCover,
    Color? deckCoverInk,
    Color? deckCoverAccent,
    Color? deckShadow,
  }) {
    return T0Palette(
      bg0: bg0 ?? this.bg0,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      canvas: canvas ?? this.canvas,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      lineSoft: lineSoft ?? this.lineSoft,
      lineStrong: lineStrong ?? this.lineStrong,
      accent: accent ?? this.accent,
      accentStrong: accentStrong ?? this.accentStrong,
      accentFill: accentFill ?? this.accentFill,
      accentStrongFill: accentStrongFill ?? this.accentStrongFill,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      lilac: lilac ?? this.lilac,
      lilacSoft: lilacSoft ?? this.lilacSoft,
      ok: ok ?? this.ok,
      warn: warn ?? this.warn,
      warnSoft: warnSoft ?? this.warnSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      grid: grid ?? this.grid,
      scrim: scrim ?? this.scrim,
      shadow: shadow ?? this.shadow,
      shadowSoft: shadowSoft ?? this.shadowSoft,
      deckBg: deckBg ?? this.deckBg,
      deckPaper: deckPaper ?? this.deckPaper,
      deckInk: deckInk ?? this.deckInk,
      deckInk2: deckInk2 ?? this.deckInk2,
      deckLine: deckLine ?? this.deckLine,
      deckAccent: deckAccent ?? this.deckAccent,
      deckAccentSoft: deckAccentSoft ?? this.deckAccentSoft,
      deckDanger: deckDanger ?? this.deckDanger,
      deckDangerSoft: deckDangerSoft ?? this.deckDangerSoft,
      deckWarn: deckWarn ?? this.deckWarn,
      deckLilac: deckLilac ?? this.deckLilac,
      deckCover: deckCover ?? this.deckCover,
      deckCoverInk: deckCoverInk ?? this.deckCoverInk,
      deckCoverAccent: deckCoverAccent ?? this.deckCoverAccent,
      deckShadow: deckShadow ?? this.deckShadow,
      transitioning: transitioning,
    );
  }

  /// 前景切换点：420ms 的 35%（≈186ms）。到点直接换，不做交叉淡入。
  ///
  /// 上一版取 0.5，210ms 那一帧刚好卡在切换线上，量到 3.42:1（15px 正文 AA 线以下）。
  /// 0.35 + 面曲线 0.42 之后，210ms 已经落在深侧（浅字压深底 = 5.9:1）。
  static const double foregroundSwitch = 0.35;

  /// 过渡途中把中间调前景往「亮度极值」收：白天侧收向纯黑，黑夜侧收向纯白。
  ///
  /// 中灰底（#7A737A 一带）上没有任何主题色能过 4.5 —— 深墨字 3.4、浅字 4.2，
  /// 只有纯黑 / 纯白能到 4.5 以上（黑白在 L=0.179 处各 4.58，是硬切的理论上限）。
  /// 所以过渡中不是把颜色往 ink 靠，而是直接收到两端。
  static const Color midLightAnchor = Color(0xFF000000);
  static const Color midDarkAnchor = Color(0xFFE8E4EE);

  /// 面的插值曲线指数：前段快、后段收，让底色在切换点之前就落到深侧。
  /// 0.65 → 0.42：切换点提前到 0.35 后，底色要跟着提前变暗，
  /// 否则 210ms 那一帧还是中灰底，任何前景色都只有 3.4~4.2。
  static const double surfaceGamma = 0.42;

  /// 兜底强度：按「面进度」st 走，不按时间 —— 底色还亮着或已经落定就退回主题色，
  /// 只有穿过中灰段（st 0.05~0.90）时把前景收到亮度极值。
  static double guardFor(double st) {
    if (st <= 0.02) return 0;
    if (st < 0.05) return (st - 0.02) / 0.03;
    if (st <= 0.90) return 1;
    return ((0.985 - st) / 0.085).clamp(0.0, 1.0);
  }

  /// AnimatedTheme 每帧都会调这里，t 是已经过 easeInOutCubic 的动画值。
  @override
  T0Palette lerp(covariant ThemeExtension<T0Palette>? other, double t) {
    if (other is! T0Palette) return this;
    if (t <= 0) return this;
    if (t >= 1) return other;

    final double st = math.pow(t, surfaceGamma).toDouble();
    final bool lightSide = t < foregroundSwitch;

    // 面：420ms 连续插值
    Color s(Color a, Color b) => Color.lerp(a, b, st)!;

    // 前景：直接切到当前侧，不插值
    Color f(Color a, Color b) => lightSide ? a : b;

    // 前景 + 对比度兜底：中灰段收到亮度极值（纯黑 / 纯白），两头退回主题色
    final double guard = guardFor(st);
    // 中灰段用「亮度极值」兜底，但极值本身也要选：底色还偏亮时纯黑更好读
    // （L=0.198 时白 4.23 / 黑 4.96），底色压暗之后才轮到纯白。
    // 这样每一帧取到的都是黑白里对比度更高的那个，理论上限 4.58:1 起。
    final Color midSurface = Color.lerp(surface, other.surface, st)!;
    final double whiteRatio = ratio(const Color(0xFFFFFFFF), midSurface);
    final double blackRatio = ratio(const Color(0xFF000000), midSurface);
    final Color darkAnchor = whiteRatio >= blackRatio
        ? (ratio(midDarkAnchor, midSurface) >= 4.5 ? midDarkAnchor : const Color(0xFFFFFFFF))
        : const Color(0xFF000000);
    final Color anchor = lightSide
        ? (blackRatio >= 4.5 ? midLightAnchor : const Color(0xFFFFFFFF))
        : darkAnchor;
    Color g(Color a, Color b) => Color.lerp(f(a, b), anchor, guard)!;

    return T0Palette(
      // ---- 面
      bg0: s(bg0, other.bg0),
      bg: s(bg, other.bg),
      surface: s(surface, other.surface),
      surface2: s(surface2, other.surface2),
      canvas: s(canvas, other.canvas),
      line: s(line, other.line),
      lineSoft: s(lineSoft, other.lineSoft),
      lineStrong: s(lineStrong, other.lineStrong),
      accentSoft: s(accentSoft, other.accentSoft),
      warnSoft: s(warnSoft, other.warnSoft),
      dangerSoft: s(dangerSoft, other.dangerSoft),
      lilacSoft: s(lilacSoft, other.lilacSoft),
      grid: s(grid, other.grid),
      scrim: s(scrim, other.scrim),
      shadow: s(shadow, other.shadow),
      shadowSoft: s(shadowSoft, other.shadowSoft),
      // ---- 前景（直接切换 + 兜底收拢）
      ink: g(ink, other.ink),
      onAccent: f(onAccent, other.onAccent),
      ink2: g(ink2, other.ink2),
      muted: g(muted, other.muted),
      accent: g(accent, other.accent),
      accentStrong: g(accentStrong, other.accentStrong),
      // 面：和 bg / surface 同一套插值，不经过前景兜底
      accentFill: s(accentFill, other.accentFill),
      accentStrongFill: s(accentStrongFill, other.accentStrongFill),
      lilac: g(lilac, other.lilac),
      ok: g(ok, other.ok),
      warn: g(warn, other.warn),
      danger: g(danger, other.danger),
      // ---- deck：两套主题相同，插值等于原值
      deckBg: f(deckBg, other.deckBg),
      deckPaper: f(deckPaper, other.deckPaper),
      deckInk: f(deckInk, other.deckInk),
      deckInk2: f(deckInk2, other.deckInk2),
      deckLine: f(deckLine, other.deckLine),
      deckAccent: f(deckAccent, other.deckAccent),
      deckAccentSoft: f(deckAccentSoft, other.deckAccentSoft),
      deckDanger: f(deckDanger, other.deckDanger),
      deckDangerSoft: f(deckDangerSoft, other.deckDangerSoft),
      deckWarn: f(deckWarn, other.deckWarn),
      deckLilac: f(deckLilac, other.deckLilac),
      deckCover: f(deckCover, other.deckCover),
      deckCoverInk: f(deckCoverInk, other.deckCoverInk),
      deckCoverAccent: f(deckCoverAccent, other.deckCoverAccent),
      deckShadow: f(deckShadow, other.deckShadow),
      transitioning: t > 0.001 && t < 0.999,
    );
  }

  /// 从当前（可能是动画中间态的）Theme 里取调色板。
  static T0Palette of(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final T0Palette? palette = theme.extension<T0Palette>();
    assert(palette != null, '主题里没有挂 T0Palette：AppTheme.light()/dark() 必须带上它');
    return palette ?? light;
  }
}

/// 页面里的标准写法：`context.pal.ink`。
extension T0PaletteContext on BuildContext {
  T0Palette get pal => T0Palette.of(this);

  /// 组件自身过渡时长的安全版本：两件事都在这里归零。
  ///
  /// 1. 主题渐变进行中直接归零 —— 否则 AnimatedContainer 会去追一个每帧都在变的
  ///    目标色，颜色永远慢半拍，过渡末尾「底色已经深了、控件还停在中间灰」。
  /// 2. `MediaQuery.disableAnimations`（系统「减弱动效」）为真时归零 ——
  ///    改在这一处，全项目所有 `context.anim(...)` / `T0Motion.dur(...)` 一起生效。
  Duration anim(Duration base) {
    if (pal.transitioning) return Duration.zero;
    if (MediaQuery.maybeDisableAnimationsOf(this) ?? false) return Duration.zero;
    return base;
  }
}
