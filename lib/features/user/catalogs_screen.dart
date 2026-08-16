import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/loading.dart';

import 'user_models.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';

/// 目录类型计数文案
const kCatalogTypeLabels = {
  '1': '书籍',
  '2': '动画',
  '3': '音乐',
  '4': '游戏',
  '6': '三次元',
};

class UserCatalogsQuery {
  final String userId;
  final bool collect;

  const UserCatalogsQuery(this.userId, {this.collect = false});

  @override
  bool operator ==(Object other) =>
      other is UserCatalogsQuery &&
      other.userId == userId &&
      other.collect == collect;

  @override
  int get hashCode => Object.hash(userId, collect);
}

class UserCatalogsData {
  final List<UserCatalog> items;
  final int page;
  final bool hasMore;

  const UserCatalogsData({
    this.items = const [],
    this.page = 1,
    this.hasMore = true,
  });
}

/// 用户目录列表 (bgm.tv/user/{uid}/index[/collect]?page=, 对齐原版 LIMIT=30)
final userCatalogsProvider =
    AsyncNotifierProvider.family<
      UserCatalogsNotifier,
      UserCatalogsData,
      UserCatalogsQuery
    >(UserCatalogsNotifier.new);

class UserCatalogsNotifier
    extends FamilyAsyncNotifier<UserCatalogsData, UserCatalogsQuery> {
  static const _limit = 30;

  @override
  Future<UserCatalogsData> build(UserCatalogsQuery query) async {
    return _fetch(1, query);
  }

  Future<UserCatalogsData> _fetch(int page, UserCatalogsQuery query) async {
    final client = ref.read(apiClientProvider);
    final html = await client.get(
      apiUserCatalogsHtml(query.userId, page: page, collect: query.collect),
      host: kHost,
    );
    final items = parseUserCatalogs(html as String);
    return UserCatalogsData(
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
        UserCatalogsData(
          items: [...current.items, ...next.items],
          page: next.page,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {}
  }
}

/// 用户目录 (独立页 / 我的目录)
class UserCatalogsScreen extends ConsumerWidget {
  final String userId;

  const UserCatalogsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: BgmAppBar(
          title: 'TA的目录',
          actions: [
            BgmHeaderMore.browser(
              () => openExternalUrl(apiUserCatalogsHtml(userId)),
            ),
          ],
          bottom: const BgmDefaultTabStrip(tabs: [Text('创建的'), Text('收藏的')]),
        ),
        body: UserCatalogsTabs(userId: userId, showTabs: false),
      ),
    );
  }
}

/// 我的目录 (当前登录用户)
class MyCatalogsScreen extends ConsumerWidget {
  const MyCatalogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: BgmAppBar(
          title: '我的目录',
          actions: [
            BgmHeaderMore.browser(() {
              final me = ref.read(currentUserProvider);
              if (me == null) return;
              openExternalUrl(apiUserCatalogsHtml(userPathId(me)));
            }),
          ],
          bottom: const BgmDefaultTabStrip(tabs: [Text('创建的'), Text('收藏的')]),
        ),
        body: me == null
            ? const Center(child: Text('请先登录'))
            : UserCatalogsTabs(userId: userPathId(me), showTabs: false),
      ),
    );
  }
}

/// 创建的 / 收藏的 (对齐原版 user/catalogs TABS)
class UserCatalogsTabs extends StatelessWidget {
  final String userId;
  final bool showTabs;

  const UserCatalogsTabs({
    super.key,
    required this.userId,
    this.showTabs = true,
  });

  @override
  Widget build(BuildContext context) {
    final body = TabBarView(
      children: [
        UserCatalogsList(userId: userId),
        UserCatalogsList(userId: userId, collect: true),
      ],
    );
    if (!showTabs) return body;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const BgmDefaultTabStrip(tabs: [Text('创建的'), Text('收藏的')]),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// 目录列表 (zone tab 与独立页共用)
class UserCatalogsList extends ConsumerStatefulWidget {
  final String userId;
  final bool collect;

  const UserCatalogsList({
    super.key,
    required this.userId,
    this.collect = false,
  });

  @override
  ConsumerState<UserCatalogsList> createState() => _UserCatalogsListState();
}

class _UserCatalogsListState extends ConsumerState<UserCatalogsList> {
  final _scroll = ScrollController();

  UserCatalogsQuery get _query =>
      UserCatalogsQuery(widget.userId, collect: widget.collect);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        unawaited(ref.read(userCatalogsProvider(_query).notifier).loadMore());
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
    final async = ref.watch(userCatalogsProvider(_query));
    return async.when(
      loading: () => const Loading(),
      error: (_, _) =>
          BgmRetry(onRetry: () => ref.invalidate(userCatalogsProvider(_query))),
      data: (data) {
        if (data.items.isEmpty) return const Center(child: Text('暂无目录'));
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
            final catalog = data.items[index];
            return InkWell(
              onTap: () => context.push('/catalog/${catalog.id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catalog.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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
                          [
                            catalog.created,
                            catalog.updated,
                          ].where((e) => e.isNotEmpty).join(' / '),
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
