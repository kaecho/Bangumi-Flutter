import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';

/// 我的人物 (收藏的角色)
///
/// 主站 /user/{uid}/mono/character 页面为空壳 (JS 渲染), 改用官方
/// v0 API: GET /v0/users/{username}/collections/-/characters。
class CharacterItem {
  final int id;
  final String name;
  final int type; // 1=角色 2=机体 3=组织
  final String image;
  final String createdAt;

  const CharacterItem({
    this.id = 0,
    this.name = '',
    this.type = 1,
    this.image = '',
    this.createdAt = '',
  });

  factory CharacterItem.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>? ?? const {};
    return CharacterItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      type: (json['type'] as num?)?.toInt() ?? 1,
      image: images['grid'] as String? ?? images['medium'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

final myCharactersProvider = FutureProvider<List<CharacterItem>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final username = user.username.isEmpty ? '${user.id}' : user.username;
  final client = ref.read(apiClientProvider);
  final data = await client.get(apiV0UserCharacters(username));
  final map = data as Map<String, dynamic>;
  return (map['data'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .map(CharacterItem.fromJson)
          .toList() ??
      const [];
});

/// 我的人物
class CharacterScreen extends ConsumerWidget {
  const CharacterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(isLoggedInProvider);
    final characters = ref.watch(myCharactersProvider);

    return Scaffold(
      appBar: BgmAppBar(title: '我的人物', showBackButton: true),
      body: !loggedIn
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('登录后查看收藏的角色'),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => context.push('/login'),
                    child: const Text('去登录'),
                  ),
                ],
              ),
            )
          : characters.when(
              loading: () => const Center(child: Loading()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('加载失败'),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(myCharactersProvider),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('还没有收藏的角色'))
                  : RefreshIndicator(
                      onRefresh: () => ref.refresh(myCharactersProvider.future),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(10),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final item = list[index];
                          return InkWell(
                            onTap: () => context.push(
                              '/mono/${item.type == 1 ? 'character' : 'person'}/${item.id}',
                            ),
                            child: Column(
                              children: [
                                Cover(
                                  url: item.image,
                                  width: double.infinity,
                                  height: double.infinity,
                                  radius: 6,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
    );
  }
}
