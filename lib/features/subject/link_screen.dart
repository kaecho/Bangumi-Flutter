import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/settings_store.dart';
import '../../design_system/design_system.dart';
import '../../shared/models/collection.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'collection_sheet.dart';
import 'subject_models.dart';
import 'subject_providers.dart';
import 'subject_notes.dart';


/// 关联条目
/// 路由: /subject/:id/link
/// Extra 对齐原版: 齿轮打开设置抽屉, 不是弹出菜单。
class LinkScreen extends ConsumerWidget {
  final int id;

  const LinkScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relations = ref.watch(subjectRelationsProvider(id));
    final count = relations.valueOrNull?.length ?? 0;
    return Scaffold(
      appBar: BgmAppBar(
        title: extraNamedTitle(
          ref.watch(subjectDetailProvider(id)).valueOrNull?.subject.displayName,
          '关联',
          named: (n) => '$n的关联',
          count: count,
        ),

        showBackButton: true,
        actions: [
          BgmHeaderAction(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () => showBgmSheet<void>(
              context: context,
              builder: (_) => const _LinkSettingSheet(),
            ),
          ),
        ],
      ),
      body: relations.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) => BgmRetry(
          onRetry: () => ref.invalidate(subjectRelationsProvider(id)),
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

class _LinkSettingSheet extends ConsumerWidget {
  const _LinkSettingSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(settingsStoreProvider);
    return BgmSheet(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('关联显示', style: context.ds.section),
                ),
              ),
              BgmSettingRow(
                title: '显示封面',
                trailing: BgmSwitch(
                  value: store.subjectLinkCover,
                  onChanged: store.setSubjectLinkCover,
                ),
              ),
              BgmSettingRow(
                title: '显示评分',
                trailing: BgmSwitch(
                  value: store.subjectLinkRating,
                  onChanged: store.setSubjectLinkRating,
                ),
              ),
              BgmSettingRow(
                title: '显示收藏状态',
                trailing: BgmSwitch(
                  value: store.subjectLinkCollected,
                  onChanged: store.setSubjectLinkCollected,
                ),
              ),
            ],
          ),
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
