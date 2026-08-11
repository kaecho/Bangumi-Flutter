import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/widgets/loading.dart';
import 'user_models.dart';

/// 目录类型计数文案
const kCatalogTypeLabels = {
  '1': '书籍',
  '2': '动画',
  '3': '音乐',
  '4': '游戏',
  '6': '三次元',
};

/// 用户目录列表 (bgm.tv/user/{uid}/index, 主站 HTML)
final userCatalogsProvider = FutureProvider.family<List<UserCatalog>, String>((ref, userId) async {
  final client = ref.read(apiClientProvider);
  final html = await client.get(apiUserCatalogsHtml(userId), host: kHost);
  return parseUserCatalogs(html as String);
});

/// 用户目录 (独立页 / 我的目录)
class UserCatalogsScreen extends ConsumerWidget {
  final String userId;

  const UserCatalogsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('目录')),
      body: UserCatalogsList(userId: userId),
    );
  }
}

/// 我的目录 (当前登录用户)
class MyCatalogsScreen extends ConsumerWidget {
  const MyCatalogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('我的目录')),
      body: me == null
          ? const Center(child: Text('请先登录'))
          : UserCatalogsList(userId: userPathId(me)),
    );
  }
}

/// 目录列表 (zone tab 与独立页共用)
class UserCatalogsList extends ConsumerWidget {
  final String userId;

  const UserCatalogsList({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userCatalogsProvider(userId));
    return async.when(
      loading: () => const Loading(),
      error: (_, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('加载失败'),
            TextButton(
              onPressed: () => ref.invalidate(userCatalogsProvider(userId)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (catalogs) {
        if (catalogs.isEmpty) return const Center(child: Text('暂无目录'));
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: catalogs.length,
          itemBuilder: (context, index) {
            final catalog = catalogs[index];
            return InkWell(
              onTap: () => context.push('/catalog/${catalog.id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catalog.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (catalog.desc.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        catalog.desc,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        for (final entry in catalog.counts.entries)
                          if (entry.value > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                '${kCatalogTypeLabels[entry.key] ?? entry.key} ${entry.value}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                        const Spacer(),
                        Text(
                          [catalog.created, catalog.updated].where((e) => e.isNotEmpty).join(' / '),
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
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
