import 'package:go_router/go_router.dart';

import 'say_screen.dart';

/// 时间线域路由
final List<GoRoute> timelineRoutes = [
  // 吐槽详情
  GoRoute(
    path: '/timeline/say/:id',
    builder: (_, state) => SayScreen(
      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
];
