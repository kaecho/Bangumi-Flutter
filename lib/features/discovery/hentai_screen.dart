import 'package:flutter/material.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import 'widgets/browser_grid.dart';

/// 里番
///
/// 原项目使用本地私有数据集 h.min.json + 私有 KV 服务 (均不可移植/
/// 不可达), 这里使用最近的官方等价数据: bgm.tv 动画浏览页 (按热度排序)。
class HentaiScreen extends StatelessWidget {
  const HentaiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: '里番',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: '浏览器查看',

            icon: const Icon(Icons.open_in_browser),
            onPressed: () => openExternalUrl(
              '$kHost${htmlRankBrowser('anime', sort: 'trends')}',
            ),
          ),
        ],
      ),
      body: BrowserGrid(basePath: htmlRankBrowser('anime', sort: 'trends')),
    );
  }
}
