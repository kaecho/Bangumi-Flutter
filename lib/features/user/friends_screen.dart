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

/// 好友列表 (bgm.tv/user/{uid}/friends, 主站 HTML)
final userFriendsProvider = FutureProvider.family<List<Friend>, String>((
  ref,
  userId,
) async {
  final client = ref.read(apiClientProvider);
  final html = await client.get(apiUserFriendsHtml(userId), host: kHost);
  return parseUserFriends(html as String);
});

/// 反向好友列表 (bgm.tv/user/{uid}/rev_friends, 原项目 type: 'rev')
final userRevFriendsProvider = FutureProvider.family<List<Friend>, String>((
  ref,
  userId,
) async {
  final client = ref.read(apiClientProvider);
  final html = await client.get(apiUserRevFriendsHtml(userId), host: kHost);
  return parseUserFriends(html as String);
});

/// 好友 (独立页 / 我的好友, 好友/反向好友 tab)
class FriendsScreen extends ConsumerStatefulWidget {
  final String userId;
  final bool rev;

  const FriendsScreen({super.key, required this.userId, this.rev = false});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.rev ? 1 : 0,
  );

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rev ? '谁加TA为好友' : 'TA的好友'),
        actions: [
          IconButton(
            tooltip: '说明',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('好友'),
                  content: const Text('点击头像前往空间\n长按头像展开菜单'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('知道了'),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            tooltip: '浏览器查看',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => openExternalUrl(
              widget.rev
                  ? apiUserRevFriendsHtml(widget.userId)
                  : apiUserFriendsHtml(widget.userId),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '好友'),
            Tab(text: '反向好友'),
          ],
        ),
      ),

      body: TabBarView(
        controller: _tab,
        children: [
          FriendsList(userId: widget.userId),
          FriendsList(userId: widget.userId, rev: true),
        ],
      ),
    );
  }
}

/// 我的好友 (当前登录用户)
class MyFriendsScreen extends ConsumerWidget {
  final bool rev;

  const MyFriendsScreen({super.key, this.rev = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(rev ? '谁加我为好友' : '我的好友'),
        actions: [
          IconButton(
            tooltip: '说明',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('好友'),
                  content: const Text('点击头像前往空间\n长按头像展开菜单'),

                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('知道了'),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            tooltip: '浏览器查看',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () {
              final me = ref.read(currentUserProvider);
              if (me == null) return;
              final userId = userPathId(me);
              openExternalUrl(
                rev
                    ? apiUserRevFriendsHtml(userId)
                    : apiUserFriendsHtml(userId),
              );
            },
          ),
        ],
      ),

      body: me == null
          ? const Center(child: Text('请先登录'))
          : FriendsScreen(userId: userPathId(me), rev: rev),
    );
  }
}

/// 好友列表 (zone tab 与独立页共用)
class FriendsList extends ConsumerWidget {
  final String userId;
  final bool rev;

  const FriendsList({super.key, required this.userId, this.rev = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      rev ? userRevFriendsProvider(userId) : userFriendsProvider(userId),
    );
    return async.when(
      loading: () => const Loading(),
      error: (_, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('加载失败'),
            TextButton(
              onPressed: () => ref.invalidate(
                rev
                    ? userRevFriendsProvider(userId)
                    : userFriendsProvider(userId),
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (friends) {
        if (friends.isEmpty) {
          return Center(child: Text(rev ? '暂无反向好友' : '暂无好友'));
        }
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
