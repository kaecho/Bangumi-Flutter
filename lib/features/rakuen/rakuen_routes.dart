import 'package:go_router/go_router.dart';

import 'blog_screen.dart';
import 'board_screen.dart';
import 'group_screen.dart';
import 'history_screen.dart';
import 'image_viewer_screen.dart';
import 'mine_screen.dart';
import 'notify_screen.dart';
import 'reviews_screen.dart';
import 'search_screen.dart';
import 'setting_screen.dart';
import 'topic_screen.dart';
import 'ugc_agree_screen.dart';

/// 超展开域路由
final List<GoRoute> rakuenRoutes = [
  // 帖子详情: type ∈ group|subject|ep|prsn|crt; blog 类型直接进日志页
  GoRoute(
    path: '/rakuen/topic/:type/:id',
    builder: (_, state) {
      final type = state.pathParameters['type'] ?? '';
      final id = state.pathParameters['id'] ?? '';
      if (type == 'blog') {
        final blogId = int.tryParse(id) ?? 0;
        return BlogScreen(id: blogId);
      }
      return TopicScreen(type: type, id: id);
    },
  ),
  GoRoute(
    path: '/rakuen/blog/:id',
    builder: (_, state) =>
        BlogScreen(id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0),
  ),
  GoRoute(
    path: '/rakuen/group/:name',
    builder: (_, state) => GroupScreen(name: state.pathParameters['name'] ?? ''),
  ),
  GoRoute(
    path: '/rakuen/board/:key',
    builder: (_, state) => BoardScreen(boardKey: state.pathParameters['key'] ?? 'topiclist'),
  ),
  GoRoute(
    path: '/rakuen/notify',
    builder: (_, _) => const NotifyScreen(),
  ),
  GoRoute(
    path: '/rakuen/history',
    builder: (_, _) => const HistoryScreen(),
  ),
  GoRoute(
    path: '/rakuen/mine',
    builder: (_, _) => const MineScreen(),
  ),
  GoRoute(
    path: '/rakuen/search',
    builder: (_, _) => const RakuenSearchScreen(),
  ),
  GoRoute(
    path: '/rakuen/setting',
    builder: (_, _) => const RakuenSettingScreen(),
  ),
  GoRoute(
    path: '/rakuen/reviews/:subjectId',
    builder: (_, state) =>
        ReviewsScreen(subjectId: int.tryParse(state.pathParameters['subjectId'] ?? '') ?? 0),
  ),
  GoRoute(
    path: '/rakuen/ugc-agree',
    builder: (_, _) => const UgcAgreeScreen(),
  ),
  GoRoute(
    path: '/rakuen/image',
    builder: (_, state) =>
        ImageViewerScreen(url: state.uri.queryParameters['url'] ?? ''),
  ),
];
