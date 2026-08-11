import 'package:go_router/go_router.dart';

import 'bilibili_sync_screen.dart';
import 'douban_sync_screen.dart';
import 'information_screen.dart';
import 'log_screen.dart';
import 'playground_screen.dart';
import 'proxy_help_screen.dart';
import 'share_screen.dart';
import 'tips_screen.dart';
import 'versions_screen.dart';
import 'web_browser_screen.dart';
import 'webhook_screen.dart';

/// WebView 域路由
final List<GoRoute> webviewRoutes = [
  // 内置浏览器: url 需 Uri.encodeComponent 编码, 可选 title 查询参数
  GoRoute(
    path: '/web/:url',
    builder: (context, state) => WebBrowserScreen(
      url: state.pathParameters['url'] ?? '',
      title: state.uri.queryParameters['title'],
    ),
  ),
  GoRoute(path: '/sync/bilibili', builder: (_, _) => const BilibiliSyncScreen()),
  GoRoute(path: '/sync/douban', builder: (_, _) => const DoubanSyncScreen()),
  GoRoute(
    path: '/share/:subjectId',
    builder: (_, state) => ShareScreen(
      subjectId: int.tryParse(state.pathParameters['subjectId'] ?? '') ?? 0,
    ),
  ),
  GoRoute(path: '/versions', builder: (_, _) => const VersionsScreen()),
  GoRoute(path: '/tips', builder: (_, _) => const TipsScreen()),
  GoRoute(path: '/proxy-help', builder: (_, _) => const ProxyHelpScreen()),
  GoRoute(path: '/webhook', builder: (_, _) => const WebhookScreen()),
  GoRoute(path: '/log', builder: (_, _) => const LogScreen()),
  GoRoute(path: '/about', builder: (_, _) => const InformationScreen()),
  GoRoute(path: '/playground', builder: (_, _) => const PlaygroundScreen()),
];
