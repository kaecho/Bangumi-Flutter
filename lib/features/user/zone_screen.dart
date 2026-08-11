import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/models/collection.dart';
import '../../shared/models/user.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'blogs_screen.dart';
import 'catalogs_screen.dart';
import 'friends_screen.dart';
import 'user_models.dart';
import 'user_timeline_screen.dart';

/// 用户信息 (旧版 API /user/{uid})
final zoneUserProvider = FutureProvider.family<User, String>((ref, userId) async {
  final client = ref.read(apiClientProvider);
  final data = await client.get(apiUserInfo(userId));
  return User.fromJson(data as Map<String, dynamic>);
});

/// 用户收藏统计 (旧版 API /user/{uid}/collections/status)
/// 返回数组 [{type, name, collects:[{status:{id}, count}]}], 转成 CollectionStats
final zoneStatsProvider = FutureProvider.family<CollectionStats, String>((ref, userId) async {
  final client = ref.read(apiClientProvider);
  final data = await client.get(apiUserCollectionsStatus(userId), query: {'app_id': kAppId});
  final byType = <String, Map<int, int>>{};
  for (final raw in data as List) {
    final entry = raw as Map<String, dynamic>;
    final name = entry['name'] as String? ?? '';
    final counts = <int, int>{};
    for (final collect in entry['collects'] as List? ?? const []) {
      final c = collect as Map<String, dynamic>;
      final status = (c['status'] as Map<String, dynamic>? ?? const {})['id'] as num?;
      if (status != null) counts[status.toInt()] = (c['count'] as num?)?.toInt() ?? 0;
    }
    if (name.isNotEmpty) byType[name] = counts;
  }
  return CollectionStats(byType: byType);
});

/// 收藏 tab 数据 (v0 分页)
class ZoneCollectionsData {
  final List<CollectionItem> items;
  final int offset;
  final int total;
  final bool hasMore;

  const ZoneCollectionsData({
    this.items = const [],
    this.offset = 0,
    this.total = 0,
    this.hasMore = true,
  });
}

final zoneCollectionsProvider = AsyncNotifierProvider.family<
    ZoneCollectionsNotifier, ZoneCollectionsData, ({String userId, String type, int status})>(
    ZoneCollectionsNotifier.new);

class ZoneCollectionsNotifier
    extends FamilyAsyncNotifier<ZoneCollectionsData, ({String userId, String type, int status})> {
  @override
  Future<ZoneCollectionsData> build(arg) => _fetch(0);

  Future<ZoneCollectionsData> _fetch(int offset) async {
    final client = ref.read(apiClientProvider);
    final status = arg.status == 0 ? '0' : '${arg.status}';
    final data = await client.get(apiV0UsersCollections(
      arg.userId,
      '${v0SubjectTypeInt(arg.type)}',
      100,
      offset,
      status,
    ));
    final parsed = UserCollection.fromJson(data as Map<String, dynamic>);
    return ZoneCollectionsData(
      items: parsed.data,
      offset: parsed.offset,
      total: parsed.total,
      hasMore: parsed.offset + parsed.data.length < parsed.total,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(current.offset + 100);
      state = AsyncData(ZoneCollectionsData(
        items: [...current.items, ...next.items],
        offset: next.offset,
        total: next.total,
        hasMore: next.hasMore,
      ));
    } catch (_) {}
  }
}

/// 收藏 tab 过滤状态 (类型 + 状态)
class ZoneFilterController extends Notifier<({String type, int status})> {
  @override
  ({String type, int status}) build() => (type: 'anime', status: 0);

  void setFilter(String type, int status) => state = (type: type, status: status);
}

final zoneScreenControllerProvider =
    NotifierProvider<ZoneFilterController, ({String type, int status})>(ZoneFilterController.new);

/// 用户空间 (bgm.tv 用户主页)
class ZoneScreen extends ConsumerStatefulWidget {
  final String userId;

  const ZoneScreen({super.key, required this.userId});

  @override
  ConsumerState<ZoneScreen> createState() => _ZoneScreenState();
}

class _ZoneScreenState extends ConsumerState<ZoneScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 5, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _selectStat(String type, int status) {
    ref.read(zoneScreenControllerProvider.notifier).setFilter(type, status);
    _tab.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(zoneUserProvider(widget.userId));
    final filter = ref.watch(zoneScreenControllerProvider);
    return Scaffold(
      body: userAsync.when(
        loading: () => const Loading(),
        error: (_, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('加载失败'),
              TextButton(
                onPressed: () => ref.invalidate(zoneUserProvider(widget.userId)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (user) => Column(
          children: [
            _ZoneHeader(user: user, userId: widget.userId, onStatTap: _selectStat),
            TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: '收藏'),
                Tab(text: '时间线'),
                Tab(text: '日志'),
                Tab(text: '目录'),
                Tab(text: '好友'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _ZoneCollectionsTab(
                    userId: widget.userId,
                    type: filter.type,
                    status: filter.status,
                  ),
                  UserTimelineBody(userId: widget.userId),
                  UserBlogsList(userId: widget.userId),
                  UserCatalogsList(userId: widget.userId),
                  FriendsList(userId: widget.userId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 头部: 模糊封面背景 + 头像 + 昵称 + 签名 + 收藏统计
class _ZoneHeader extends ConsumerWidget {
  final User user;
  final String userId;
  final void Function(String type, int status) onStatTap;

  const _ZoneHeader({required this.user, required this.userId, required this.onStatTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(zoneStatsProvider(userId));
    final me = ref.watch(currentUserProvider);
    final isMe = me != null && userPathId(me) == userId;

    return Column(
      children: [
        // 封面背景
        SizedBox(
          height: 140,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (user.avatarUrl.isNotEmpty)
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Image.network(
                    user.avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(color: theme.colorScheme.primaryContainer),
                  ),
                )
              else
                Container(color: theme.colorScheme.primaryContainer),
              Container(color: Colors.black.withValues(alpha: 0.25)),
              Positioned(
                left: 16,
                bottom: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Avatar(url: user.avatarUrl, size: 68, name: user.displayName),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '@${user.username.isNotEmpty ? user.username : user.id}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isMe)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                    tooltip: '设置',
                    onPressed: () => context.push('/settings'),
                  ),
                ),
            ],
          ),
        ),
        // 签名
        if (user.sign.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                user.sign,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        // 收藏统计
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Card(
            child: stats.when(
              loading: () => const SizedBox(height: 90),
              error: (_, _) => const SizedBox(height: 90),
              data: (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    for (final (type, label) in kUserTypeTabs)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 48,
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            for (final (status, statusLabel) in [
                              (CollectionStatus.wish, '想看'),
                              (CollectionStatus.doing, '在看'),
                              (CollectionStatus.collect, '看过'),
                              (CollectionStatus.onHold, '搁置'),
                              (CollectionStatus.dropped, '抛弃'),
                            ])
                              Expanded(
                                child: InkWell(
                                  onTap: () => onStatTap(type, status),
                                  child: Column(
                                    children: [
                                      Text(
                                        '${s.count(type, status)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        statusLabel,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 收藏 tab: 类型 + 状态过滤
class _ZoneCollectionsTab extends ConsumerWidget {
  final String userId;
  final String type;
  final int status;

  const _ZoneCollectionsTab({
    required this.userId,
    required this.type,
    required this.status,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(
      zoneCollectionsProvider((userId: userId, type: type, status: status)),
    );

    return Column(
      children: [
        // 类型
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final (t, label) in kUserTypeTabs)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: type == t,
                    onSelected: (_) => ref
                        .read(zoneScreenControllerProvider.notifier)
                        .setFilter(t, status),
                  ),
                ),
            ],
          ),
        ),
        // 状态
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final (s, label) in kCollectionStatusTabs)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: status == s,
                    onSelected: (_) => ref
                        .read(zoneScreenControllerProvider.notifier)
                        .setFilter(type, s),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Loading(),
            error: (_, _) => const Center(child: Text('加载失败')),
            data: (data) {
              if (data.items.isEmpty) return const Center(child: Text('暂无收藏'));
              return ListView.builder(
                itemCount: data.items.length + (data.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= data.items.length) {
                    return Center(
                      child: TextButton(
                        onPressed: () => unawaited(
                          ref
                              .read(zoneCollectionsProvider(
                                (userId: userId, type: type, status: status),
                              ).notifier)
                              .loadMore(),
                        ),
                        child: const Text('加载更多'),
                      ),
                    );
                  }
                  final item = data.items[index];
                  return ListTile(
                    leading: Cover(url: item.subject.images.common, width: 42, height: 56),
                    title: Text(
                      item.subject.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${CollectionStatus.text(item.type)} · 第${item.epStatus}话',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    onTap: () => context.push('/subject/${item.subject.id}'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
