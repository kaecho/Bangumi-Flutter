import 'package:flutter/material.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import 'widgets/browser_grid.dart';

/// 漫画/文库 (书籍) 列表
///
/// 原项目漫画 (manga) 与文库 (wenku) 均为本地打包数据集 (不可移植),
/// 这里使用 bgm.tv 主站书籍浏览页等价实现: /book/browser?sort=rank&page=..
class MangaScreen extends StatelessWidget {
  final String title;

  const MangaScreen({super.key, this.title = '漫画'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: title,
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: '浏览器查看',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => openExternalUrl(
              '$kHost${htmlRankBrowser('book', sort: 'rank')}',
            ),
          ),
        ],
      ),
      body: BrowserGrid(basePath: htmlRankBrowser('book', sort: 'rank')),
    );
  }
}
