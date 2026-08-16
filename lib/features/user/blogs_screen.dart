import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';

import 'user_models.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';
import '../rakuen/rakuen_providers.dart';

/// 原版 IconBookmarks: 书签弹出 favor 标题
class BlogsHeaderBookmarks extends ConsumerWidget {
  const BlogsHeaderBookmarks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(topicFavorProvider);
    return PopupMenuButton<String>(
      tooltip: '书签',
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.bookmark_outline),
      onSelected: (value) {
        if (value == 'empty') return;
        if (value.startsWith('blog/')) {
          final blogId = int.tryParse(value.split('/').last);
          if (blogId != null) context.push('/rakuen/blog/$blogId');
          return;
        }
        context.push('/rakuen/topic/$value');
      },
      itemBuilder: (_) {
        if (items.isEmpty) {
          return const [PopupMenuItem(value: 'empty', child: Text('(空书签)'))];
        }
        return [
          for (final item in items)
            PopupMenuItem(
              value: item.topicId,
              child: Text(item.title.isEmpty ? item.topicId : item.title),
            ),
        ];
      },
    );
  }
}

class UserBlogsData {
  final List<UserBlog> items;
  final int page;
  final bool hasMore;

  const UserBlogsData({
    this.items = const [],
    this.page = 1,
    this.hasMore = true,
  });
}

/// 用户日志列表 (bgm.tv/user/{uid}/blog?page=, 对齐原版 LIMIT=10)
final userBlogsProvider =
    AsyncNotifierProvider.family<UserBlogsNotifier, UserBlogsData, String>(
      UserBlogsNotifier.new,
    );

class UserBlogsNotifier extends FamilyAsyncNotifier<UserBlogsData, String> {
  static const _limit = 10;

  @override
  Future<UserBlogsData> build(String userId) async {
    return _fetch(1, userId);
  }

  Future<UserBlogsData> _fetch(int page, String userId) async {
    final client = ref.read(apiClientProvider);
    final html = await client.get(
      apiUserBlogsHtml(userId, page: page),
      host: kHost,
    );
    final items = parseUserBlogs(html as String);
    return UserBlogsData(
      items: items,
      page: page,
      hasMore: items.length >= _limit,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(current.page + 1, arg);
      state = AsyncData(
        UserBlogsData(
          items: [...current.items, ...next.items],
          page: next.page,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {}
  }
}

/// 用户日志 (独立页 / 我的日志)
class UserBlogsScreen extends ConsumerWidget {
  final String userId;

  const UserBlogsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: BgmAppBar(
        title: 'TA的日志',
        actions: [
          const BlogsHeaderBookmarks(),
          BgmHeaderMore.browser(
            () => openExternalUrl(apiUserBlogsHtml(userId)),
          ),
        ],
      ),

      body: UserBlogsList(userId: userId),
    );
  }
}

/// 我的日志 (当前登录用户)
class MyBlogsScreen extends ConsumerWidget {
  const MyBlogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: BgmAppBar(
        title: '我的日志',
        actions: [
          const BlogsHeaderBookmarks(),
          BgmHeaderMore.browser(() {
            final me = ref.read(currentUserProvider);
            if (me == null) return;
            openExternalUrl(apiUserBlogsHtml(userPathId(me)));
          }),
        ],
      ),

      body: me == null
          ? const Center(child: Text('请先登录'))
          : UserBlogsList(userId: userPathId(me)),
    );
  }
}

/// 日志列表 (zone tab 与独立页共用)
class UserBlogsList extends ConsumerStatefulWidget {
  final String userId;

  const UserBlogsList({super.key, required this.userId});

  @override
  ConsumerState<UserBlogsList> createState() => _UserBlogsListState();
}

class _UserBlogsListState extends ConsumerState<UserBlogsList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        unawaited(
          ref.read(userBlogsProvider(widget.userId).notifier).loadMore(),
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userBlogsProvider(widget.userId));
    return async.when(
      loading: () => const Loading(),
      error: (_, _) => BgmRetry(
        onRetry: () => ref.invalidate(userBlogsProvider(widget.userId)),
      ),
      data: (data) {
        if (data.items.isEmpty) return const Center(child: Text('暂无日志'));
        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: data.items.length + (data.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= data.items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: BgmSpinner(size: 20)),
              );
            }
            final blog = data.items[index];
            return InkWell(
              onTap: () => context.push('/blog/${blog.id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (blog.cover.isNotEmpty)
                      Cover(url: blog.cover, width: 44, height: 44, radius: 4),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            blog.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (blog.content.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              blog.content,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (blog.time.isNotEmpty) blog.time,
                              if (blog.replies.isNotEmpty) '${blog.replies} 回复',
                              ...blog.tags,
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.outline,
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
        );
      },
    );
  }
}
