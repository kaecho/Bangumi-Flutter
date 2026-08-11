import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/storage/settings_store.dart';
import '../features/discovery/discovery_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/rakuen/rakuen_screen.dart';
import '../features/timeline/timeline_screen.dart';
import '../features/tinygrail/tinygrail_screen.dart';
import '../features/user/user_screen.dart';

/// 底部 Tab 容器: 6 个 Tab (与原项目 bottom-tab-navigator 一致)
class TabShell extends ConsumerStatefulWidget {
  final int initialIndex;

  const TabShell({super.key, required this.initialIndex});

  @override
  ConsumerState<TabShell> createState() => _TabShellState();
}

class _TabShellState extends ConsumerState<TabShell> {
  late int _index = widget.initialIndex;

  static const _tabs = [
    (label: '发现', icon: Icons.explore_outlined, activeIcon: Icons.explore),
    (label: '时间线', icon: Icons.timeline_outlined, activeIcon: Icons.timeline),
    (label: '首页', icon: Icons.home_outlined, activeIcon: Icons.home),
    (label: '超展开', icon: Icons.forum_outlined, activeIcon: Icons.forum),
    (label: '我的', icon: Icons.person_outline, activeIcon: Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    final tinygrail = ref.watch(settingsStoreProvider).tinygrailEnabled;
    final tabs = [..._tabs, if (tinygrail) (label: '小圣杯', icon: Icons.emoji_events_outlined, activeIcon: Icons.emoji_events)];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const DiscoveryScreen(),
          const TimelineScreen(),
          const ProgressScreen(),
          const RakuenScreen(),
          const UserScreen(),
          if (tinygrail) const TinygrailScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          final paths = ['/discovery', '/timeline', '/progress', '/rakuen', '/user', '/tinygrail'];
          context.go(paths[i]);
        },
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.activeIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
