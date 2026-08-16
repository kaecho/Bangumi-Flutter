import 'package:flutter/widgets.dart';

/// 原版 `src/assets/iconfont` 码点 (icon-bgm / home / trophy …)
abstract final class BgmIcons {
  static const fontFamily = 'BgmIconfont';

  static const IconData bgm = IconData(0xe61a, fontFamily: fontFamily);
  static const IconData home = IconData(0xe635, fontFamily: fontFamily);
  static const IconData trophy = IconData(0xe682, fontFamily: fontFamily);
  static const IconData star = IconData(0xe799, fontFamily: fontFamily);
  static const IconData setting = IconData(0xe79a, fontFamily: fontFamily);
  static const IconData moon = IconData(0xe74e, fontFamily: fontFamily);
  static const IconData sunny = IconData(0xe6fb, fontFamily: fontFamily);
}
