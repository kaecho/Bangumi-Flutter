import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/settings_store.dart';
import 'breathing_light.dart';

/// 主 Tab 标题: 点按切主题、长按进设置, 旁侧服务可用性灯
class TabLogoTitle extends ConsumerWidget {
  final String text;

  const TabLogoTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(settingsStoreProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: GestureDetector(
            onTap: store.logoToggleTheme ? () => store.toggleThemeMode() : null,
            onLongPress: () => context.push('/settings'),
            child: Text(text, overflow: TextOverflow.ellipsis),
          ),
        ),
        const ServerStatusLight(),
      ],
    );
  }
}
