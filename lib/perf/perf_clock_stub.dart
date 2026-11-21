/// VM / 桌面兜底：没有 rAF，用单调秒表当时钟。
final Stopwatch _clock = Stopwatch()..start();

/// 毫秒（相对进程启动；web 上是相对页面 `performance.timeOrigin`）
double perfNow() => _clock.elapsedMicroseconds / 1000.0;

/// 这一套平台有没有 requestAnimationFrame（web 才有）
bool get perfHasRaf => false;

/// VM 上不排帧：直接不回调（采集代码因此可以共用一份）
void perfRequestFrame(void Function(double timestampMs) onFrame) {}

/// VM 上不挂 window：只往控制台打
void perfPublish(String key, String json) {}
