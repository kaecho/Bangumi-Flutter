import 'package:flutter/material.dart';

import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/app_bar.dart';
import 'widgets/browser_grid.dart';

/// 游戏列表
///
/// 原项目使用本地打包数据集 (不可移植), 这里使用 bgm.tv 主站游戏浏览页
/// 等价实现: /game/browser?sort=rank&page=..
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(title: '游戏', showBackButton: true),
      body: BrowserGrid(basePath: htmlRankBrowser('game', sort: 'rank')),
    );
  }
}
