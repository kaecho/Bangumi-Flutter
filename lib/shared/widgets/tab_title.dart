import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/settings_store.dart';
import '../../design_system/design_system.dart';
import 'breathing_light.dart';
import 'bgm_button.dart';

/// 原版 LogoHeader: 左右 80pt 槽 + 居中 Bangumi 图标
///
/// 点按切主题 (需 logoToggleTheme)、长按进设置。
class LogoHeader extends ConsumerWidget implements PreferredSizeWidget {
  final Widget? leading;
  final Widget? trailing;
  final bool implyLeading;

  const LogoHeader({
    super.key,
    this.leading,
    this.trailing,
    this.implyLeading = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = context.ds;
    return AppBar(
      backgroundColor: ds.surfaceBase,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leadingWidth: 120,
      titleSpacing: 0,
      leading: SizedBox(
        width: 120,
        child: Align(
          alignment: Alignment.centerLeft,
          child:
              leading ??
              (implyLeading && Navigator.of(context).canPop()
                  ? BgmHeaderAction(
                      icon: Icon(Icons.arrow_back, color: ds.textPrimary),
                      onPressed: () => Navigator.of(context).maybePop(),
                    )
                  : const SizedBox.shrink()),
        ),
      ),
      title: const _BgmLogo(),
      actions: [
        SizedBox(
          width: 120,
          child: Align(
            alignment: Alignment.centerRight,
            child: trailing ?? const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _BgmLogo extends ConsumerWidget {
  const _BgmLogo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(settingsStoreProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: store.logoToggleTheme ? () => store.toggleThemeMode() : null,
          onLongPress: () => context.push('/settings'),
          child: Icon(BgmIcons.bgm, size: 22, color: context.ds.textPrimary),
        ),
        const ServerStatusLight(),
      ],
    );
  }
}

/// 兼容旧调用: 主 Tab 不再显示文字标题
class TabLogoTitle extends StatelessWidget {
  final String text;

  const TabLogoTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => const _BgmLogo();
}
