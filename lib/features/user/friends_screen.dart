import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'user_models.dart';

/// 好友列表 (bgm.tv/user/{uid}/friends, 主站 HTML)
final userFriendsProvider = FutureProvider.family<List<Friend>, String>((ref, userId) async {
  final client = ref.read(apiClientProvider);
  final html = await client.get(apiUserFriendsHtml(userId), host: kHost);
  return parseUserFriends(html as String);
});

/// 好友 (独立页 / 我的好友)
class FriendsScreen extends ConsumerWidget {
  final String userId;

  const FriendsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('好友')),
      body: FriendsList(userId: userId),
    );
  }
}

/// 我的好友 (当前登录用户)
class MyFriendsScreen extends ConsumerWidget {
  const MyFriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('我的好友')),
      body: me == null
          ? const Center(child: Text('请先登录'))
          : FriendsList(userId: userPathId(me)),
    );
  }
}

/// 好友列表 (zone tab 与独立页共用)
class FriendsList extends ConsumerWidget {
  final String userId;

  const FriendsList({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userFriendsProvider(userId));
    return async.when(
      loading: () => const Loading(),
      error: (_, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('加载失败'),
            TextButton(
              onPressed: () => ref.invalidate(userFriendsProvider(userId)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (friends) {
        if (friends.isEmpty) return const Center(child: Text('暂无好友'));
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return InkWell(
              onTap: () => context.push('/user/${friend.userId}'),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Avatar(url: friend.avatar, size: 52, name: friend.userName),
                  const SizedBox(height: 6),
                  Text(
                    friend.userName,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
