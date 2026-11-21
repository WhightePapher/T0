/// 启动参数的唯一解析点：桌面 `main(List<String> args)` 与 web 查询串共用。
///
/// 为什么单独抽出来：`main()` 直接读 `Uri.base` 是测不了的；把「args + 查询串 →
/// 一份配置」抽成纯函数，`?perf=` / `?route=` / `?motion=` 的优先级就有用例可断言
/// （见 test/round2_test.dart）。args 优先，查询串只补空缺。
class T0LaunchArgs {
  const T0LaunchArgs({this.route, this.perf, this.motionScale});

  /// 起始路由（`--route=/outline` / `?route=/outline`）
  final String? route;

  /// 帧采集场景（`--perf=theme` / `?perf=theme`）
  final String? perf;

  /// 抓帧放慢倍数（`--motion=6` / `?motion=6`）
  final double? motionScale;

  static T0LaunchArgs parse(List<String> args, Map<String, String> query) {
    String? route;
    String? perf;
    double? motion;
    for (final String arg in args) {
      if (arg.startsWith('--route=')) {
        route = _nonEmpty(arg.substring('--route='.length)) ?? route;
      } else if (arg.startsWith('--perf=')) {
        perf = _nonEmpty(arg.substring('--perf='.length)) ?? perf;
      } else if (arg.startsWith('--motion=')) {
        motion = double.tryParse(arg.substring('--motion='.length)) ?? motion;
      }
    }
    route ??= _nonEmpty(query['route']);
    perf ??= _nonEmpty(query['perf']);
    motion ??= _nonEmpty(query['motion']) == null
        ? null
        : double.tryParse(query['motion']!);
    return T0LaunchArgs(route: route, perf: perf, motionScale: motion);
  }

  static String? _nonEmpty(String? value) =>
      (value == null || value.isEmpty) ? null : value;
}
