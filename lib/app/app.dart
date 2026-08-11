import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

/// 应用根组件
class BangumiApp extends ConsumerWidget {
  const BangumiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final primary = ref.watch(themeColorProvider);

    return MaterialApp.router(
      title: 'Bangumi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(primary),
      darkTheme: AppTheme.dark(primary),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
