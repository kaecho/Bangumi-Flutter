import 'package:go_router/go_router.dart';

import '../core/storage/settings_store.dart';

import '../features/discovery/discovery_routes.dart';
import '../features/progress/progress_routes.dart';
import '../features/rakuen/rakuen_routes.dart';
import '../features/subject/subject_routes.dart';
import '../features/timeline/timeline_routes.dart';
import '../features/tinygrail/tinygrail_routes.dart';
import '../features/user/user_routes.dart';
import '../features/webview/webview_routes.dart';
import 'tab_shell.dart';

/// 初始页: 与原项目 [getInitialRouteName] 一致, 受设置 initialPage 控制。
/// 注意 [SettingsStore] 在 main() 中先于 runApp 完成 init, 故此处可安全读取。
String _initialPath() {
  switch (SettingsStore.instance.initialPage) {
    case 'Discovery':
      return '/discovery';
    case 'Timeline':
      return '/timeline';
    case 'Rakuen':
      return '/rakuen';
    case 'User':
      return '/user';
    case 'Home':
    default:
      return '/progress';
  }
}

/// 全局路由表
///
/// - 每个 feature 维护自己的 routes 文件 (feature_routes.dart), 在此聚合
/// - Tab 页在 [TabShell] 中, 独立路由 (不走 ShellRoute), 由底部导航切换
final appRouter = GoRouter(
  initialLocation: _initialPath(),
  routes: [
    GoRoute(path: '/', redirect: (_, _) => _initialPath()),
    GoRoute(
      path: '/discovery',
      builder: (_, _) => const TabShell(initialIndex: 0),
    ),
    GoRoute(
      path: '/timeline',
      builder: (_, _) => const TabShell(initialIndex: 1),
    ),
    GoRoute(
      path: '/progress',
      builder: (_, _) => const TabShell(initialIndex: 2),
    ),
    GoRoute(
      path: '/rakuen',
      builder: (_, _) => const TabShell(initialIndex: 3),
    ),
    GoRoute(path: '/user', builder: (_, _) => const TabShell(initialIndex: 4)),
    GoRoute(
      path: '/tinygrail',
      builder: (_, _) => const TabShell(initialIndex: 5),
    ),
    // 各 feature 的独立页面路由
    ...discoveryRoutes,
    ...subjectRoutes,
    ...progressRoutes,
    ...timelineRoutes,
    ...rakuenRoutes,
    ...userRoutes,
    ...tinygrailRoutes,
    ...webviewRoutes,
  ],
);
