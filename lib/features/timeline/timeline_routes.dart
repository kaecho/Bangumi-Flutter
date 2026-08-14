import 'package:go_router/go_router.dart';

import 'say_screen.dart';

/// 时间线域路由
final List<GoRoute> timelineRoutes = [
  GoRoute(
    path: '/timeline/say/new',
    builder: (_, _) => const SayComposeScreen(),
  ),
  GoRoute(
    path: '/timeline/say/:id',
    builder: (_, state) =>
        SayScreen(id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0),
  ),
];
