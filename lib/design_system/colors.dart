import 'dart:ui';

/// 语义色板 — 与主题色 (accent) 无关的固定语义色 + 明暗中性色
abstract final class AppPalette {
  /// 评分星标
  static const star = Color(0xFFF5A623);

  /// 涨 (A 股惯例: 红涨)
  static const rise = Color(0xFFE5484D);

  /// 跌 (绿跌)
  static const fall = Color(0xFF30A46C);

  /// 成功状态
  static const success = Color(0xFF30A46C);

  /// 错误
  static const error = Color(0xFFE5484D);

  /// 默认主题色 (bgm.tv 品牌粉)
  static const defaultAccent = Color(0xFFF09199);

  /// 预设主题色
  static const accentColors = [
    Color(0xFFF09199), // bgm 粉
    Color(0xFF1E90FF), // 蓝
    Color(0xFFFF6B81), // 桃红
    Color(0xFF4CAF50), // 绿
    Color(0xFF9C27B0), // 紫
    Color(0xFFFF9800), // 橙
    Color(0xFF00BCD4), // 青
    Color(0xFF607D8B), // 蓝灰
  ];

  // ---- 中性色 ----
  static const bgLight = Color(0xFFF7F7F7);
  static const bgDark = Color(0xFF181818);
  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF232323);
  static const borderLight = Color(0xFFE5E5E5);
  static const borderDark = Color(0xFF2E2E2E);

  /// 头像占位文字底
  static const placeholderIcon = Color(0x33000000);
  static const placeholderBg = Color(0x0F000000);
}
