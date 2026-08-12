import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/models/collection.dart';
import '../../shared/models/user.dart';
import '../../shared/widgets/cover.dart';
import '../../design_system/design_system.dart';

/// 用户空间菜单 (原项目 user/v2 菜单)
const kUserMenus = [
  ('我的好友', Icons.group_outlined, '/my-friends'),
  ('我的日志', Icons.edit_note_outlined, '/my-blogs'),
  ('我的目录', Icons.folder_special_outlined, '/my-catalogs'),
  ('我的人物', Icons.person_outline, '/my-mono'),
  ('我的词云', Icons.cloud_outlined, '/wordcloud'),
  ('本地管理', Icons.folder_outlined, '/settings/smb'),
  ('本地备份', Icons.inbox_outlined, '/settings/backup'),
  ('设置', Icons.settings_outlined, '/settings'),
];

/// 收藏统计
final collectionStatsProvider = FutureProvider<CollectionStats>((ref) async {
  final client = ref.read(apiClientProvider);
  final me = ref.read(currentUserProvider);
  if (me == null) return const CollectionStats();
  final userId = me.username.isEmpty ? '${me.id}' : me.username;
  final data = await client.get(apiUserCollectionsStatus(userId));
  return CollectionStats.fromJson(data as Map<String, dynamic>);
});

/// 用户 Tab (Tab 5)
class UserScreen extends ConsumerWidget {
  const UserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLogin = ref.watch(isLoggedInProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          if (isLogin)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: '退出登录',
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            ),
        ],
      ),
      body: isLogin && user != null
          ? _UserProfile(user: user)
          : _LoginGate(),
    );
  }
}

class _UserProfile extends ConsumerWidget {
  final User user;

  const _UserProfile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(collectionStatsProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // 头部
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Avatar(url: user.avatarUrl, size: 64, name: user.displayName),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userGroupText[user.userGroup] ?? '会员',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                    ),
                    if (user.sign.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.sign,
                        style: context.ds.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: '用户空间',
                onPressed: () {
                  final userId = user.username.isEmpty ? '${user.id}' : user.username;
                  context.push('/user/$userId');
                },
              ),
            ],
          ),
        ),
        // 收藏统计
        stats.when(
          data: (s) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    for (final (type, label) in [
                      ('anime', '动画'),
                      ('book', '书籍'),
                      ('real', '三次元'),
                      ('game', '游戏'),
                    ])
                      Expanded(
                        child: InkWell(
                          onTap: () => context.push('/user/$type/collections'),
                          child: Column(
                            children: [
                              Text(
                                '${s.total(type)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                label,
                                style: context.ds.meta,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          loading: () => const SizedBox(height: 80),
          error: (_, _) => const SizedBox(height: 80),
        ),
        // 菜单
        Card(
          margin: const EdgeInsets.all(12),
          child: Column(
            children: [
              for (final (i, menu) in kUserMenus.indexed) ...[
                if (i > 0) const Divider(indent: 48),
                ListTile(
                  leading: Icon(menu.$2, size: 22, color: theme.colorScheme.primary),
                  title: Text(menu.$1, style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => context.push(menu.$3),
                ),
              ],
            ],
          ),
        ),
        // 时间线/照片墙
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.timeline, size: 22, color: context.ds.star),
                title: const Text('时光机', style: TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  final userId = user.username.isEmpty ? '${user.id}' : user.username;
                  context.push('/user/$userId/timeline');
                },
              ),
              const Divider(indent: 48),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, size: 22, color: Colors.pink),
                title: const Text('照片墙', style: TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  final userId = user.username.isEmpty ? '${user.id}' : user.username;
                  context.push('/user/$userId/milestone');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginGate extends ConsumerWidget {
  const _LoginGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_circle_outlined, size: 56, color: context.ds.textHint),
          const SizedBox(height: 12),
          const Text('登录后同步你的收藏与进度'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('登录'),
          ),
        ],
      ),
    );
  }
}

/// 用户收藏列表页 (用户空间收藏 tab)
final userCollectionsProvider =
    FutureProvider.family<List<CollectionItem>, String>((ref, type) async {
  final client = ref.read(apiClientProvider);
  final me = ref.read(currentUserProvider);
  if (me == null) return const [];
  final userId = me.username.isEmpty ? '${me.id}' : me.username;
  final data = await client.get(apiV0UsersCollections(userId, type, 100, 0, '3'));
  return UserCollection.fromJson(data as Map<String, dynamic>).data;
});

class UserCollectionsScreen extends ConsumerWidget {
  final String type;

  const UserCollectionsScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userCollectionsProvider(type));
    return Scaffold(
      appBar: AppBar(title: Text('我的${SubjectType.pluralText(type)}')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: Cover(url: item.subject.images.common, width: 44, height: 58),
              title: Text(item.subject.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${CollectionStatus.text(item.type)} · 第${item.epStatus}话'),
              onTap: () => context.push('/subject/${item.subject.id}'),
            );
          },
        ),
      ),
    );
  }
}
