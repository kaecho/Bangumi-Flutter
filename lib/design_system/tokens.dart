import 'package:flutter/widgets.dart';

/// 间距 token — 全 App 只允许使用这里的值
abstract final class AppGap {
  static const double x1 = 2;
  static const double x2 = 4;
  static const double x3 = 6;
  static const double x4 = 8;
  static const double x5 = 10;
  static const double x6 = 12;
  static const double x7 = 14;
  static const double x8 = 16;
  static const double x10 = 24;

  /// 页面水平边距
  static const pageH = EdgeInsets.symmetric(horizontal: x6);

  /// 列表项内边距 (横向 12, 纵向 10)
  static const listItem = EdgeInsets.symmetric(horizontal: x6, vertical: x5);

  /// 列表底部留白
  static const listBottom = EdgeInsets.only(bottom: x10);

  /// 卡片/容器内边距
  static const card = EdgeInsets.all(x5);
}

/// 圆角 token
abstract final class AppRadius {
  static const double s = 4;
  static const double m = 6;
  static const double l = 8;
  static const double xl = 12;

  static const sAll = BorderRadius.all(Radius.circular(s));
  static const mAll = BorderRadius.all(Radius.circular(m));
  static const lAll = BorderRadius.all(Radius.circular(l));
  static const xlAll = BorderRadius.all(Radius.circular(xl));

  /// 底部弹窗等顶部圆角
  static const sheetTop = BorderRadius.vertical(top: Radius.circular(xl));
}
