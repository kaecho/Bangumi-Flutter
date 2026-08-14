import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';
import '../../shared/models/collection.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'collection_sheet.dart';
import 'subject_models.dart';
import 'subject_providers.dart';

import '../../design_system/design_system.dart';

/// 关联条目
/// 路由: /subject/:id/link
class LinkScreen extends ConsumerWidget {
  final int id;

  const LinkScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relations = ref.watch(subjectRelationsProvider(id));
    final store = ref.watch(settingsStoreProvider);
    return Scaffold(
      appBar: BgmAppBar(
        title: '关联条目',
        showBackButton: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'cover':
                  store.setSubjectLinkCover(!store.subjectLinkCover);
                case 'rating':
                  store.setSubjectLinkRating(!store.subjectLinkRating);
                case 'collected':
                  store.setSubjectLinkCollected(!store.subjectLinkCollected);
              }
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'cover',
                checked: store.subjectLinkCover,
                child: const Text('显示封面'),
              ),
              CheckedPopupMenuItem(
                value: 'rating',
                checked: store.subjectLinkRating,
                child: const Text('显示评分'),
              ),
              CheckedPopupMenuItem(
                value: 'collected',
                checked: store.subjectLinkCollected,
                child: const Text('显示收藏状态'),
              ),
            ],
          ),
          IconButton(
            tooltip: '浏览器查看',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => openExternalUrl(htmlSubjectRelations(id)),
          ),
        ],
      ),

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

class _RelationRow extends ConsumerWidget {
  final SubjectListItem item;
  const _RelationRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final store = ref.watch(settingsStoreProvider);
    final collection = store.subjectLinkCollected
        ? ref.watch(collectionProvider(item.id)).valueOrNull
        : null;
    final scoreText = [
      if (item.rank > 0) '#${item.rank}',
      if (item.score > 0) item.score.toStringAsFixed(1),
    ].join(' ');
    return InkWell(
      onTap: () => context.push('/subject/${item.id}'),
      onLongPress: () => showCollectionSheet(context, item.id),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (store.subjectLinkCover) ...[
              Cover(url: item.images.common, width: 56, height: 76, radius: 4),
              const SizedBox(width: 12),
            ],
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
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  if (item.date.isNotEmpty)
                    Text(
                      item.date,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (store.subjectLinkRating && scoreText.isNotEmpty)
                    Text(scoreText, style: context.ds.caption),
                  if (collection != null && collection.type > 0)
                    Text(
                      SubjectType.statusText(collection.type),

                      style: context.ds.tiny,
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: context.ds.textHint),
          ],
        ),
      ),
    );
  }
}
