import 'package:flutter/foundation.dart';

/// Web 端拿不到 RSS，也不写文件：只打控制台。
void perfLog(String line) => debugPrint('PERF $line');

int perfRssBytes() => 0;
