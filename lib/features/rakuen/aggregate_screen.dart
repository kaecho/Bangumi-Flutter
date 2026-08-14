import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../webview/note_screen.dart';
import '../../shared/widgets/loading.dart';

import 'rakuen_providers.dart';

/// 帖子聚合 (移植自原项目 rakuen/history)
///
/// 4 tab: 我回复的 / 收藏 / 热门 / 缓存。
/// - 我回复的: 主站 HTML /group/my_reply
/// - 收藏: 本地主题收藏
/// - 热门: 超展开 type=hot
/// - 缓存: 浏览历史
/// 路由: /rakuen/history
class AggregateScreen extends ConsumerStatefulWidget {
  const AggregateScreen({super.key});

  @override
  ConsumerState<AggregateScreen> createState() => _AggregateScreenState();
}

class _AggregateScreenState extends ConsumerState<AggregateScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);

  static const _tabs = ['我回复的', '收藏', '热门', '缓存'];

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('帖子聚合'),
        actions: [
          IconButton(
            tooltip: '说明',
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push(
              extraNotePath(
                title: '帖子聚合',
                message: const ['能快速查看回复和贴贴信息。', '会员支持同时显示更多自己的回复。'],

                advance: true,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: [for (final t in _tabs) Tab(text: t)],
        ),
      ),

      body: TabBarView(
        controller: _tab,
        children: const [
          _MyReplyList(),
          _FavorList(),
          _HotList(),
          _CacheList(),
        ],
      ),
    );
  }
}

/// 我回复的 — 主站 /group/my_reply HTML
class _MyReplyList extends ConsumerStatefulWidget {
  const _MyReplyList();

  @override
  ConsumerState<_MyReplyList> createState() => _MyReplyListState();
}

class _MyReplyListState extends ConsumerState<_MyReplyList> {
  final int _page = 1;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(myReplyProvider(_page));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myReplyProvider),
      child: data.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            Center(
              child: Text(
                apiErrorMessage(e),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton(
                onPressed: () => ref.invalidate(myReplyProvider),
                child: const Text('重试'),
              ),
            ),
          ],
        ),
        data: (value) {
          final rows = value.items;
          if (rows.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('没有数据')),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: rows.length + (value.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
            itemBuilder: (context, index) {
              if (index == rows.length) {
                return ListTile(
                  title: const Center(
                    child: Text('加载更多', style: TextStyle(fontSize: 12)),
                  ),
                  onTap: () =>
                      ref.read(myReplyProvider(_page).notifier).loadMore(),
                );
              }
              final t = rows[index];
              return ListTile(
                dense: true,
                title: Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${t.userName} · ${t.replies} 回复 · ${t.time}',
                  style: const TextStyle(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  final parts = t.topicId.split('/');
                  if (parts.length == 2) {
                    context.push('/rakuen/topic/${parts.first}/${parts.last}');
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FavorList extends ConsumerWidget {
  const _FavorList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(topicFavorProvider);
    if (items.isEmpty) {
      return const Center(child: Text('还没有收藏的帖子'));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
      itemBuilder: (_, i) {
        final t = items[i];
        return ListTile(
          title: Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              if (t.group.isNotEmpty) t.group,
              if (t.userName.isNotEmpty) t.userName,
              if (t.replies > 0) '${t.replies} 回复',
            ].join(' · '),
          ),
          onTap: () => context.push('/rakuen/topic/${t.topicId}'),
          onLongPress: () => ref.read(topicFavorProvider.notifier).toggle(t),
        );
      },
    );
  }
}

class _HotList extends ConsumerWidget {
  const _HotList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hotTopicsProvider);
    return async.when(
      loading: () => const Loading(text: '加载中...'),
      error: (e, _) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(hotTopicsProvider),
          child: Text('重试: ${apiErrorMessage(e)}'),
        ),
      ),
      data: (items) {
        if (items.isEmpty) return const Center(child: Text('暂无热门'));
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(hotTopicsProvider),
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
            itemBuilder: (_, i) {
              final t = items[i];
              return ListTile(
                title: Text(
                  t.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    if (t.group.isNotEmpty) t.group,
                    if (t.userName.isNotEmpty) t.userName,
                    if (t.replies.isNotEmpty) '${t.replyCount} 回复',
                  ].join(' · '),
                ),
                onTap: t.topicId.isEmpty
                    ? null
                    : () => context.push('/rakuen/topic/${t.topicId}'),
              );
            },
          ),
        );
      },
    );
  }
}

class _CacheList extends ConsumerWidget {
  const _CacheList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(historyProvider);
    if (items.isEmpty) {
      return const Center(child: Text('暂无浏览缓存'));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
      itemBuilder: (_, i) {
        final t = items[i];
        return ListTile(
          title: Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              if (t.group.isNotEmpty) t.group,
              if (t.userName.isNotEmpty) t.userName,
            ].join(' · '),
          ),
          onTap: () => context.push('/rakuen/topic/${t.topicId}'),
        );
      },
    );
  }
}
