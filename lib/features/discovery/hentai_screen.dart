import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/storage/settings_store.dart';
import '../../shared/widgets/app_bar.dart';
import 'widgets/browser_grid.dart';
import '../../shared/widgets/bgm_button.dart';
import 'widgets/filter_switch.dart';

/// 里番
///
/// 原项目使用本地私有数据集 h.min.json + 私有 KV 服务 (均不可移植/
/// 不可达), 这里使用最近的官方等价数据: bgm.tv 动画浏览页 (按热度排序)。
/// Extra 对齐原版找番剧: 切布局 + 回顶。
class HentaiScreen extends ConsumerStatefulWidget {
  const HentaiScreen({super.key});

  @override
  ConsumerState<HentaiScreen> createState() => _HentaiScreenState();
}

class _HentaiScreenState extends ConsumerState<HentaiScreen> {
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
        title: '找番剧',
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
          const DiscoveryFilterSwitch(name: 'NSFW'),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('此页面已不再维护'),
            ),
          ),
          Expanded(
            child: BrowserGrid(
              basePath: htmlRankBrowser('anime', sort: 'trends'),
              isList: store.discoveryList,
              controller: _scroll,
            ),
          ),
        ],
      ),
    );
  }
}
