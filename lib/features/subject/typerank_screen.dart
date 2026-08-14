import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';

import 'collection_sheet.dart';
import '../discovery/discovery_notes.dart';
import 'subject_models.dart';
import 'subject_providers.dart';
import '../../design_system/design_system.dart';

/// 分类排行 (共享某标签的条目)
/// 路由: /subject/:id/typerank?tag=&type=
class SubjectTypeRankScreen extends ConsumerWidget {
  final int id;
  final String tag;
  final String type;

  const SubjectTypeRankScreen({
    super.key,
    required this.id,
    required this.tag,
    this.type = 'anime',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(typerankProvider((type: type, tag: tag)));
    return Scaffold(
      appBar: BgmAppBar(
        title: '标签: $tag',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: '标签',
            icon: const Icon(Icons.bookmark_border),
            onPressed: () => context.push('/subject/$id/tag'),
          ),
          IconButton(
            tooltip: '说明',
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push(typeRankNotePath()),
          ),
          IconButton(
            tooltip: '浏览器查看',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () =>
                openExternalUrl('$kHost${htmlTagSubjects(type, tag)}'),
          ),
        ],
      ),

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
                    ref.invalidate(typerankProvider((type: type, tag: tag))),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? const Empty(text: '暂无条目')
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (_, i) => _SubjectRow(item: items[i]),
              ),
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  final SubjectListItem item;
  const _SubjectRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/subject/${item.id}'),
      onLongPress: () => showCollectionSheet(context, item.id),

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
                      '${item.score.toStringAsFixed(1)} 分${item.rank > 0 ? ' · 排名 ${item.rank}' : ''}',
                      style: TextStyle(fontSize: 11, color: context.ds.star),
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
