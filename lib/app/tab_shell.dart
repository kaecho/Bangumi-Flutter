import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/storage/settings_store.dart';
import '../design_system/design_system.dart';
import '../features/discovery/discovery_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/rakuen/rakuen_screen.dart';
import '../features/timeline/timeline_screen.dart';
import '../features/tinygrail/tinygrail_screen.dart';
import '../features/user/user_screen.dart';
import '../shared/widgets/site_notice.dart';
import '../shared/widgets/tab_bar.dart';

/// 底部 Tab 容器
///
/// 与原项目 [bottom-tab-navigator] 一致: 6 个潜 Tab
/// (发现 / 时间胶囊 / 收藏 / 超展开 / 时光机 / 小圣杯)
class TabShell extends ConsumerStatefulWidget {
  final int initialIndex;

  const TabShell({super.key, required this.initialIndex});

  @override
  ConsumerState<TabShell> createState() => _TabShellState();
}

class _TabShellState extends ConsumerState<TabShell> {
  late int _index = widget.initialIndex;
  final _built = <int>{};

  /// 顺序与原项目 getTabConfig / routesConfig 一致
  static const _allTabs = <BgmTabItem>[
    BgmTabItem(
      key: 'Discovery',
      label: '发现',
      icon: BgmIcons.home,
      iconSize: 19,
      path: '/discovery',
      child: DiscoveryScreen(),
      alwaysShow: false,
    ),
    BgmTabItem(
      key: 'Timeline',
      label: '时间胶囊',
      icon: Icons.access_time,
      iconSize: 21,
      path: '/timeline',
      child: TimelineScreen(),
      alwaysShow: false,
    ),
    BgmTabItem(
      key: 'Home',
      label: '收藏',
      icon: Icons.star_outline,
      path: '/progress',
      child: ProgressScreen(),
      alwaysShow: true,
    ),
    BgmTabItem(
      key: 'Rakuen',
      label: '超展开',
      icon: Icons.chat_bubble_outline,
      iconSize: 19,
      path: '/rakuen',
      child: RakuenScreen(),
      alwaysShow: false,
    ),
    BgmTabItem(
      key: 'User',
      label: '时光机',
      icon: Icons.person_outline,
      path: '/user',
      child: UserScreen(),
      alwaysShow: true,
    ),
    BgmTabItem(
      key: 'Tinygrail',
      label: '小圣杯',
      icon: BgmIcons.trophy,
      iconSize: 19,
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

    // initialIndex 由路由传入; 越界 (Tab 被隐藏) 回落到 收藏
    if (_index >= tabs.length) {
      _index = tabs.indexWhere((t) => t.key == 'Home');
    }
    if (_index < 0) _index = 0;
    _built.add(_index);

    final lazy = setting.bottomTabLazy;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < tabs.length; i++)
            !lazy || _built.contains(i)
                ? tabs[i].child
                : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SiteNoticeBanner(),
          BgmTabBar(
            tabs: tabs,
            index: _index,
            onSelect: (i) {
              setState(() => _index = i);
              context.go(tabs[i].path);
            },
          ),
        ],
      ),
    );
  }
}
