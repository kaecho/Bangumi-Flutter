import 'package:flutter/material.dart';

import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/app_bar.dart';
import 'widgets/browser_grid.dart';

/// 广告位 / Gal 游戏
///
/// 原项目为本地 protobuf 数据集 + 私有 KV (不可移植), 这里使用
/// bgm.tv 主站游戏浏览页等价实现。
class AdvScreen extends StatelessWidget {
  const AdvScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(title: '找 Gal', showBackButton: true),
      body: BrowserGrid(basePath: htmlRankBrowser('game', sort: 'rank')),
    );
  }
}
