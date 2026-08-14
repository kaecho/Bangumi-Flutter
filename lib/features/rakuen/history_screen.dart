import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/format.dart';
import 'rakuen_models.dart';
import 'rakuen_providers.dart';
import '../../design_system/design_system.dart';

/// 浏览历史 (port 特有功能: 本地浏览记录, 与原版 rakuen/history 语义不同)
/// 路由: /history/browse
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('浏览历史'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '清空',
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('清空浏览历史?'),
                    content: const Text('清空后不可恢复'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () {
                          ref.read(historyProvider.notifier).clear();
                          Navigator.of(context).pop();
                        },
                        child: const Text('清空'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: history.isEmpty
          ? const Center(child: Text('暂无浏览历史'))
          : ListView.separated(
              itemCount: history.length,
              separatorBuilder: (_, _) => const Divider(indent: 16),
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
