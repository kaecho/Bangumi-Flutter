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
import '../shared/widgets/site_notice.dart';

/// 底部 Tab 容器
///
/// 与原项目 [bottom-tab-navigator] 一致: 6 个潜 Tab
/// (发现 / 时间线 / 首页 / 超展开 / 我的 / 小圣杯), 其中
/// - 发现 / 时间线 / 超展开 受设置 homeRenderTabs 控制 (可隐藏)
/// - 首页 / 我的 始终显示 (原项目 showCondition: () => true)
/// - 小圣杯 受 setting.tinygrail + homeRenderTabs 双重控制
/// - bottomTabLazy: true 时仅构建可见 Tab 的页面 (原项目 lazy)
class TabShell extends ConsumerStatefulWidget {
  final int initialIndex;

  const TabShell({super.key, required this.initialIndex});

  @override
  ConsumerState<TabShell> createState() => _TabShellState();
}

class _TabShellState extends ConsumerState<TabShell> {
  late int _index = widget.initialIndex;

  /// 6 个潜 Tab (顺序与原项目 getTabConfig 一致)
  static const _allTabs = <_TabDef>[
    _TabDef(
      key: 'Discovery',
      label: '发现',
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      path: '/discovery',
      child: DiscoveryScreen(),
      alwaysShow: false,
    ),
    _TabDef(
      key: 'Timeline',
      label: '时间线',
      icon: Icons.timeline_outlined,
      activeIcon: Icons.timeline,
      path: '/timeline',
      child: TimelineScreen(),
      alwaysShow: false,
    ),
    _TabDef(
      key: 'Home',
      label: '首页',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      path: '/progress',
      child: ProgressScreen(),
      alwaysShow: true,
    ),
    _TabDef(
      key: 'Rakuen',
      label: '超展开',
      icon: Icons.forum_outlined,
      activeIcon: Icons.forum,
      path: '/rakuen',
      child: RakuenScreen(),
      alwaysShow: false,
    ),
    _TabDef(
      key: 'User',
      label: '我的',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      path: '/user',
      child: UserScreen(),
      alwaysShow: true,
    ),
    _TabDef(
      key: 'Tinygrail',
      label: '小圣杯',
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events,
      path: '/tinygrail',
      child: TinygrailScreen(),
      alwaysShow: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final setting = ref.watch(settingsStoreProvider);
    final homeRenderTabs = setting.homeRenderTabs.toSet();

    final tabs = _allTabs.where((t) {
      if (t.key == 'Tinygrail') {
        return setting.tinygrailEnabled && homeRenderTabs.contains(t.key);
      }
      return t.alwaysShow || homeRenderTabs.contains(t.key);
    }).toList();

    // initialIndex 由路由传入; 越界 (Tab 被隐藏) 回落到 首页
    if (_index >= tabs.length) {
      _index = tabs.indexWhere((t) => t.key == 'Home');
    }
    if (_index < 0) _index = 0;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < tabs.length; i++) tabs[i].child],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SiteNoticeBanner(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              setState(() => _index = i);
              context.go(tabs[i].path);
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
        ],
      ),
    );
  }
}

class _TabDef {
  final String key;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;
  final Widget child;
  final bool alwaysShow;

  const _TabDef({
    required this.key,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
    required this.child,
    required this.alwaysShow,
  });
}
