import 'package:flutter/material.dart';

import 'sync_webview_scaffold.dart';

/// bilibili 同步 (移植自原项目 screens/web-view/bilibili-sync)
///
/// 原项目在 WebView 内打开 bilibili 账号页并注入脚本抓取追番列表,
/// 本页保留核心流程: WebView 内登录 bilibili → 完成同步 → 点「完成」返回。
/// 路由: /sync/bilibili
class BilibiliSyncScreen extends StatelessWidget {
  const BilibiliSyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SyncWebViewScaffold(
      title: 'bilibili 同步',
      url: 'https://account.bilibili.com/space?from=headline',
      domain: 'bilibili.com',
    );
  }
}
