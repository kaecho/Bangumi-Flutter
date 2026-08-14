import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/settings_store.dart';
import 'router.dart';
import 'theme.dart';

/// 应用根组件
class BangumiApp extends ConsumerWidget {
  const BangumiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(settingsStoreProvider);
    final themeMode = ref.watch(themeModeProvider);
    final primary = ref.watch(themeColorProvider);
    final scale = 1 + store.fontSizeAdjust * 0.06;
    return MaterialApp.router(
      title: 'Bangumi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(primary),
      darkTheme: AppTheme.dark(primary, deepDark: store.deepDark),

      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final content = child ?? const SizedBox.shrink();
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: store.letterSpacing == 0
              ? content
              : DefaultTextStyle.merge(
                  style: TextStyle(letterSpacing: store.letterSpacing),
                  child: content,
                ),
        );
      },
    );
  }
}
