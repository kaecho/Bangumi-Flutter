import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/format.dart';
import 'rakuen_models.dart';
import 'rakuen_providers.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';

/// 浏览历史 (port 特有功能: 本地浏览记录, 与原版 rakuen/history 语义不同)
/// 路由: /history/browse
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: BgmAppBar(
        title: '浏览历史',
        actions: [
          if (history.isNotEmpty)
            BgmHeaderAction(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '清空',
              onPressed: () async {
                final ok = await showBgmConfirm(
                  context,
                  title: '清空浏览历史?',
                  message: '清空后不可恢复',
                  confirmLabel: '清空',
                );
                if (ok) await ref.read(historyProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: history.isEmpty
          ? const Center(child: Text('暂无浏览历史'))
          : ListView.separated(
              itemCount: history.length,
              separatorBuilder: (_, _) => const BgmHairline(indent: 16),
              itemBuilder: (context, index) =>
                  _HistoryRow(item: history[index]),
            ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  final HistoryItem item;

  const _HistoryRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        if (item.topicId.startsWith('blog/')) {
          final blogId = int.tryParse(item.topicId.split('/').last);
          if (blogId != null) {
            context.push('/rakuen/blog/$blogId');
            return;
          }
        }
        context.push('/rakuen/topic/${item.topicId}');
      },
      onLongPress: () => ref.read(historyProvider.notifier).remove(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.group.isNotEmpty)
                        Text(
                          item.group,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text('${item.replies} 回复', style: context.ds.meta),
                      const Spacer(),
                      Text(
                        friendlyTimeOf(
                          DateTime.fromMillisecondsSinceEpoch(item.time * 1000),
                        ),
                        style: context.ds.tiny,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
