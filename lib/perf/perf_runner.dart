import 'dart:async';
import 'dart:convert';

import 'package:flutter/scheduler.dart';

import 'frame_stats.dart';
import 'perf_clock.dart';
import 'perf_platform.dart';

/// 帧采集内核：两套口径同时上，最后在结果里**分别**写清楚。
///
/// 1. `SchedulerBinding.addTimingsCallback`（FrameTiming，引擎上报的
///    build / raster 真实耗时）—— 桌面端有，web 端引擎不回调，
///    所以 `frameTiming.supported` 会是 false；
/// 2. `requestAnimationFrame` 帧间隔（等效帧率）—— web 上唯一拿得到的
///    端到端口径，掉帧次数就按它数。
///
class PerfRunner {
  PerfRunner._();

  static final PerfRunner instance = PerfRunner._();

  bool _enabled = false;
  bool _sampling = false;
  bool _timingFired = false;
  String _scenario = '';

  final List<double> _raf = <double>[];
  final List<double> _build = <double>[];
  final List<double> _raster = <double>[];
  final List<_Window> _windows = <_Window>[];

  double? _coldStartMs;

  bool get enabled => _enabled;

  /// 场景开始：注册三个回调（不采集时不注册，线上零开销）
  void begin(String scenario) {
    if (_sampling) return;
    _sampling = true;
    _enabled = true;
    _scenario = scenario;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    if (perfHasRaf) perfRequestFrame(_onRaf);
    perfLog('SCENARIO $scenario clock=${perfHasRaf ? 'performance.now' : 'Stopwatch'} raf=${perfHasRaf ? 'yes' : 'no'}');
  }

  /// 冷启动：`performance.now()` 原点就是导航开始，首帧回调的读数本身
  /// 就是「index.html 加载 → 首帧可交互」的毫秒数。
  void markColdStart(double ms) => _coldStartMs = ms;

  void _onRaf(double stamp) {
    _raf.add(stamp);
    if (_enabled) perfRequestFrame(_onRaf);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return;
    _timingFired = true;
    for (final FrameTiming t in timings) {
      _build.add(t.buildDuration.inMicroseconds / 1000);
      _raster.add(t.rasterDuration.inMicroseconds / 1000);
    }
  }

  /// 采一个窗口：`body()` 里就是这段交互（点主题 / 开弹层 / 切模块）
  Future<void> measure(String name, Future<void> Function() body) async {
    if (!_enabled) {
      await body();
      return;
    }
    final _Window w = _Window(
      name: name,
      start: perfNow(),
      raf0: _raf.length,
      build0: _build.length,
      raster0: _raster.length,
    );
    await body();
    w.end = perfNow();
    w.elements = FrameStats.instance.elementCount();
    w.raf1 = _raf.length;
    w.build1 = _build.length;
    w.raster1 = _raster.length;
    _windows.add(w);
  }

  /// 收尾：把结果同时打到控制台和 `window.__t0perf`
  void finish([String? note]) {
    if (!_enabled) return;
    _enabled = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    final Map<String, Object?> out = <String, Object?>{
      'scenario': _scenario,
      'note': note,
      'clock': perfHasRaf ? 'performance.now' : 'stopwatch',
      'raf_supported': perfHasRaf,
      'frame_timing': <String, Object?>{
        // web 引擎不上报 FrameTiming：这里如实写 false，别拿自计时冒充
        'supported': _timingFired,
        'build_samples': _build.length,
      },
      'cold_start_ms': _round(_coldStartMs),
      'raf_samples': _raf.length,
      'windows': <Map<String, Object?>>[
        for (final _Window w in _windows)
          <String, Object?>{
            'name': w.name,
            'wall_ms': _round(w.end - w.start),
            'elements': w.elements,
            ..._summary(w.raf0, w.raf1, w.build0, w.build1, w.raster0, w.raster1),
            // 原始帧间隔：python 侧按 family 汇总（跨窗口、跨 3 次运行）时用
            'intervals': <double>[for (final double v in _intervals(w.raf0, w.raf1)) _round(v)!],
            'build_samples': <double>[for (final double v in _slice(_build, w.build0, w.build1)) (_round(v)!)],
            'raster_samples': <double>[for (final double v in _slice(_raster, w.raster0, w.raster1)) (_round(v)!)],
          },
      ],
      'pooled': <String, Object?>{
        ..._summary(0, _raf.length, 0, _build.length, 0, _raster.length),
      },
    };
    final String json = jsonEncode(out);
    perfPublish('__t0perf', json);
    perfLog('T0PERF_JSON $json');
    perfLog('DONE $_scenario');
  }

  List<double> _slice(List<double> source, int from, int to) =>
      source.sublist(from.clamp(0, source.length), to.clamp(0, source.length));

  List<double> _intervals(int raf0, int raf1) {
    final List<double> out = <double>[];
    for (int i = raf0 + 1; i < raf1; i++) {
      out.add(_raf[i] - _raf[i - 1]);
    }
    return out;
  }

  Map<String, Object?> _summary(
    int raf0,
    int raf1,
    int build0,
    int build1,
    int raster0,
    int raster1,
  ) {
    final List<double> intervals = <double>[];
    for (int i = raf0 + 1; i < raf1; i++) {
      intervals.add(_raf[i] - _raf[i - 1]);
    }
    final List<double> build = _build.sublist(build0.clamp(0, _build.length), build1.clamp(0, _build.length));
    final List<double> raster = _raster.sublist(raster0.clamp(0, _raster.length), raster1.clamp(0, _raster.length));
    final double p50 = _pct(intervals, 0.50);
    return <String, Object?>{
      'frames': intervals.length,
      'interval_p50_ms': _round(p50),
      'interval_p95_ms': _round(_pct(intervals, 0.95)),
      'interval_max_ms': _round(intervals.isEmpty ? 0 : intervals.reduce((double a, double b) => a > b ? a : b)),
      'fps_p50': _round(p50 <= 0 ? 0 : 1000 / p50),
      'dropped_over_33ms': intervals.where((double v) => v > 33).length,
      'over_50ms': intervals.where((double v) => v >= 50).length,
      'build_p50_ms': _round(_pct(build, 0.50)),
      'build_p95_ms': _round(_pct(build, 0.95)),
      'build_max_ms': _round(_max(build)),
      'raster_p50_ms': _round(_pct(raster, 0.50)),
      'raster_p95_ms': _round(_pct(raster, 0.95)),
      'raster_max_ms': _round(_max(raster)),
    };
  }

  static double _max(List<double> values) =>
      values.isEmpty ? 0 : values.reduce((double a, double b) => a > b ? a : b);

  static double _pct(List<double> values, double p) {
    if (values.isEmpty) return 0;
    final List<double> sorted = List<double>.of(values)..sort();
    final int index = ((sorted.length - 1) * p).round().clamp(0, sorted.length - 1);
    return sorted[index];
  }

  static double? _round(double? v) => v == null ? null : (v * 100).round() / 100;
}

class _Window {
  _Window({
    required this.name,
    required this.start,
    required this.raf0,
    required this.build0,
    required this.raster0,
  }) : end = start;

  final String name;
  final double start;
  double end;
  final int raf0;
  int raf1 = 0;
  final int build0;
  int build1 = 0;
  final int raster0;
  int raster1 = 0;
  int elements = 0;
}
