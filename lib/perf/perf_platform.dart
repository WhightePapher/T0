/// 帧耗时采集的打卡：桌面端追加写文件，Web 端只打控制台。
///
/// 为什么写文件：Windows 的 GUI exe 没有控制台，stdout 拿不到；
/// 用 `T0_PERF_LOG=<绝对路径>` 指定文件，Python 驱动脚本读回来。
library;

export 'perf_platform_stub.dart' if (dart.library.io) 'perf_platform_io.dart';
