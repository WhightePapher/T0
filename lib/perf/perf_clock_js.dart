import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// web：`performance.now()`（毫秒，原点 = 页面导航开始）。
///
/// 不用 `@JS('window.performance.now')` 这种点号注解：拿 globalThis 上的对象
/// 再以它自己作 this 调用，两个浏览器引擎都不会报 "Illegal invocation"。
final JSObject _performance = globalContext['performance'] as JSObject;
final JSFunction _performanceNow = _performance['now'] as JSFunction;
final JSFunction _requestAnimationFrame = globalContext['requestAnimationFrame'] as JSFunction;

double perfNow() =>
    (_performanceNow.callAsFunction(_performance) as JSNumber).toDartDouble;

bool get perfHasRaf => true;

/// 排一帧：回调拿到 rAF 时间戳（毫秒，和 [perfNow] 同一原点）
void perfRequestFrame(void Function(double timestampMs) onFrame) {
  final JSFunction cb = ((JSNumber stamp) {
    onFrame(stamp.toDartDouble);
  }).toJS;
  _requestAnimationFrame.callAsFunction(globalContext, cb);
}

/// `window[key] = json`：抓帧脚本用 `Runtime.evaluate` 直接读，比翻控制台稳。
void perfPublish(String key, String json) {
  globalContext[key] = json.toJS;
}
