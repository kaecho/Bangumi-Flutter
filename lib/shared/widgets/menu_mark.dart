import 'package:flutter/material.dart';

import '../../core/storage/settings_store.dart';
import '../../design_system/design_system.dart';

/// 原版 IconMenu: 圆底白标, 或 Header 无底叠层
class BgmMenuMark extends StatelessWidget {
  final IconData icon;
  final IconData? badge;
  final String? text;
  final bool wrap;
  final bool? compact;
  final Color? color;
  final double? size;

  const BgmMenuMark({
    super.key,
    required this.icon,
    this.badge,
    this.text,
    this.wrap = true,
    this.compact,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isSm = compact ?? SettingsStore.instance.discoveryMenuNum >= 5;
    final box = wrap ? (isSm ? 46.0 : 50.0) : (size ?? 24);
    final iconSize = (size ?? 24) - (isSm && wrap ? 2 : 0);
    final ink = dark ? const Color(0xFF2A2A2A) : ds.textPrimary;
    final fg = color ?? (wrap ? Colors.white : ds.textPrimary);
    final mark = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (text != null)
          Text(
            text!,
            style: ds.bodyStrong.copyWith(
              fontSize: (size ?? 16) - (isSm ? 2 : 0),
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Icon(icon, size: iconSize, color: fg),
        if (badge != null)
          Positioned(
            right: wrap ? box / 2 - 10 : -2,
            top: wrap ? box / 2 - 6 : 0,
            child: Icon(
              badge,
              size: 9,
              color: wrap
                  ? (dark ? ds.surfaceBase : ds.textPrimary)
                  : ds.textPrimary,
            ),
          ),
      ],
    );
    if (!wrap) {
      return SizedBox(
        width: box,
        height: box,
        child: Center(child: mark),
      );
    }
    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: mark,
    );
  }
}

/// 原版 IconNotify: 信封 + 粉点, 不是数字 Badge
class BgmNotifyMark extends StatelessWidget {
  final bool unread;
  final Color? color;

  const BgmNotifyMark({super.key, required this.unread, this.color});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Icon(
              Icons.mail_outline,
              size: 22,
              color: color ?? ds.textPrimary,
            ),
          ),
          if (unread)
            Positioned(
              top: 6,
              left: 22,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: ds.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: ds.surfaceBase, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
