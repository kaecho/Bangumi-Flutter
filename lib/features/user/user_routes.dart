import 'package:go_router/go_router.dart';

import 'login_screen.dart';
import 'user_screen.dart';

/// 用户域路由
final List<GoRoute> userRoutes = [
  GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
  GoRoute(
    path: '/user/:type/collections',
    builder: (_, state) => UserCollectionsScreen(type: state.pathParameters['type'] ?? 'anime'),
  ),
  // GoRoute(path: '/user/:id', builder: (_, _) => const ZoneScreen()),
  // GoRoute(path: '/user/:id/timeline', builder: (_, _) => const UserTimelineScreen()),
  // GoRoute(path: '/user/:id/milestone', builder: (_, _) => const MilestoneScreen()),
  // GoRoute(path: '/user/:id/blogs', builder: (_, _) => const UserBlogsScreen()),
  // GoRoute(path: '/user/:id/catalogs', builder: (_, _) => const UserCatalogsScreen()),
  // GoRoute(path: '/user/:id/friends', builder: (_, _) => const FriendsScreen()),
  // GoRoute(path: '/pm', builder: (_, _) => const PmScreen()),
  // GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
  // GoRoute(path: '/settings/backup', builder: (_, _) => const BackupScreen()),
  // GoRoute(path: '/settings/smb', builder: (_, _) => const SmbScreen()),
  // GoRoute(path: '/settings/user', builder: (_, _) => const UserSettingScreen()),
  // GoRoute(path: '/settings/origin', builder: (_, _) => const OriginSettingScreen()),
  // GoRoute(path: '/settings/status', builder: (_, _) => const ServerStatusScreen()),
  // GoRoute(path: '/my-friends', builder: (_, _) => const MyFriendsScreen()),
  // GoRoute(path: '/my-blogs', builder: (_, _) => const MyBlogsScreen()),
  // GoRoute(path: '/my-catalogs', builder: (_, _) => const MyCatalogsScreen()),
  // GoRoute(path: '/my-mono', builder: (_, _) => const MyMonoScreen()),
];
