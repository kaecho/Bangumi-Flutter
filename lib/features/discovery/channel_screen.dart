import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'widgets/discovery_html.dart';
import 'widgets/season_filter.dart';

/// 频道聚合数据
final channelProvider = FutureProvider.family<ChannelData, String>((ref, type) async {
  final client = ref.read(apiClientProvider);
  final body = await client.get(htmlChannel(type), host: kHost);
  return parseChannel(body as String);
});

/// 频道聚合 (原项目 discovery/channel, 非电波提醒)
///
/// 频道页 (https://bgm.tv/{anime|book|real|game}) 聚合了 注目条目/
/// 讨论/日志 三个栏目。
class ChannelScreen extends ConsumerStatefulWidget {
  const ChannelScreen({super.key});

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen> {
  String _type = 'anime';

  @override
  Widget build(BuildContext context) {
    final channel = ref.watch(channelProvider(_type));
    return Scaffold(
      appBar: BgmAppBar(title: '频道', showBackButton: true),
      body: Column(
        children: [
          TypeTabs(
            value: _type,
            onChanged: (v) => setState(() => _type = v),
          ),
          Expanded(
            child: channel.when(
              loading: () => const Center(child: Loading()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('加载失败'),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(channelProvider(_type)),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
              data: (data) => RefreshIndicator(
                onRefresh: () => ref.refresh(channelProvider(_type).future),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (data.rank.isNotEmpty) ...[
                      const SectionHeader(title: '注目'),
                      SizedBox(
                        height: 168,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: data.rank.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final item = data.rank[index];
                            return GestureDetector(
                              onTap: () => context.push('/subject/${item.id}'),
                              child: SizedBox(
                                width: 104,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Cover(
                                      url: item.cover,
                                      width: 104,
                                      height: 139,
                                      radius: 6,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    if (data.discuss.isNotEmpty) ...[
                      const SectionHeader(title: '讨论'),
                      for (final item in data.discuss)
                        ListTile(
                          dense: true,
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            '${item.username} · ${item.time}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Text(
                            '${item.replies} 回复',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () => context.push(
                            '/web/${Uri.encodeComponent('https://bgm.tv/subject/topic/${item.id}')}',
                          ),
                        ),
                    ],
                    if (data.blogs.isNotEmpty) ...[
                      const SectionHeader(title: '日志'),
                      for (final blog in data.blogs)
                        ListTile(
                          dense: true,
                          title: Text(
                            blog.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            '${blog.username} · ${blog.time} · ${blog.replies} 回复',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () => context.push(
                            '/web/${Uri.encodeComponent('https://bgm.tv/blog/${blog.id}')}',
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
