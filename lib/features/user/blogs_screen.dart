import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'user_models.dart';

/// 用户日志列表 (bgm.tv/user/{uid}/blog, 主站 HTML)
final userBlogsProvider = FutureProvider.family<List<UserBlog>, String>((ref, userId) async {
  final client = ref.read(apiClientProvider);
  final html = await client.get(apiUserBlogsHtml(userId), host: kHost);
  return parseUserBlogs(html as String);
});

/// 用户日志 (独立页 / 我的日志)
class UserBlogsScreen extends ConsumerWidget {
  final String userId;

  const UserBlogsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('日志')),
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
      appBar: AppBar(title: const Text('我的日志')),
      body: me == null
          ? const Center(child: Text('请先登录'))
          : UserBlogsList(userId: userPathId(me)),
    );
  }
}

/// 日志列表 (zone tab 与独立页共用)
class UserBlogsList extends ConsumerWidget {
  final String userId;

  const UserBlogsList({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userBlogsProvider(userId));
    return async.when(
      loading: () => const Loading(),
      error: (_, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('加载失败'),
            TextButton(
              onPressed: () => ref.invalidate(userBlogsProvider(userId)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (blogs) {
        if (blogs.isEmpty) return const Center(child: Text('暂无日志'));
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: blogs.length,
          itemBuilder: (context, index) {
            final blog = blogs[index];
            return InkWell(
              onTap: () => context.push('/blog/${blog.id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (blog.content.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              blog.content,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
