import 'dart:io';

import 'package:flutter/foundation.dart';

/// 追加一行性能日志：`T0_PERF_LOG` 指向文件时写文件，否则 `debugPrint`。
void perfLog(String line) {
  final String? path = Platform.environment['T0_PERF_LOG'];
  if (path != null && path.isNotEmpty) {
    try {
      final File file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
    } on FileSystemException catch (e) {
      debugPrint('perfLog 写文件失败: $e');
    }
  }
  debugPrint('PERF $line');
}

/// 进程常驻内存（字节）：看「随操作次数涨」的量时和 Element 数一起看。
int perfRssBytes() {
  try {
    return ProcessInfo.currentRss;
  } on Object {
    return 0;
  }
}
