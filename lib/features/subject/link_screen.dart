import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'subject_models.dart';
import 'subject_providers.dart';

/// 关联条目
/// 路由: /subject/:id/link
class LinkScreen extends ConsumerWidget {
  final int id;

  const LinkScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relations = ref.watch(subjectRelationsProvider(id));
    return Scaffold(
      appBar: BgmAppBar(title: '关联条目', showBackButton: true),
      body: relations.when(
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
                onPressed: () => ref.invalidate(subjectRelationsProvider(id)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? const Empty(text: '暂无关联条目')
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (_, i) => _RelationRow(item: items[i]),
              ),
      ),
    );
  }
}

class _RelationRow extends StatelessWidget {
  final SubjectListItem item;
  const _RelationRow({required this.item});

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
                  if (item.relation.isNotEmpty)
                    Text(
                      item.relation,
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
                    ),
                  if (item.date.isNotEmpty)
                    Text(
                      item.date,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
