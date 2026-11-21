/// 帧采集用的平台出口：高精度时钟、requestAnimationFrame、把结果挂到 window。
///
/// 为什么单独一个库：`dart:js_interop_unsafe` 只能在 web 编译；桌面 / 测试（VM）
/// 用 stub，接口一致但没有 JS。条件导出写在 [perf_clock]。
library;

export 'perf_clock_stub.dart' if (dart.library.js_interop) 'perf_clock_js.dart';
