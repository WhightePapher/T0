import 'dart:io' show Platform;

/// 启动期主题覆盖：`T0_START_THEME=dark|light`。
///
/// 只给「出图 / 演示」用（Windows 上顶栏右上角常被别的窗口压住，脚本点不到主题按钮），
/// 不设置时行为不变（默认白天，用户手动切换）。
String? startThemeOverride() {
  final String? value = Platform.environment['T0_START_THEME'];
  if (value == 'dark' || value == 'light') return value;
  return null;
}
