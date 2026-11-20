import 'package:flutter/material.dart';

import 'features/delivery/delivery_page.dart';
import 'features/intake/intake_page.dart';
import 'features/modules/modules_page.dart';
import 'features/outline/outline_page.dart';
import 'features/workbench/workbench_page.dart';
import 'features/workspace/workspace_page.dart';
import 'models/mock_data.dart';
import 'perf/frame_stats.dart';
import 'perf/perf_platform.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'theme/tokens.dart';

void main(List<String> args) {
  // 桌面端可以用 --route=/outline 直接落到某一步（截图与演示用）
  String route = WorkbenchPage.routeName;
  // 帧耗时采集：--perf=A|B|C|soak（见 _T0AppState._runPerfScenario），不带就不注册回调
  String? perf;
  for (final String arg in args) {
    if (arg.startsWith('--route=')) {
      route = arg.substring('--route='.length);
    } else if (arg.startsWith('--perf=')) {
      perf = arg.substring('--perf='.length);
    }
  }
  runApp(T0App(initialRoute: route, perfScenario: perf));
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

  @override
  void initState() {
    super.initState();
    final String? scenario = widget.perfScenario;
    if (scenario != null && scenario.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runPerfScenario(scenario));
    }
  }

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ 帧耗时采集
  //
  // 三组数据都是「点一次主题按钮 → 统计这 420ms 动画窗口内的帧」：
  //   A 冷启动后第一次切换
  //   B 连续切换 10 次之后再切一次
  //   C 在模块工作区里做 20 次操作（切模块 / 应用修改 / 前后对比 / 切主题）之后再切
  // 每组都同时记 Element 数（≈ widget 数）与 RSS，用来判断「哪个量跟着操作次数长」。
  Future<void> _runPerfScenario(String scenario) async {
    FrameStats.instance.start();
    perfLog('SCENARIO $scenario route=${widget.initialRoute}');
    // 等首帧稳定与首屏排版完成
    await Future<void>.delayed(const Duration(milliseconds: 900));

    switch (scenario) {
      case 'A':
        await _perfMeasureSwitch('A 冷启动后第一次切换');
      case 'B':
        for (int i = 0; i < 10; i++) {
          _theme.toggle();
          await Future<void>.delayed(const Duration(milliseconds: 520));
        }
        await _perfMeasureSwitch('B 连续切换 10 次之后');
      case 'C':
        await _perfWorkspaceOps(20);
        await _perfMeasureSwitch('C 工作区 20 次操作之后');
      case 'D':
        // 逛完六个界面再切主题：PageRoute 默认 maintainState=true，之前逛过的页面
        // 元素还挂在树上，主题动画会把它们一起重建 —— 这条就是「越用越卡」的量。
        for (final String name in <String>[
          '/intake',
          '/outline',
          '/modules',
          '/workspace',
          '/delivery',
        ]) {
          _navigatorKey.currentState?.pushNamed(name);
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        await _perfMeasureSwitch('D 逛完 5 个页面之后');
      case 'E':
        // 前后对比弹层开着切主题：弹层里两页 720×405 全量重建，是「个位数帧」的现场
        await WorkspacePage.perfOpenCompareOnly();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await _perfMeasureSwitch('E 对比弹层开着切主题');
        await Future<void>.delayed(const Duration(milliseconds: 200));
        WorkspacePage.perfCloseCompare();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      case 'soak':
        for (int i = 0; i < 20; i++) {
          await _perfMeasureSwitch('soak #${i + 1}');
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
      default:
        perfLog('未知场景 $scenario（可选 A / B / C / soak）');
    }
    perfLog('DONE $scenario');
  }

  /// 点一次主题按钮，统计 420ms 动画窗口里的帧。
  Future<void> _perfMeasureSwitch(String label) async {
    final FrameStats stats = FrameStats.instance;
    final int mark = stats.mark;
    final int elements = stats.elementCount();
    final double rssMb = perfRssBytes() / 1048576;
    final bool toDark = !_theme.isDark;

    _theme.toggle();
    // 采样到 900ms 而不是 420ms：动画本身 420ms 结束，之后不再出帧；多等一会儿
    // 是为了让引擎把这一批 FrameTiming 送齐（成批回调，release 下会晚到几百毫秒）。
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final Map<String, double> p = stats.summary(from: mark);
    perfLog(
      'SWITCH $label to=${toDark ? 'dark' : 'light'} frames=${p['frames']!.toInt()} '
      'build_p50=${p['build_p50']} build_p95=${p['build_p95']} '
      'raster_p50=${p['raster_p50']} raster_p95=${p['raster_p95']} '
      'elements=$elements rss_mb=${rssMb.toStringAsFixed(1)}',
    );
    // 让动画尾巴彻底结束，别把余帧算进下一组
    await Future<void>.delayed(const Duration(milliseconds: 220));
  }

  /// 工作区里的 20 次真实操作：切模块 / 应用修改 / 前后对比弹层 / 切主题
  Future<void> _perfWorkspaceOps(int total) async {
    final T0Store store = T0Store.instance;
    for (int i = 0; i < total; i++) {
      switch (i % 4) {
        case 0:
          store.setActiveModule(1 + (i ~/ 4) % 5);
          await Future<void>.delayed(const Duration(milliseconds: 240));
        case 1:
          final int id = store.activeModuleId.value;
          if (store.hasEdits(id)) {
            store.revertEdit(id);
          } else {
            store.applyEdit(id);
          }
          await Future<void>.delayed(const Duration(milliseconds: 140));
        case 2:
          await WorkspacePage.perfCompareOnce();
          await Future<void>.delayed(const Duration(milliseconds: 160));
        case 3:
          _theme.toggle();
          await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      perfLog(
        'OP ${i + 1}/$total kind=${i % 4} elements=${FrameStats.instance.elementCount()} '
        'rss_mb=${(perfRssBytes() / 1048576).toStringAsFixed(1)}',
      );
    }
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
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondary) => page,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondary,
      Widget child,
    ) {
      final Animation<double> curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return AnimatedBuilder(
        animation: curved,
        builder: (BuildContext context, Widget? child) => Opacity(
          opacity: curved.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - curved.value)),
            child: child,
          ),
        ),
        child: child,
      );
    },
  );
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
