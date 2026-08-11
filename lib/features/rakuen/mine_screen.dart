import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/utils/format.dart';
import '../../shared/models/timeline.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'html_parse.dart';
import 'rakuen_providers.dart';
import 'widgets/login_gate.dart';
import 'widgets/topic_row.dart';

/// 我的 (我的主题/日志/动态)
/// 路由: /rakuen/mine
class MineScreen extends ConsumerStatefulWidget {
  const MineScreen({super.key});

  @override
  ConsumerState<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends ConsumerState<MineScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = ref.watch(isLoggedInProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        bottom: isLogin
            ? TabBar(
                controller: _tabController,
                tabs: const [Tab(text: '我的主题'), Tab(text: '我的日志'), Tab(text: '我的动态')],
              )
            : null,
      ),
      body: !isLogin
          ? const RakuenLoginGate(message: '登录后查看我的主题、日志和动态')
          : TabBarView(
              controller: _tabController,
              children: [
                _MineTopics(uid: '${user?.id ?? 0}'),
                _MineBlogs(uid: '${user?.id ?? 0}'),
                _MineTimeline(uid: '${user?.id ?? 0}'),
              ],
            ),
    );
  }
}

class _MineTopics extends ConsumerWidget {
  final String uid;

  const _MineTopics({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mineTopicsProvider(uid));
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (e, _) => _ErrorRetry(onRetry: () => ref.invalidate(mineTopicsProvider(uid))),
      data: (topics) {
        if (topics.isEmpty) return const Center(child: Text('还没有发布主题'));
        return ListView.separated(
          itemCount: topics.length,
          separatorBuilder: (_, _) => const Divider(indent: 56),
          itemBuilder: (context, index) {
            final topic = topics[index];
            return RakuenTopicRow(
              topic: RakuenTopicItem(
                topicId: topic.topicId,
                title: topic.title,
                group: topic.group?.title.isNotEmpty == true
                    ? topic.group!.title
                    : (topic.group?.name ?? ''),
                userName: topic.user?.displayName ?? '',
                replies: '${topic.replies}',
                time: topic.displayTime,
              ),
            );
          },
        );
      },
    );
  }
}

class _MineBlogs extends ConsumerWidget {
  final String uid;

  const _MineBlogs({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mineBlogsProvider(uid));
    final theme = Theme.of(context);
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (e, _) => _ErrorRetry(onRetry: () => ref.invalidate(mineBlogsProvider(uid))),
      data: (blogs) {
        if (blogs.isEmpty) return const Center(child: Text('还没有发布日志'));
        return ListView.separated(
          itemCount: blogs.length,
          separatorBuilder: (_, _) => const Divider(indent: 16),
          itemBuilder: (context, index) {
            final blog = blogs[index];
            return InkWell(
              onTap: () => context.push('/rakuen/blog/${blog.id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            blog.title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${blog.replies} 回复',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                friendlyTime(blog.createdAt),
                                style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MineTimeline extends ConsumerWidget {
  final String uid;

  const _MineTimeline({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mineTimelineProvider(uid));
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (e, _) => _ErrorRetry(onRetry: () => ref.invalidate(mineTimelineProvider(uid))),
      data: (items) {
        if (items.isEmpty) return const Center(child: Text('暂无动态'));
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(indent: 56),
          itemBuilder: (context, index) => _TimelineRow(item: items[index]),
        );
      },
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final TimelineItem item;

  const _TimelineRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(url: item.user?.avatarUrl ?? '', size: 34, name: item.user?.displayName),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.content.isEmpty ? _timelineTypeText(item.type) : item.content,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${_timelineTypeText(item.type)} · ${friendlyTime(item.createdAt)}',
                  style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timelineTypeText(String type) => switch (type) {
        'say' => '吐槽',
        'blog' => '日志',
        'topic' => '帖子',
        'collect' => '收藏',
        'progress' => '进度',
        'relation' => '好友',
        'wiki' => '维基',
        'index' => '目录',
        _ => type,
      };
}

class _ErrorRetry extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorRetry({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('加载失败'),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
