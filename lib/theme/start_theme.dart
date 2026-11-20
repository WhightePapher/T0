/// 条件导出：桌面 / 移动端用 `dart:io` 读环境变量，Web 用 stub。
library;

export 'start_theme_stub.dart' if (dart.library.io) 'start_theme_io.dart';
