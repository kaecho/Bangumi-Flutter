import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';

import 'collection_sheet.dart';
import '../discovery/discovery_notes.dart';
import '../discovery/typerank_screen.dart';
import '../discovery/typerank_data.dart';

import 'subject_models.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/bgm_button.dart';

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
    final packed = ref.watch(typeRankPackedProvider((type: type, tag: tag)));
    final total = packed.valueOrNull?.ids.length;
    return Scaffold(
      appBar: BgmAppBar(
        title: typeRankTitle(type, tag, total: total),
        showBackButton: true,
        actions: [
          BgmHeaderAction(
            tooltip: '标签',
            icon: const Icon(Icons.bookmark_border),
            onPressed: () => context.push(typeRankBookmarkPath(type, tag)),
          ),
          BgmHeaderAction(
            tooltip: '说明',
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push(typeRankNotePath()),
          ),
        ],
      ),
      body: packed.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) => BgmRetry(
          onRetry: () =>
              ref.invalidate(typeRankPackedProvider((type: type, tag: tag))),
        ),
        data: (data) => data.ids.isEmpty
            ? const Empty(text: '此标签没有足够的列表数据')
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: data.items.length,
                itemBuilder: (_, i) => _SubjectRow(item: data.items[i]),
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
