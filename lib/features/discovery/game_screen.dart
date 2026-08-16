import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/storage/settings_store.dart';
import '../../shared/widgets/app_bar.dart';
import 'widgets/browser_grid.dart';
import '../../shared/widgets/bgm_button.dart';
import 'widgets/filter_switch.dart';

/// 游戏列表
///
/// 原项目使用本地打包数据集 (不可移植), 这里使用 bgm.tv 主站游戏浏览页
/// 等价实现: /game/browser?sort=rank&page=..
/// Extra 对齐原版: 切布局 + 回顶。
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(settingsStoreProvider);
    return Scaffold(
      appBar: BgmAppBar(
        title: '找游戏',
        showBackButton: true,
        actions: [
          BgmDiscoveryExtra(
            isList: store.discoveryList,
            onToggleLayout: () => store.setDiscoveryList(!store.discoveryList),
            onScrollToTop: () => scrollBgmToTop(_scroll),
          ),
        ],
      ),
      body: Column(
        children: [
          const DiscoveryFilterSwitch(name: '游戏'),
          Expanded(
            child: BrowserGrid(
              basePath: htmlRankBrowser('game', sort: 'rank'),
              isList: store.discoveryList,
              controller: _scroll,
            ),
          ),
        ],
      ),
    );
  }
}
