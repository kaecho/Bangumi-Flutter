import 'dart:ui';

/// 语义色板 — 对齐原项目 `src/styles/colors.ts`
abstract final class AppPalette {
  /// 评分星标 (colorYellow)
  static const star = Color(0xFFFFCA28);

  /// 涨 (小圣杯 ask 红)
  static const rise = Color(0xFFCE6175);

  /// 跌 / 买入 (小圣杯 bid 绿)
  static const fall = Color(0xFF01AD91);

  /// 成功 (colorSuccess)
  static const success = Color(0xFF32C840);

  /// 错误 (colorDanger)
  static const error = Color(0xFFE8080D);

  /// 原版主题粉 colorMain `rgb(254, 138, 149)`
  static const defaultAccent = Color(0xFFFE8A95);

  /// 浅粉底 colorMainLight
  static const accentLight = Color(0xFFFFF4F4);

  /// 深色浅粉 _colorMainLight
  static const accentLightDark = Color(0xFF3B3033);

  /// 预设主题色 (首项即原版粉)
  static const accentColors = [
    Color(0xFFFE8A95), // 原版粉
    Color(0xFFF09199), // 主站粉
    Color(0xFF0DB7F3), // 原版蓝
    Color(0xFFFF6B81), // 桃红
    Color(0xFF32C840), // 绿
    Color(0xFF9C27B0), // 紫
    Color(0xFFFEBE58), // 橙
    Color(0xFF607D8B), // 蓝灰
  ];

  // ---- 中性色 (原版 light / dark / deepDark) ----
  static const bgLight = Color(0xFFEEEFF0);
  static const bgDark = Color(0xFF181818);
  static const bgDeepDark = Color(0xFF181818);
  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF242424);
  static const cardDeepDark = Color(0xFF000000);
  static const borderLight = Color(0xFFE4E4EC);
  static const borderDark = Color(0x29FFFFFF);
  static const borderDeepDark = Color(0x29FFFFFF);

  static const textPrimaryLight = Color(0xFF000000);
  static const textPrimaryDark = Color(0xEBFFFFFF);
  static const textSecondaryLight = Color(0xFF808080);
  static const textSecondaryDark = Color(0x85FFFFFF);
  static const textHintLight = Color(0xFF969696);
  static const textHintDark = Color(0x61FFFFFF);

  /// 头像占位文字底
  static const placeholderIcon = Color(0x33000000);
  static const placeholderBg = Color(0x0F000000);
}
