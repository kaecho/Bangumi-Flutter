import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_bar.dart';
import 'series_notes.dart';

PreferredSizeWidget seriesAppBar({
  required BuildContext context,
  required VoidCallback onRefresh,
}) {
  return BgmAppBar(
    title: '关联系列',
    showBackButton: true,
    actions: [
      IconButton(
        tooltip: '刷新',
        icon: const Icon(Icons.refresh),
        onPressed: () {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('刷新关联系列'),
              content: const Text('确定刷新?'),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onRefresh();
                  },
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        },
      ),
      IconButton(
        tooltip: '说明',
        icon: const Icon(Icons.info_outline),
        onPressed: () => context.push(seriesNotePath()),
      ),
    ],
  );
}
