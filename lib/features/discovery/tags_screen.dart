import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';
import 'widgets/discovery_html.dart';

/// 标签类型 Tab
const kTagTypes = [
  ('anime', '动画'),
  ('book', '书籍'),
  ('real', '三次元'),
  ('game', '游戏'),
];

/// 某类型的标签列表
final tagListProvider = FutureProvider.family<List<TagItem>, String>((ref, type) async {
  final client = ref.read(apiClientProvider);
  final body = await client.get(htmlTypeTag(type), host: kHost);
  return parseTagList(body as String);
});

/// 标签
class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  String _type = 'anime';

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagListProvider(_type));
    return Scaffold(
      appBar: BgmAppBar(title: '标签', showBackButton: true),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final (value, label) in kTagTypes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Tag(
                      text: label,
                      active: _type == value,
                      onTap: () => setState(() => _type = value),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: tags.when(
              loading: () => const Center(child: Loading()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('加载失败'),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(tagListProvider(_type)),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('暂无标签'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final tag = list[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            onTap: () => context.push(
                              '/tags/$_type/${Uri.encodeComponent(tag.name)}',
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      tag.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${tag.count}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
