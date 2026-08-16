import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/storage/settings_store.dart';
import '../../shared/widgets/app_bar.dart';
import 'widgets/browser_grid.dart';
import '../../shared/widgets/bgm_button.dart';
import 'widgets/filter_switch.dart';

/// 广告位 / Gal 游戏
///
/// 原项目为本地 protobuf 数据集 + 私有 KV (不可移植), 这里使用
/// bgm.tv 主站游戏浏览页等价实现。
/// Extra 对齐原版找游戏: 切布局 + 回顶。
class AdvScreen extends ConsumerStatefulWidget {
  const AdvScreen({super.key});

  @override
  ConsumerState<AdvScreen> createState() => _AdvScreenState();
}

class _AdvScreenState extends ConsumerState<AdvScreen> {
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
        title: '找 Gal',
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
          const DiscoveryFilterSwitch(name: 'ADV'),
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
