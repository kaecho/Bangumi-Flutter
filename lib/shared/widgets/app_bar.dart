import 'package:flutter/material.dart';

/// 自定义 AppBar (毛玻璃效果, 移植自原项目 header-v2)
class BgmAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final bool transparent;
  final Color? backgroundColor;

  const BgmAppBar({
    super.key,
    this.title = '',
    this.titleWidget,
    this.actions,
    this.leading,
    this.showBackButton = false,
    this.transparent = false,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: backgroundColor ??
          (transparent ? Colors.transparent : theme.scaffoldBackgroundColor),
      elevation: 0,
      leading: leading ??
          (showBackButton
              ? BackButton(color: theme.colorScheme.onSurface)
              : null),
      titleSpacing: 0,
      title: titleWidget ??
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      actions: actions,
    );
  }
}

/// 页面容器 (统一背景 + SafeArea)
class BgmPage extends StatelessWidget {
  final Widget child;
  final bool withSafeArea;

  const BgmPage({super.key, required this.child, this.withSafeArea = true});

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (withSafeArea) {
      content = SafeArea(child: content);
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: content,
    );
  }
}
