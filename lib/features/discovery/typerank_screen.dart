import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../design_system/design_system.dart';

import '../subject/collection_sheet.dart';
import '../subject/subject_models.dart';
import 'discovery_notes.dart';
import 'typerank_data.dart';
import '../../shared/widgets/bgm_button.dart';

/// 分类排行类型 (原项目 SUBJECT_TYPE 标题)
const kTypeRankTypes = <(String, String)>[
  ('anime', '动画'),
  ('book', '书籍'),
  ('music', '音乐'),
  ('game', '游戏'),
  ('real', '三次元'),
];

String typeRankTypeCn(String type) =>
    kTypeRankTypes.where((e) => e.$1 == type).firstOrNull?.$2 ?? '动画';

/// 原版分类排行书签: 有标签进 `/tags/{type}/{tag}`, 否则回标签索引
String typeRankBookmarkPath(String type, String tag) {
  final t = tag.trim();
  if (t.isEmpty) return '/tags';
  return '/tags/${Uri.encodeComponent(type)}/${Uri.encodeComponent(t)}';
}

final typeRankPackedProvider =
    FutureProvider.family<
      ({List<int> ids, List<SubjectListItem> items}),
      ({String type, String tag})
    >((ref, arg) async {
      final ids = await loadTypeRankIds(arg.type, arg.tag);
      if (ids.isEmpty) return (ids: ids, items: const <SubjectListItem>[]);
      final client = ref.read(apiClientProvider);
      final items = await fetchTypeRankSubjects(client, ids);
      return (ids: ids, items: items);
    });

/// 分类排行 (按标签筛选条目)
///
/// 原项目从打包 `typerank/{type}-ids.json` 取该标签 TOP100 ID。
class TypeRankScreen extends ConsumerWidget {
  final String initialType;
  final String initialTag;

  const TypeRankScreen({
    super.key,
    this.initialType = 'anime',
    this.initialTag = 'TV',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = initialType;
    final tag = initialTag;
    final packed = ref.watch(typeRankPackedProvider((type: type, tag: tag)));
    final total = packed.valueOrNull?.ids.length;
    return Scaffold(
      appBar: BgmAppBar(
        title: typeRankTitle(type, tag, total: total),
        showBackButton: true,
        actions: [
          BgmHeaderAction(
            tooltip: '标签',
            icon: const Icon(Icons.bookmark_outline),
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
                itemBuilder: (_, i) => _TypeRankSubjectRow(item: data.items[i]),
              ),
      ),
    );
  }
}

class _TypeRankSubjectRow extends StatelessWidget {
  final SubjectListItem item;

  const _TypeRankSubjectRow({required this.item});

  @override
  Widget build(BuildContext context) {
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
                    item.displayName.isEmpty ? '#${item.id}' : item.displayName,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.date.isNotEmpty)
                    Text(item.date, style: context.ds.caption),
                  if (item.score > 0)
                    Text(
                      '${item.score.toStringAsFixed(1)} 分${item.rank > 0 ? ' · 排名 ${item.rank}' : ''}',
                      style: context.ds.caption.copyWith(
                        color: context.ds.star,
                      ),
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
