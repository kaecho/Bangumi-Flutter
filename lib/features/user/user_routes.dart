import 'package:go_router/go_router.dart';

import 'actions_screen.dart';
import 'backup_screen.dart';
import 'blogs_screen.dart';
import 'catalogs_screen.dart';
import 'dev_screen.dart';
import 'friends_screen.dart';
import 'login_screen.dart';
import 'milestone_screen.dart';
import 'mono_screen.dart';
import 'origin_setting_screen.dart';
import 'pm_screen.dart';
import 'qiafan_screen.dart';
import 'server_status_screen.dart';
import 'setting_screen.dart';
import 'smb_screen.dart';
import 'sponsor_screen.dart';
import 'user_setting_screen.dart';
import 'user_screen.dart';
import 'user_timeline_screen.dart';
import 'zone_screen.dart';

/// 用户域路由
final List<GoRoute> userRoutes = [
  GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
  GoRoute(
    path: '/user/:type/collections',
    builder: (_, state) => UserCollectionsScreen(type: state.pathParameters['type'] ?? 'anime'),
  ),
  // 用户空间
  GoRoute(
    path: '/user/:id',
    builder: (_, state) => ZoneScreen(userId: state.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: '/user/:id/timeline',
    builder: (_, state) => UserTimelineScreen(userId: state.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: '/user/:id/milestone',
    builder: (_, state) => MilestoneScreen(userId: state.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: '/user/:id/blogs',
    builder: (_, state) => UserBlogsScreen(userId: state.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: '/user/:id/catalogs',
    builder: (_, state) => UserCatalogsScreen(userId: state.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: '/user/:id/friends',
    builder: (_, state) => FriendsScreen(userId: state.pathParameters['id'] ?? ''),
  ),
  // 短信
  GoRoute(path: '/pm', builder: (_, _) => const PmScreen()),
  GoRoute(
    path: '/pm/chat/:uid',
    builder: (_, state) => PmChatScreen(
      userId: state.pathParameters['uid'] ?? '',
      convId: state.uri.queryParameters['conv'],
    ),
  ),
  // 设置
  GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
  GoRoute(path: '/settings/backup', builder: (_, _) => const BackupScreen()),
  GoRoute(path: '/settings/smb', builder: (_, _) => const SmbScreen()),
  GoRoute(path: '/settings/user', builder: (_, _) => const UserSettingScreen()),
  GoRoute(path: '/settings/origin', builder: (_, _) => const OriginSettingScreen()),
  GoRoute(path: '/settings/status', builder: (_, _) => const ServerStatusScreen()),
  GoRoute(path: '/settings/sponsor', builder: (_, _) => const SponsorScreen()),
  GoRoute(path: '/settings/actions', builder: (_, _) => const ActionsScreen()),
  GoRoute(path: '/settings/dev', builder: (_, _) => const DevScreen()),
  GoRoute(path: '/settings/qiafan', builder: (_, _) => const QiafanScreen()),
  // 我的快捷入口
  GoRoute(path: '/my-friends', builder: (_, _) => const MyFriendsScreen()),
  GoRoute(path: '/my-blogs', builder: (_, _) => const MyBlogsScreen()),
  GoRoute(path: '/my-catalogs', builder: (_, _) => const MyCatalogsScreen()),
  GoRoute(path: '/my-mono', builder: (_, _) => const MyMonoScreen()),
];
