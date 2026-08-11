import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/settings_store.dart';

/// 主题管理 (Material 3, 浅色/深色/跟随系统 + 自定义主题色)
class AppTheme {
  static const Color defaultPrimary = Color(0xFF1E90FF);

  /// 预设主题色 (与原项目一致)
  static const List<Color> accentColors = [
    Color(0xFF1E90FF), // 蓝
    Color(0xFFFF6B81), // 粉
    Color(0xFF4CAF50), // 绿
    Color(0xFF9C27B0), // 紫
    Color(0xFFFF9800), // 橙
    Color(0xFF00BCD4), // 青
    Color(0xFFE91E63), // 玫红
    Color(0xFF607D8B), // 蓝灰
  ];

  static ThemeData light(Color seed) => _base(Brightness.light, seed);
  static ThemeData dark(Color seed) => _base(Brightness.dark, seed);

  static ThemeData _base(Brightness brightness, Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF7F7F7)
          : const Color(0xFF181818),
      appBarTheme: AppBarTheme(
        backgroundColor: brightness == Brightness.light
            ? const Color(0xFFF7F7F7)
            : const Color(0xFF181818),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: brightness == Brightness.light ? Colors.black87 : Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: brightness == Brightness.light ? Colors.white : const Color(0xFF232323),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(
        color: brightness == Brightness.light
            ? const Color(0xFFE5E5E5)
            : const Color(0xFF2E2E2E),
        thickness: 0.5,
        space: 0.5,
      ),
      listTileTheme: ListTileThemeData(
        textColor: brightness == Brightness.light ? Colors.black87 : Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// 当前主题色 (跟随设置)
final themeColorProvider = Provider<Color>((ref) {
  return ref.watch(settingsStoreProvider).primaryColor;
});

/// 当前 ThemeMode (跟随设置)
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsStoreProvider).themeMode;
});

/// 主题色文案扩展
extension AppThemeX on BuildContext {
  Color get accent => Theme.of(this).colorScheme.primary;

  /// 背景色
  Color get bgColor => Theme.of(this).scaffoldBackgroundColor;

  /// 内容区颜色 (卡片/列表项)
  Color get contentColor => Theme.of(this).cardTheme.color ?? Colors.white;

  /// 文字主色
  Color get textColor => Theme.of(this).colorScheme.onSurface;

  /// 次要文字色
  Color get subTextColor => Theme.of(this).colorScheme.onSurfaceVariant;

  /// 分割线颜色
  Color get borderColor => Theme.of(this).dividerColor;

  /// 主色淡背景
  Color get accentBg => Theme.of(this).colorScheme.primary.withValues(alpha: 0.08);
}
