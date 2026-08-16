import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/settings_store.dart';
import '../design_system/design_system.dart';

/// 主题管理: 由设计 token 驱动 (浅色/深色/跟随系统 + 自定义主题色)
class AppTheme {
  static ThemeData light(Color seed) => _base(Brightness.light, seed);
  static ThemeData dark(Color seed, {bool deepDark = false}) =>
      _base(Brightness.dark, seed, deepDark: deepDark);

  static ThemeData _base(
    Brightness brightness,
    Color seed, {
    bool deepDark = false,
  }) {
    // 不用 fromSeed: Material You 会把 #FE8A95  squish 成另一套粉
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      primary: seed,
      onPrimary: Colors.white,
    );

    final ds = AppThemeData.fromScheme(scheme, deepDark: deepDark);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [ds],
      scaffoldBackgroundColor: deepDark && brightness == Brightness.dark
          ? AppPalette.bgDeepDark
          : ds.surfaceBase,

      textTheme: TextTheme(
        titleLarge: ds.title,
        titleMedium: ds.bodyStrong,
        titleSmall: ds.label,
        bodyLarge: ds.body,
        bodyMedium: ds.body,
        bodySmall: ds.caption,
        labelLarge: ds.label,
        labelSmall: ds.meta,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: ds.surfaceBase,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: ds.title,
        iconTheme: IconThemeData(color: ds.textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: ds.surfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lAll),
      ),
      dividerTheme: DividerThemeData(
        color: ds.border,
        thickness: 0.5,
        space: 0.5,
      ),
      iconTheme: IconThemeData(color: ds.textPrimary, size: 22),
      listTileTheme: ListTileThemeData(
        textColor: ds.textPrimary,
        titleTextStyle: ds.body,
        subtitleTextStyle: ds.caption,
        iconColor: ds.textSecondary,
        contentPadding: AppGap.pageH,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 62,
        elevation: 0,
        backgroundColor: ds.surfaceCard,
        indicatorColor: ds.accentSoft,
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: ds.textSecondary, size: 22),
        ),
        labelTextStyle: WidgetStatePropertyAll(ds.tiny),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: ds.bodyStrong,
        unselectedLabelStyle: ds.body.copyWith(color: ds.textSecondary),
        labelColor: ds.accent,
        unselectedLabelColor: ds.textSecondary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ds.surfaceCard,
        selectedColor: ds.accentSoft,
        labelStyle: ds.caption,
        side: BorderSide(color: ds.border, width: 0.5),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: AppGap.x2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: ds.surfaceCard,
        hintStyle: ds.caption.copyWith(color: ds.textHint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppGap.x6,
          vertical: AppGap.x4,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.lAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.lAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.lAll,
          borderSide: BorderSide(color: ds.accent, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ds.surfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        titleTextStyle: ds.section,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ds.surfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: ds.accent,
        linearTrackColor: ds.border,
        circularTrackColor: ds.border,
      ),
      popupMenuTheme: PopupMenuThemeData(iconColor: ds.textPrimary),

      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lAll),
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

/// 主题快捷访问 — 全部委托给设计 token (`context.ds`)
extension AppThemeX on BuildContext {
  Color get accent => ds.accent;

  /// 背景色
  Color get bgColor => ds.surfaceBase;

  /// 内容区颜色 (卡片/列表项)
  Color get contentColor => ds.surfaceCard;

  /// 文字主色
  Color get textColor => ds.textPrimary;

  /// 次要文字色
  Color get subTextColor => ds.textSecondary;

  /// 分割线颜色
  Color get borderColor => ds.border;

  /// 主色淡背景
  Color get accentBg => ds.accentSoft;
}
