import 'package:flutter/material.dart';

import 'palette.dart';
import 'tokens.dart';

/// 全局 ThemeData：两套主题都挂 [T0Palette] extension。
///
/// 白天是暖纸底 + 沉绿主色；黑夜是 #42374B 衍生的深紫系。
/// 两套都关掉 Material 自带涟漪（按钮自己做 hover / pressed）。
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(T0Palette.light, Brightness.light);

  static ThemeData dark() => _build(T0Palette.dark, Brightness.dark);

  static ThemeData _build(T0Palette p, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      fontFamily: T0.sansFamily,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: p.accent,
              onPrimary: p.onAccent,
              secondary: p.lilac,
              onSecondary: p.onAccent,
              surface: p.surface,
              onSurface: p.ink,
              error: p.danger,
              onError: p.onAccent,
            )
          : ColorScheme.light(
              primary: p.accent,
              onPrimary: p.onAccent,
              secondary: p.lilac,
              onSecondary: p.onAccent,
              surface: p.surface,
              onSurface: p.ink,
              error: p.danger,
              onError: p.onAccent,
            ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accentSoft,
        selectionHandleColor: p.accent,
      ),
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[p],
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
    );
  }

  /// 输入框统一外观：14 圆角、1px line、聚焦转绿。
  static InputDecoration field(
    BuildContext context, {
    String? hint,
    EdgeInsetsGeometry? padding,
    int? hintMaxLines,
  }) {
    final T0Palette p = context.pal;
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(T0.fieldRadius),
      borderSide: BorderSide(color: p.line),
    );
    return InputDecoration(
      hintText: hint,
      hintMaxLines: hintMaxLines,
      hintStyle: context.tMeta,
      isDense: true,
      filled: true,
      fillColor: p.surface,
      contentPadding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(T0.fieldRadius),
        borderSide: BorderSide(color: p.accent, width: 1.2),
      ),
    );
  }
}
