import 'package:flutter/material.dart';

import 'sync_webview_scaffold.dart';

/// 豆瓣同步 (移植自原项目 screens/web-view/douban-sync)
///
/// 原项目通过豆瓣账号页 + 收藏 XML 匹配同步, 本页保留核心流程:
/// WebView 内登录豆瓣 → 完成同步 → 点「完成」返回。
/// 路由: /sync/douban
class DoubanSyncScreen extends StatelessWidget {
  const DoubanSyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SyncWebViewScaffold(
      title: '豆瓣同步',
      url: 'https://www.douban.com/',
      domain: 'douban.com',
    );
  }
}
