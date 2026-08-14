import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';

/// 半月刊条目 (原项目公开 CDN 静态数据)
class BiWeeklyItem {
  final String topicId; // group/432006
  final String title;
  final String desc;
  final String cover;

  const BiWeeklyItem({
    this.topicId = '',
    this.title = '',
    this.desc = '',
    this.cover = '',
  });

  factory BiWeeklyItem.fromJson(Map<String, dynamic> json) => BiWeeklyItem(
    topicId: json['topicId'] as String? ?? '',
    title: json['title'] as String? ?? '',
    desc: json['desc'] as String? ?? '',
    cover: json['cover'] as String? ?? '',
  );

  bool get isCatalog => title.contains('目录');

  String get topicUrl {
    final id = topicId.split('/').last;
    return 'https://bgm.tv/group/topic/$id';
  }
}

/// 半月刊
final biWeeklyProvider = FutureProvider<List<BiWeeklyItem>>((ref) async {
  final client = ref.read(apiClientProvider);
  final data = await client.get(apiBiWeeklyJson(), host: kDogeCdnHost);
  return (data as List)
      .whereType<Map<String, dynamic>>()
      .map(BiWeeklyItem.fromJson)
      .toList();
});

class BiWeeklyScreen extends ConsumerStatefulWidget {
  const BiWeeklyScreen({super.key});

  @override
  ConsumerState<BiWeeklyScreen> createState() => _BiWeeklyScreenState();
}

class _BiWeeklyScreenState extends ConsumerState<BiWeeklyScreen> {
  /// 0=文章 1=目录 (原项目顶部 文章/目录 分段)
  int _kind = 0;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(biWeeklyProvider);
    return Scaffold(
      appBar: BgmAppBar(
        title: 'Bangumi 半月刊',
        showBackButton: true,
        actions: [
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) {
              if (value == 'group') {
                context.push('/rakuen/group/biweekly');
              } else if (value == 'browser') {
                openExternalUrl('$kHost/group/biweekly');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'group', child: Text('小组讨论')),
              PopupMenuItem(value: 'browser', child: Text('浏览器查看')),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('文章')),
                ButtonSegment(value: 1, label: Text('目录')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
          ),
          Expanded(
            child: items.when(
              loading: () => const Center(child: Loading()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('加载失败'),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(biWeeklyProvider),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
              data: (list) {
                final filtered = list
                    .where((e) => _kind == 1 ? e.isCatalog : !e.isCatalog)
                    .toList();
                if (filtered.isEmpty) {
                  return Center(child: Text(_kind == 1 ? '暂无目录' : '暂无文章'));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(biWeeklyProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return InkWell(
                        onTap: () => context.push(
                          '/web/${Uri.encodeComponent(item.topicUrl)}',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Cover(
                                url: item.cover,
                                width: 64,
                                height: 64,
                                radius: 6,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (item.desc.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          item.desc,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
