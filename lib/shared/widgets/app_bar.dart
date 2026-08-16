import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/design_system.dart';
import 'bgm_button.dart';

/// 自定义 AppBar (毛玻璃效果, 移植自原项目 header-v2)
class BgmAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool? showBackButton;
  final bool transparent;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const BgmAppBar({
    super.key,
    this.title = '',
    this.titleWidget,
    this.actions,
    this.leading,
    this.bottom,
    this.showBackButton,
    this.transparent = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final showBack =
        showBackButton ?? (ModalRoute.of(context)?.canPop ?? false);
    final fg = foregroundColor ?? ds.textPrimary;
    final bg =
        backgroundColor ?? (transparent ? Colors.transparent : ds.surfaceBase);
    final theme = Theme.of(context);
    final overlayStyle = fg.computeLuminance() > 0.5
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnimatedTheme(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      data: theme.copyWith(
        iconTheme: IconThemeData(color: fg),
        appBarTheme: theme.appBarTheme.copyWith(
          foregroundColor: fg,
          iconTheme: IconThemeData(color: fg),
          actionsIconTheme: IconThemeData(color: fg),
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        systemOverlayStyle: overlayStyle,
        flexibleSpace: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          color: bg,
        ),
        leading:
            leading ??
            (showBack
                ? BgmHeaderAction(
                    tooltip: '返回',
                    icon: Icon(Icons.arrow_back, color: fg),
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                : null),

        automaticallyImplyLeading: showBack,
        titleSpacing: 0,
        title:
            titleWidget ??
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              style: TextStyle(color: fg),
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        actions: actions,
        bottom: bottom,
      ),
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
    return Scaffold(backgroundColor: context.ds.surfaceBase, body: content);
  }
}
