import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/storage/settings_store.dart';
import '../../shared/widgets/app_bar.dart';
import 'widgets/browser_grid.dart';
import '../../shared/widgets/bgm_button.dart';
import 'widgets/filter_switch.dart';

/// 漫画/文库 (书籍) 列表
///
/// 原项目漫画 (manga) 与文库 (wenku) 均为本地打包数据集 (不可移植),
/// 这里使用 bgm.tv 主站书籍浏览页等价实现: /book/browser?sort=rank&page=..
/// Extra 对齐原版找游戏/漫画: 切布局 + 回顶。
class MangaScreen extends ConsumerStatefulWidget {
  final String title;

  const MangaScreen({super.key, this.title = '找漫画'});

  @override
  ConsumerState<MangaScreen> createState() => _MangaScreenState();
}

class _MangaScreenState extends ConsumerState<MangaScreen> {
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
        title: widget.title,
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
          DiscoveryFilterSwitch(name: widget.title == '找文库' ? '文库' : '漫画'),
          Expanded(
            child: BrowserGrid(
              basePath: htmlRankBrowser('book', sort: 'rank'),
              isList: store.discoveryList,
              controller: _scroll,
            ),
          ),
        ],
      ),
    );
  }
}
