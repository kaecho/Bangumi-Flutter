import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';

/// 半月刊条目 (原项目公开 CDN 静态数据)
class BiWeeklyItem {
  final String topicId; // group/432006
  final String title;
  final String desc;
  final String cover;

  const BiWeeklyItem({this.topicId = '', this.title = '', this.desc = '', this.cover = ''});

  factory BiWeeklyItem.fromJson(Map<String, dynamic> json) => BiWeeklyItem(
        topicId: json['topicId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        desc: json['desc'] as String? ?? '',
        cover: json['cover'] as String? ?? '',
      );

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

class BiWeeklyScreen extends ConsumerWidget {
  const BiWeeklyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(biWeeklyProvider);
    return Scaffold(
      appBar: BgmAppBar(title: '半月刊', showBackButton: true),
      body: items.when(
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
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(biWeeklyProvider.future),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              return InkWell(
                onTap: () => context.push(
                  '/web/${Uri.encodeComponent(item.topicUrl)}',
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Cover(url: item.cover, width: 64, height: 64, radius: 6),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            if (item.desc.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.desc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
