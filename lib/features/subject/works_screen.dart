import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'subject_models.dart';
import 'subject_providers.dart';

/// 作品列表 (人物的出演作品)
/// 路由: /subject/:id/works (id 为人物 ID)
class WorksScreen extends ConsumerWidget {
  final int id;

  const WorksScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(monoSubjectsProvider((type: 'person', id: id)));
    return Scaffold(
      appBar: BgmAppBar(title: '作品', showBackButton: true),
      body: list.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 8),
              const Text('加载失败'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(monoSubjectsProvider((type: 'person', id: id))),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? const Empty(text: '暂无作品')
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (_, i) => _WorkRow(item: items[i]),
              ),
      ),
    );
  }
}

class _WorkRow extends StatelessWidget {
  final SubjectListItem item;
  const _WorkRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/subject/${item.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Cover(url: item.images.common, width: 56, height: 76, radius: 4),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.date.isNotEmpty)
                    Text(
                      item.date,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (item.score > 0)
                    Text(
                      '${item.score.toStringAsFixed(1)} 分',
                      style: const TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
