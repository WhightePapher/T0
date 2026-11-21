import 'package:flutter/material.dart';

import 'features/delivery/delivery_page.dart';
import 'features/intake/intake_page.dart';
import 'features/modules/modules_page.dart';
import 'features/outline/outline_page.dart';
import 'features/workbench/workbench_page.dart';
import 'features/workspace/workspace_page.dart';
import 'models/mock_data.dart';
import 'perf/perf_clock.dart';
import 'perf/perf_platform.dart';
import 'perf/launch_args.dart';
import 'perf/perf_runner.dart';
import 'theme/app_theme.dart';
import 'theme/motion.dart';
import 'theme/theme_controller.dart';
import 'theme/tokens.dart';

void main(List<String> args) {
  // 两个入口共用一套解析：桌面 `--route=/outline --perf=theme`，
  // web `?route=/outline&perf=theme`（见 lib/perf/launch_args.dart）
  final T0LaunchArgs launch = T0LaunchArgs.parse(args, Uri.base.queryParameters);
  final double? motion = launch.motionScale;
  if (motion != null) T0Motion.captureScale = motion;
  runApp(T0App(
    initialRoute: launch.route ?? WorkbenchPage.routeName,
    perfScenario: launch.perf,
  ));
}

/// t0 办公 · 跨平台高保真应用。
///
/// 六个界面用命名路由串起来，切换动效 240ms：淡入 + 上移 8px。
/// 主题：白天 / 黑夜两套，切换时颜色走 420ms easeInOutCubic 渐变
/// （AnimatedTheme + ThemeExtension，见 lib/theme/palette.dart）。
class T0App extends StatefulWidget {
  const T0App({super.key, this.initialRoute = WorkbenchPage.routeName, this.perfScenario});

  /// 默认从工作台进入；测试里可以直接落到任意一步。
  final String initialRoute;

  /// `--perf=A|B|C|soak`：debug 构建下的帧耗时采集脚本，见 [_T0AppState._runPerfScenario]
  final String? perfScenario;

  @override
  State<T0App> createState() => _T0AppState();
}

class _T0AppState extends State<T0App> {
  /// 本次不持久化：同一会话内保持，重启回到白天。
  final ThemeController _theme = ThemeController();

  /// `--perf=D` 需要从外部按路由名推进（模拟用户逛页面），其余场景用不到
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// 采集场景当前停在哪个路由，避免重复 push
  String? _perfRoute;

  @override
  void initState() {
    super.initState();
    final String? scenario = widget.perfScenario;
    if (scenario != null && scenario.isNotEmpty) {
      // 从第一帧之前就开始排 rAF / 注册 FrameTiming 回调，冷启动才量得全
      PerfRunner.instance.begin(scenario);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // performance.now() 的原点就是导航开始：这一读数本身即「加载 → 首帧」
        if (perfHasRaf) PerfRunner.instance.markColdStart(perfNow());
        _runPerfScenario(scenario);
      });
    }
  }

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ 帧采集场景
  //
  // 四条场景，桌面 runner 走 `--perf=<场景>`，web 走 `?perf=<场景>`，
  // 场景代码只有这一份（`_runPerfScenario`），结果由 PerfRunner 统一输出到
  // 控制台 + `window.__t0perf`（见 lib/perf/perf_runner.dart、tool/measure_fps.py）。
  //
  //   cold    冷启动：导航开始 → 首帧（performance.now 的原点就是导航开始）
  //   theme   主题切换：6 次按钮切换，每次统计 420ms 过渡窗口
  //   works   工作区操作：切模块 / 应用修改 / 前后对比 各 10 次
  //   dialog  对比弹层：打开 10 次 + 关闭 10 次
  //   all     上面三条依次跑一遍（一条命令出齐三张表）
  //
  // A/B/C/D/E/soak 是上一轮的桌面场景名，保留同一套实现（老脚本还能跑）。
  Future<void> _runPerfScenario(String scenario) async {
    final PerfRunner runner = PerfRunner.instance;
    perfLog('SCENARIO $scenario route=${widget.initialRoute}');
    // 等首屏排版落定，第一帧的构建成本不算进交互窗口
    await Future<void>.delayed(const Duration(milliseconds: 600));

    switch (scenario) {
      case 'cold':
        // 首帧时刻在 initState 的 post-frame 里就记下了，这里只是让它落盘
        await Future<void>.delayed(const Duration(milliseconds: 300));
        runner.finish('cold_start = performance.now 原点 → 首帧回调');
      case 'theme':
        await _perfThemeSwitches(6);
        runner.finish('6 次主题切换，每次一个 420ms 窗口');
      case 'works':
        await _perfWorkspaceSweep();
        runner.finish('切模块 / 应用修改 / 前后对比 各 10 次');
      case 'dialog':
        await _perfDialogSweep();
        runner.finish('对比弹层打开 10 次 + 关闭 10 次');
      case 'all':
        await _perfThemeSwitches(4);
        await _perfWorkspaceSweep();
        await _perfDialogSweep();
        runner.finish('theme + works + dialog 一次跑完');
      // ---- 上一轮的桌面场景名（同一套实现，语义不变）
      case 'A':
        await _perfThemeSwitches(1);
        runner.finish('A 冷启动后第一次切换');
      case 'B':
        for (int i = 0; i < 10; i++) {
          _theme.toggle();
          await Future<void>.delayed(const Duration(milliseconds: 520));
        }
        await _perfThemeSwitches(1);
        runner.finish('B 连续切换 10 次之后');
      case 'C':
        await _perfWorkspaceSweep();
        runner.finish('C 工作区 30 次操作');
      case 'D':
        for (final String name in <String>[
          '/intake',
          '/outline',
          '/modules',
          '/workspace',
          '/delivery',
        ]) {
          await _perfGoto(name);
        }
        await _perfThemeSwitches(1);
        runner.finish('D 逛完 5 个页面之后');
      case 'E':
        await _perfGoto('/workspace');
        await WorkspacePage.perfOpenCompareOnly();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await _perfThemeSwitches(1);
        WorkspacePage.perfCloseCompare();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        runner.finish('E 对比弹层开着切主题');
      case 'soak':
        await _perfThemeSwitches(20);
        runner.finish('soak 20 次切换');
      default:
        perfLog('未知场景 $scenario（可选 cold / theme / works / dialog / all，或 A–E / soak）');
        runner.finish('未知场景');
    }
  }

  /// 点一次主题按钮，统计 420ms 动画窗口内的帧；窗口外多等 180ms 让尾巴收干净
  Future<void> _perfThemeSwitches(int times) async {
    final PerfRunner runner = PerfRunner.instance;
    for (int i = 0; i < times; i++) {
      await runner.measure('theme#${i + 1}', () async {
        _theme.toggle();
        // 420ms 是过渡时长本身；窗口就开到 420ms，尾巴不进表
        await Future<void>.delayed(const Duration(milliseconds: 420));
      });
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
  }

  /// 切模块 / 应用修改 / 前后对比 各 10 次，每次一个窗口
  Future<void> _perfWorkspaceSweep() async {
    final PerfRunner runner = PerfRunner.instance;
    await _perfGoto('/workspace');
    final T0Store store = T0Store.instance;
    for (int i = 0; i < 10; i++) {
      await runner.measure('works.module#${i + 1}', () async {
        store.setActiveModule(1 + i % 5);
        await Future<void>.delayed(const Duration(milliseconds: 260));
      });
    }
    for (int i = 0; i < 10; i++) {
      await runner.measure('works.edit#${i + 1}', () async {
        final int id = store.activeModuleId.value;
        if (store.hasEdits(id)) {
          store.revertEdit(id);
        } else {
          store.applyEdit(id);
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
    }
    for (int i = 0; i < 10; i++) {
      await runner.measure('works.compare#${i + 1}', () async {
        await WorkspacePage.perfCompareOnce();
        await Future<void>.delayed(const Duration(milliseconds: 160));
      });
    }
  }

  /// 对比弹层：打开 / 关闭各一个窗口（打开是 scale 0.94→1 + 两页滑入）
  Future<void> _perfDialogSweep() async {
    final PerfRunner runner = PerfRunner.instance;
    await _perfGoto('/workspace');
    for (int i = 0; i < 10; i++) {
      await runner.measure('dialog.open#${i + 1}', () async {
        await WorkspacePage.perfOpenCompareOnly();
        await Future<void>.delayed(const Duration(milliseconds: 280));
      });
      await runner.measure('dialog.close#${i + 1}', () async {
        WorkspacePage.perfCloseCompare();
        await Future<void>.delayed(const Duration(milliseconds: 240));
      });
    }
  }

  /// 按路由名往前走一步（采集场景模拟用户逛页面）；已经在目标页就不重复压栈
  Future<void> _perfGoto(String name) async {
    final NavigatorState? nav = _navigatorKey.currentState;
    if (nav == null) return;
    if (_perfRoute == name) return;
    _perfRoute = name;
    nav.pushNamed(name);
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _theme,
      builder: (BuildContext context, _) {
        return T0Theme(
          controller: _theme,
          child: MaterialApp(
            title: 't0 办公 · 受控 AI 演示文稿',
            debugShowCheckedModeBanner: false,
            navigatorKey: _navigatorKey,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _theme.mode,
            // MaterialApp 自带的主题动画只有 200ms，且会和下面这条 420ms 的
            // AnimatedTheme 叠成两段；关掉它，只留一条 easeInOutCubic。
            themeAnimationDuration: Duration.zero,
            // 全应用统一的响应式度量 + 主题渐变壳
            builder: (BuildContext context, Widget? child) {
              return T0Metrics(
                width: MediaQuery.sizeOf(context).width,
                child: AnimatedTheme(
                  data: Theme.of(context),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeInOutCubic,
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            initialRoute: widget.initialRoute,
            onGenerateRoute: _routeFor,
            onUnknownRoute: (RouteSettings settings) =>
                _fadeUpRoute(const WorkbenchPage(), settings),
          ),
        );
      },
    );
  }
}

Route<dynamic> _fadeUpRoute(Widget page, RouteSettings settings) {
  return PageRouteBuilder<void>(
    settings: settings,
    // maintainState: false —— 这一条是「主题切换越用越卡」的解药。
    // 默认 true 时，逛过的每个页面都留在树里（实测逛完五步后 4660 个 Element，
    // 是单页 1323 的 3.5 倍），主题动画 25 帧会把它们全部重建一遍，
    // 实测 build p50 从 45ms 涨到 290ms，420ms 只出的了 1 帧。
    // 五步是「往下一步走」的线性流程，数据都在 T0Store 单例里，
    // 回到上一页时重建即可，不需要为不可见的页面每帧付钱。
    maintainState: false,
    transitionDuration: T0Motion.scaled(T0Motion.pageIn),
    reverseTransitionDuration: T0Motion.scaled(T0Motion.pageOut),
    pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondary) => page,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondary,
      Widget child,
    ) {
      // 主题渐变进行中 / 系统减弱动效：整段转场让路，直接落位（不是缩短，是不动）
      if (T0Motion.dur(context, T0Motion.pageIn) == Duration.zero) return child;
      // 进：240ms enter；退：180ms（reverseTransitionDuration）走 exit
      final Animation<double> incoming = CurvedAnimation(
        parent: animation,
        curve: T0Motion.enter,
        reverseCurve: T0Motion.exit,
      );
      // 旧页：靠 secondaryAnimation 反推 —— 新页压上来时它 fade 1→0、上移 0→−4，
      // 两页因此有前后层次，而不是硬叠在一起。
      final Animation<double> outgoing = CurvedAnimation(
        parent: secondary,
        curve: T0Motion.enter,
        reverseCurve: T0Motion.exit,
      );
      return _FadeUpTransition(
        incoming: incoming,
        outgoing: outgoing,
        child: child,
      );
    },
  );
}

/// 页面转场的两层合成：新页 fade 0→1 + 上移 8→0；旧页 fade 1→0 + 上移 0→−4。
///
/// [child] 通过 `AnimatedBuilder.child` 传入，每帧只重跑这一层 `Opacity / Transform`，
/// 页面本体不重建。
class _FadeUpTransition extends StatelessWidget {
  const _FadeUpTransition({
    required this.incoming,
    required this.outgoing,
    required this.child,
  });

  final Animation<double> incoming;
  final Animation<double> outgoing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[incoming, outgoing]),
      child: child,
      builder: (BuildContext context, Widget? child) {
        final double enter = incoming.value.clamp(0.0, 1.0);
        final double leave = outgoing.value.clamp(0.0, 1.0);
        final double opacity = (enter * (1 - leave)).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - enter) - 4 * leave),
            // 整页一层：转场 240ms 内只有合成，页面本身不重画
            child: RepaintBoundary(child: child),
          ),
        );
      },
    );
  }
}

Route<dynamic> _routeFor(RouteSettings settings) {
  final Widget page = switch (settings.name) {
    '/' || WorkbenchPage.routeName => const WorkbenchPage(),
    IntakePage.routeName => const IntakePage(),
    OutlinePage.routeName => const OutlinePage(),
    ModulesPage.routeName => const ModulesPage(),
    WorkspacePage.routeName => WorkspacePage(key: WorkspacePage.perfKey),
    DeliveryPage.routeName => const DeliveryPage(),
    _ => const WorkbenchPage(),
  };
  return _fadeUpRoute(page, settings);
}
