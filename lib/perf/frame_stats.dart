import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

/// 一帧的耗时（build = UI 线程，raster = 光栅线程）。
class FrameSample {
  const FrameSample(this.build, this.raster);

  final Duration build;
  final Duration raster;
}

/// 帧耗时采集（`--perf=A|B|C` 驱动，见 lib/main.dart）。
///
/// 只在带 `--perf=` 启动时才 `start()`；正常启动不注册回调，零开销。
/// 数据来自 `SchedulerBinding.addTimingsCallback`，是引擎上报的真实
/// FrameTiming（build 与 raster 分开），不是自己掐表。
class FrameStats {
  FrameStats._();

  static final FrameStats instance = FrameStats._();

  final List<FrameSample> _samples = <FrameSample>[];
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final FrameTiming t in timings) {
      _samples.add(FrameSample(t.buildDuration, t.rasterDuration));
    }
    // soak 会跑几十次切换，别让采样表无限长
    if (_samples.length > 4000) {
      _samples.removeRange(0, _samples.length - 4000);
    }
  }

  void clear() => _samples.clear();

  /// 采集游标：在「点主题按钮」前取一次，统计时只看这之后的帧。
  /// 不能用 clear() 代替 —— 引擎把 FrameTiming 成批回调，clear() 会把还没送达的
  /// 那一批一起丢掉（release 构建里就出现过整组 frames=0）。
  int get mark => _samples.length;

  int get count => _samples.length;

  /// build / raster 的 p50 / p95（毫秒，保留一位小数）
  Map<String, double> summary({int from = 0}) {
    final List<FrameSample> window = from <= 0 ? _samples : _samples.sublist(from);
    final List<double> build = <double>[
      for (final FrameSample s in window) s.build.inMicroseconds / 1000,
    ];
    final List<double> raster = <double>[
      for (final FrameSample s in window) s.raster.inMicroseconds / 1000,
    ];
    return <String, double>{
      'frames': window.length.toDouble(),
      'build_p50': _pct(build, 0.50),
      'build_p95': _pct(build, 0.95),
      'raster_p50': _pct(raster, 0.50),
      'raster_p95': _pct(raster, 0.95),
    };
  }

  static double _pct(List<double> values, double p) {
    if (values.isEmpty) return 0;
    final List<double> sorted = List<double>.of(values)..sort();
    final int index = ((sorted.length - 1) * p).round().clamp(0, sorted.length - 1);
    return (sorted[index] * 10).round() / 10;
  }

  /// 当前树里的 Element 数量（≈ widget 数量）：跟着操作次数长不长，看它就够。
  int elementCount() {
    int n = 0;
    void visit(Element element) {
      n++;
      element.visitChildren(visit);
    }

    final Element? root = WidgetsBinding.instance.rootElement;
    if (root != null) visit(root);
    return n;
  }
}
