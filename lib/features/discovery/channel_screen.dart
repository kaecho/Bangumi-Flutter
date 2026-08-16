import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';

import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/bgm_button.dart';

import '../../shared/widgets/score.dart';
import '../subject/collection_sheet.dart';
import 'tags_screen.dart';
import 'widgets/discovery_html.dart';

/// 频道聚合数据
final channelProvider = FutureProvider.family<ChannelData, String>((
  ref,
  type,
) async {
  final client = ref.read(apiClientProvider);
  final body = await client.get(htmlChannel(type), host: kHost);
  return parseChannel(body as String);
});

/// 原版 SUBJECT_TYPE + 浏览器查看
const kChannelTypes = <(String, String)>[
  ('anime', '动画'),
  ('book', '书籍'),
  ('real', '三次元'),
  ('game', '游戏'),
  ('music', '音乐'),
];

/// 频道聚合 (原项目 discovery/channel, 非电波提醒)
///
/// 频道页 (https://bgm.tv/{anime|book|real|game}) 聚合了 注目条目/
/// 讨论/日志 三个栏目。
class ChannelScreen extends ConsumerStatefulWidget {
  final String initialType;

  const ChannelScreen({super.key, this.initialType = 'anime'});

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen> {
  late String _type = widget.initialType;

  String get _typeCn =>
      kChannelTypes.where((e) => e.$1 == _type).firstOrNull?.$2 ?? '动画';

  @override
  Widget build(BuildContext context) {
    final channel = ref.watch(channelProvider(_type));
    return Scaffold(
      appBar: BgmAppBar(
        title: '$_typeCn频道',
        showBackButton: true,
        actions: [
          BgmHeaderMore(
            items: [
              for (final type in kChannelTypes) (type.$1, type.$2),
              ('browser', '浏览器查看'),
            ],
            onSelected: (value) {
              if (value == 'browser') {
                openExternalUrl('$kHost/$_type');
                return;
              }
              setState(() => _type = value);
            },
          ),
        ],
      ),
      body: channel.when(
        loading: () => const Center(child: Loading()),
        error: (error, _) =>
            BgmRetry(onRetry: () => ref.invalidate(channelProvider(_type))),
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
                        onLongPress: () =>
                            showCollectionSheet(context, item.id),
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
                const SectionHeader(title: '最新帖子'),
                for (final item in data.discuss)
                  BgmTextRow(
                    title: item.title,
                    replies: item.replies,
                    subtitle: item.subjectName.isEmpty
                        ? item.username
                        : item.subjectName,
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item.username,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(item.time, style: context.ds.caption),
                      ],
                    ),
                    onTap: () =>
                        context.push('/rakuen/topic/subject/${item.id}'),
                  ),
              ],
              if (data.blogs.isNotEmpty) ...[
                const SectionHeader(title: '最新日志'),
                for (final blog in data.blogs)
                  BgmTextRow(
                    title: blog.title,
                    replies: blog.replies,
                    subtitle: '${blog.username} · ${blog.time}',
                    onTap: () => context.push('/rakuen/blog/${blog.id}'),
                  ),
              ],
              if (data.friends.isNotEmpty) ...[
                const SectionHeader(title: '好友最近关注'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 12,
                    children: [
                      for (final item in data.friends)
                        SizedBox(
                          width: (MediaQuery.sizeOf(context).width - 34) / 2,
                          child: GestureDetector(
                            onTap: () => context.push('/subject/${item.id}'),
                            onLongPress: () =>
                                showCollectionSheet(context, item.id),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Cover(
                                  url: item.cover,
                                  width: 56,
                                  height: _type == 'music' ? 56 : 75,
                                  radius: 6,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: visualFontSize(
                                            item.name,
                                            const [(18, 10), (14, 11), (0, 12)],
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: item.userName,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (item.action.isNotEmpty)
                                              TextSpan(
                                                text: ' ${item.action}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                          ],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SectionHeader(title: '标签'),
              _ChannelTags(type: _type),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelTags extends ConsumerWidget {
  final String type;

  const _ChannelTags({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagListProvider(TagListQuery(type)));
    return tags.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Loading()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in list.take(24))
              BgmFilterChip(
                label: tag.name,
                selected: false,
                onTap: () => context.push(
                  '/tags/$type/${Uri.encodeComponent(tag.name)}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
