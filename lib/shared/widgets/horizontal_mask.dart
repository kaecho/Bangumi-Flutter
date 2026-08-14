import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/settings_store.dart';

/// 横向列表两侧溢出遮罩 (原项目 horizontalShowMask)
class HorizontalMask extends ConsumerWidget {
  final Widget child;
  final double height;

  const HorizontalMask({super.key, required this.child, this.height = 24});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(settingsStoreProvider).horizontalShowMask) return child;
    final color = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: height,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: height,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0), color],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
