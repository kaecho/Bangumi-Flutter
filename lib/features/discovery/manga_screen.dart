import 'package:flutter/material.dart';

import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/app_bar.dart';
import 'widgets/browser_grid.dart';

/// 漫画 (书籍) 列表
///
/// 原项目为文库 (wenku) 本地数据集 (不可移植), 这里使用 bgm.tv 主站
/// 书籍浏览页等价实现: /book/browser?sort=rank&page=..
class MangaScreen extends StatelessWidget {
  const MangaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(title: '漫画', showBackButton: true),
      body: BrowserGrid(basePath: htmlRankBrowser('book', sort: 'rank')),
    );
  }
}
