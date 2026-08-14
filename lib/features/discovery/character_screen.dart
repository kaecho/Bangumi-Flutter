import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'widgets/discovery_html.dart';

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

final myPersonsProvider = FutureProvider<List<CharacterItem>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final username = user.username.isEmpty ? '${user.id}' : user.username;
  final client = ref.read(apiClientProvider);
  try {
    final data = await client.get(apiV0UserPersons(username));
    final map = data as Map<String, dynamic>;
    return (map['data'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(CharacterItem.fromJson)
            .toList() ??
        const [];
  } catch (_) {
    return const [];
  }
});

class MonoRecentsData {
  final List<MonoRecentItem> items;
  final int page;
  final bool hasMore;

  const MonoRecentsData({
    this.items = const [],
    this.page = 1,
    this.hasMore = true,
  });
}

/// 收藏人物的最近作品 (bgm.tv/mono/update, 对齐原版 LIMIT=20)
final monoRecentsProvider =
    AsyncNotifierProvider<MonoRecentsNotifier, MonoRecentsData>(
      MonoRecentsNotifier.new,
    );

class MonoRecentsNotifier extends AsyncNotifier<MonoRecentsData> {
  static const _limit = 20;

  @override
  Future<MonoRecentsData> build() => _fetch(1);

  Future<MonoRecentsData> _fetch(int page) async {
    final client = ref.read(apiClientProvider);
    final html = await client.get(htmlUserMonoRecents(page: page), host: kHost);
    final items = parseMonoRecents(html as String);
    return MonoRecentsData(
      items: items,
      page: page,
      hasMore: items.length >= _limit,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(current.page + 1);
      state = AsyncData(
        MonoRecentsData(
          items: [...current.items, ...next.items],
          page: next.page,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {}
  }
}

/// 我的人物 (原项目 tabs: 人物近况 / 虚拟角色 / 现实人物)
class CharacterScreen extends ConsumerStatefulWidget {
  const CharacterScreen({super.key});

  @override
  ConsumerState<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends ConsumerState<CharacterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(isLoggedInProvider);
    final characters = ref.watch(myCharactersProvider);
    final persons = ref.watch(myPersonsProvider);

    return Scaffold(
      appBar: BgmAppBar(
        title: '我的人物',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: '浏览器查看',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => openExternalUrl('$kHost/mono/update'),
          ),
        ],
      ),

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
          : Column(
              children: [
                TabBar(
                  controller: _tab,
                  tabs: const [
                    Tab(text: '人物近况'),
                    Tab(text: '虚拟角色'),
                    Tab(text: '现实人物'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      const _RecentsList(),
                      characters.when(
                        loading: () => const Center(child: Loading()),
                        error: (_, _) => Center(
                          child: FilledButton.tonal(
                            onPressed: () =>
                                ref.invalidate(myCharactersProvider),
                            child: const Text('重试'),
                          ),
                        ),
                        data: (list) => _CharacterGrid(
                          items: list,
                          emptyText: '还没有收藏的角色',
                          onRefresh: () async =>
                              ref.invalidate(myCharactersProvider),
                        ),
                      ),
                      persons.when(
                        loading: () => const Center(child: Loading()),
                        error: (_, _) => Center(
                          child: FilledButton.tonal(
                            onPressed: () => ref.invalidate(myPersonsProvider),
                            child: const Text('重试'),
                          ),
                        ),
                        data: (list) => _CharacterGrid(
                          items: list,
                          emptyText: '还没有收藏的人物',
                          onRefresh: () async =>
                              ref.invalidate(myPersonsProvider),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _CharacterGrid extends StatelessWidget {
  final List<CharacterItem> items;
  final String emptyText;
  final Future<void> Function() onRefresh;

  const _CharacterGrid({
    required this.items,
    required this.emptyText,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(child: Text(emptyText)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return InkWell(
            onTap: () => context.push(
              '/mono/${item.type == 1 ? 'character' : 'person'}/${item.id}',
            ),
            child: Column(
              children: [
                Expanded(
                  child: Cover(
                    url: item.image,
                    width: double.infinity,
                    height: double.infinity,
                    radius: 6,
                  ),
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
    );
  }
}

class _RecentsList extends ConsumerStatefulWidget {
  const _RecentsList();

  @override
  ConsumerState<_RecentsList> createState() => _RecentsListState();
}

class _RecentsListState extends ConsumerState<_RecentsList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        unawaited(ref.read(monoRecentsProvider.notifier).loadMore());
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
    final async = ref.watch(monoRecentsProvider);
    return async.when(
      loading: () => const Center(child: Loading()),
      error: (_, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('加载失败'),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(monoRecentsProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (data) {
        if (data.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(monoRecentsProvider),
            child: ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('收藏你喜欢的角色/声优/团体\n追踪最新相关作品动态')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(monoRecentsProvider),
          child: ListView.separated(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: data.items.length + (data.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 16),
            itemBuilder: (context, index) {
              if (index >= data.items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final item = data.items[index];
              return InkWell(
                onTap: item.id == 0
                    ? null
                    : () => context.push('/subject/${item.id}'),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Cover(url: item.cover, width: 64, height: 86, radius: 4),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name.isEmpty ? item.nameJp : item.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.name.isNotEmpty && item.nameJp.isNotEmpty)
                            Text(
                              item.nameJp,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (item.info.isNotEmpty)
                            Text(
                              item.info,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (item.star > 0)
                            Text(
                              '${item.star} 分 ${item.starInfo}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          if (item.actors.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  for (final actor in item.actors.take(4))
                                    InkWell(
                                      onTap: actor.$1.isEmpty
                                          ? null
                                          : () => context.push(
                                              '/mono/${actor.$1}',
                                            ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Cover(
                                            url: actor.$2,
                                            width: 22,
                                            height: 22,
                                            radius: 11,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            actor.$3,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
