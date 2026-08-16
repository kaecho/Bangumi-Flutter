import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';

import '../../shared/widgets/bgm_button.dart';

import 'widgets/discovery_html.dart';
import 'typerank_data.dart';

/// 标签类型 Tab
const kTagTypes = [
  ('anime', '动画'),
  ('book', '书籍'),
  ('music', '音乐'),
  ('game', '游戏'),
  ('real', '三次元'),
];

/// 原版 HeaderV2Popover DATA: 浏览器查看 + 网页版查看
const kTagsMoreItems = <(String, String)>[
  ('browser', '浏览器查看'),
  ('spa', '网页版查看'),
];

class TagListQuery {
  final String type;
  final String filter;

  const TagListQuery(this.type, {this.filter = ''});

  @override
  bool operator ==(Object other) =>
      other is TagListQuery && other.type == type && other.filter == filter;

  @override
  int get hashCode => Object.hash(type, filter);
}

/// 某类型的标签列表 (空关键字走 /{type}/tag, 有关键字走 /search/tag/{type}/{q})
final tagListProvider = FutureProvider.family<List<TagItem>, TagListQuery>((
  ref,
  query,
) async {
  final client = ref.read(apiClientProvider);
  final body = await client.get(
    htmlTypeTag(query.type, filter: query.filter),
    host: kHost,
  );
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
  bool _rec = false;
  String _filter = '';
  final _filterCtrl = TextEditingController();

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(
      tagListProvider(TagListQuery(_type, filter: _filter)),
    );
    return Scaffold(
      appBar: BgmAppBar(
        title: '标签',
        showBackButton: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: BgmSegmented<bool>(
              values: const [(false, '数量'), (true, '排名')],
              selected: _rec,
              onSelect: (v) => setState(() => _rec = v),
            ),
          ),
          BgmHeaderMore(
            items: kTagsMoreItems,
            onSelected: (value) {
              if (value == 'browser') {
                openExternalUrl('$kHost${htmlTypeTag(_type, filter: _filter)}');
              } else if (value == 'spa') {
                openExternalUrl(htmlSpa('Tags'));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          BgmTabStrip(
            scrollable: true,
            index: kTagTypes
                .indexWhere((e) => e.$1 == _type)
                .clamp(0, kTagTypes.length - 1),
            onSelect: (i) => setState(() => _type = kTagTypes[i].$1),
            tabs: [for (final t in kTagTypes) Text(t.$2)],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _filterCtrl,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (v) => setState(() => _filter = v.trim()),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索标签',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _filterCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _filterCtrl.clear();
                          setState(() => _filter = '');
                        },
                      ),
              ),
            ),
          ),
          if (_rec)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                '「排名」为作者整理的对应标签下评分最高的前 100 个条目。若没有足够数据则跳转到正常的标签页面。',
                style: TextStyle(fontSize: 12),
              ),
            ),
          Expanded(
            child: tags.when(
              loading: () => const Center(child: Loading()),
              error: (error, _) => BgmRetry(
                onRetry: () => ref.invalidate(
                  tagListProvider(TagListQuery(_type, filter: _filter)),
                ),
              ),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('暂无标签'))
                  : FutureBuilder<Map<String, int>>(
                      future: _rec
                          ? loadTypeRankCounts(_type)
                          : Future.value(const <String, int>{}),
                      builder: (context, packed) {
                        final counts = packed.data ?? const <String, int>{};
                        final shown = _rec
                            ? [
                                for (final tag in list)
                                  if ((counts[tag.name] ?? 0) > 0) tag,
                              ]
                            : list;
                        if (shown.isEmpty) {
                          return const Center(child: Text('暂无标签'));
                        }
                        return GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 1,
                              ),
                          itemCount: shown.length,
                          itemBuilder: (context, index) {
                            final tag = shown[index];
                            final n = _rec
                                ? (counts[tag.name] ?? 0)
                                : tag.count;
                            final count = n > 10000
                                ? '${(n / 10000).toStringAsFixed(1)}w'
                                : '$n';
                            final scheme = Theme.of(context).colorScheme;
                            return InkWell(
                              onTap: () => context.push(
                                _rec && (counts[tag.name] ?? 0) > 0
                                    ? '/typerank?type=$_type&tag=${Uri.encodeQueryComponent(tag.name)}'
                                    : '/tags/$_type/${Uri.encodeComponent(tag.name)}',
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        tag.name,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        count,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
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
