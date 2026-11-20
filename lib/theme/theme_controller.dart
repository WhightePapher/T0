import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'start_theme.dart';

/// 白天 / 黑夜的主题状态。
///
/// 只有 ChangeNotifier + InheritedNotifier，没有 provider / riverpod 之类的新依赖；
/// 本次不持久化：重启回到白天。
class ThemeController extends ChangeNotifier {
  static const MethodChannel _titleBar =
      MethodChannel('t0/theme');

  // 启动期覆盖（T0_START_THEME=dark|light）：不设置时就是白天，行为不变
  ThemeMode _mode = startThemeOverride() == 'dark'
      ? ThemeMode.dark
      : ThemeMode.light;

  ThemeController() {
    _syncNativeTitleBar();
  }

  /// Windows 原生标题栏跟着主题走（DwmSetWindowAttribute，见 windows/runner）。
  /// Web / 其它平台没有这个 channel，静默忽略。
  void _syncNativeTitleBar() {
    if (kIsWeb) return;
    _titleBar.invokeMethod<void>('setDark', _mode == ThemeMode.dark).catchError(
      (Object _) {
        // 没有原生实现（web / 测试环境）时忽略
      },
    );
  }

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  void toggle() => setMode(isDark ? ThemeMode.light : ThemeMode.dark);

  void setMode(ThemeMode next) {
    if (next == _mode) return;
    _mode = next;
    _syncNativeTitleBar();
    notifyListeners();
  }
}

/// 把 controller 下发到整棵树（挂在 MaterialApp 之上，弹层 / Overlay 也读得到）。
class T0Theme extends InheritedNotifier<ThemeController> {
  const T0Theme({super.key, required ThemeController controller, required super.child})
    : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final T0Theme? scope = context.dependOnInheritedWidgetOfExactType<T0Theme>();
    assert(scope?.notifier != null, 'T0Theme 必须包在 MaterialApp 外面');
    return scope!.notifier!;
  }
}
