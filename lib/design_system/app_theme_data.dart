import 'package:flutter/material.dart';

import 'colors.dart';

/// 应用语义主题 (ThemeExtension) — 颜色 + 文字样式的设计 token 入口
///
/// 通过 `context.ds` 访问。所有屏幕禁止使用手写字号/颜色,
/// 统一走这里的语义 token。
class AppThemeData extends ThemeExtension<AppThemeData> {
  // ---- 颜色 ----
  /// 主题色
  final Color accent;

  /// 主题色淡背景 (选中态/图标底)
  final Color accentSoft;

  /// 评分星标
  final Color star;

  /// 涨 (红)
  final Color rise;

  /// 跌 (绿)
  final Color fall;

  /// 成功
  final Color success;

  /// 错误
  final Color error;

  /// 一级文字
  final Color textPrimary;

  /// 二级文字 (副标题)
  final Color textSecondary;

  /// 三级文字 (meta/占位/禁用)
  final Color textHint;

  /// 页面背景
  final Color surfaceBase;

  /// 卡片/内容区
  final Color surfaceCard;

  /// 分割线/描边
  final Color border;

  // ---- 文字样式 (已含颜色) ----
  /// 20/700 大数字、招牌
  final TextStyle display;

  /// 17/600 页面/详情标题
  final TextStyle title;

  /// 15/600 区块标题
  final TextStyle section;

  /// 14/500 列表项标题
  final TextStyle bodyStrong;

  /// 14/400 正文
  final TextStyle body;

  /// 13/400 次要正文
  final TextStyle label;

  /// 12/400 辅助说明 (textSecondary)
  final TextStyle caption;

  /// 11/400 元信息 (textHint)
  final TextStyle meta;

  /// 10/400 角标/最弱信息 (textHint)
  final TextStyle tiny;

  const AppThemeData({
    required this.accent,
    required this.accentSoft,
    required this.star,
    required this.rise,
    required this.fall,
    required this.success,
    required this.error,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.surfaceBase,
    required this.surfaceCard,
    required this.border,
    required this.display,
    required this.title,
    required this.section,
    required this.bodyStrong,
    required this.body,
    required this.label,
    required this.caption,
    required this.meta,
    required this.tiny,
  });

  factory AppThemeData.fromScheme(ColorScheme scheme, {bool deepDark = false}) {
    final dark = scheme.brightness == Brightness.dark;
    final textPrimary = scheme.onSurface;
    final textSecondary = scheme.onSurfaceVariant;
    final textHint = scheme.outline;
    final useDeep = dark && deepDark;

    TextStyle s(
      double size,
      FontWeight weight,
      Color color, {
      double height = 1.3,
    }) => TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );

    return AppThemeData(
      accent: scheme.primary,
      accentSoft: scheme.primary.withValues(alpha: dark ? 0.16 : 0.08),
      star: AppPalette.star,
      rise: AppPalette.rise,
      fall: AppPalette.fall,
      success: AppPalette.success,
      error: AppPalette.error,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textHint: textHint,
      surfaceBase: useDeep
          ? AppPalette.bgDeepDark
          : dark
          ? AppPalette.bgDark
          : AppPalette.bgLight,
      surfaceCard: useDeep
          ? AppPalette.cardDeepDark
          : dark
          ? AppPalette.cardDark
          : AppPalette.cardLight,
      border: useDeep
          ? AppPalette.borderDeepDark
          : dark
          ? AppPalette.borderDark
          : AppPalette.borderLight,

      display: s(20, FontWeight.w700, textPrimary),
      title: s(17, FontWeight.w600, textPrimary),
      section: s(15, FontWeight.w600, textPrimary),
      bodyStrong: s(14, FontWeight.w500, textPrimary),
      body: s(14, FontWeight.w400, textPrimary),
      label: s(13, FontWeight.w400, textPrimary),
      caption: s(12, FontWeight.w400, textSecondary),
      meta: s(11, FontWeight.w400, textHint),
      tiny: s(10, FontWeight.w400, textHint),
    );
  }

  @override
  AppThemeData copyWith({
    Color? accent,
    Color? accentSoft,
    Color? star,
    Color? rise,
    Color? fall,
    Color? success,
    Color? error,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? surfaceBase,
    Color? surfaceCard,
    Color? border,
    TextStyle? display,
    TextStyle? title,
    TextStyle? section,
    TextStyle? bodyStrong,
    TextStyle? body,
    TextStyle? label,
    TextStyle? caption,
    TextStyle? meta,
    TextStyle? tiny,
  }) {
    return AppThemeData(
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      star: star ?? this.star,
      rise: rise ?? this.rise,
      fall: fall ?? this.fall,
      success: success ?? this.success,
      error: error ?? this.error,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      border: border ?? this.border,
      display: display ?? this.display,
      title: title ?? this.title,
      section: section ?? this.section,
      bodyStrong: bodyStrong ?? this.bodyStrong,
      body: body ?? this.body,
      label: label ?? this.label,
      caption: caption ?? this.caption,
      meta: meta ?? this.meta,
      tiny: tiny ?? this.tiny,
    );
  }

  @override
  AppThemeData lerp(AppThemeData? other, double t) {
    if (other == null) return this;
    return AppThemeData(
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      star: Color.lerp(star, other.star, t)!,
      rise: Color.lerp(rise, other.rise, t)!,
      fall: Color.lerp(fall, other.fall, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      border: Color.lerp(border, other.border, t)!,
      display: TextStyle.lerp(display, other.display, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      section: TextStyle.lerp(section, other.section, t)!,
      bodyStrong: TextStyle.lerp(bodyStrong, other.bodyStrong, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      meta: TextStyle.lerp(meta, other.meta, t)!,
      tiny: TextStyle.lerp(tiny, other.tiny, t)!,
    );
  }
}

/// `context.ds` 访问设计 token
extension AppThemeContext on BuildContext {
  AppThemeData get ds => Theme.of(this).extension<AppThemeData>()!;
}
