import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';
import '../../shared/models/collection.dart';
import '../../shared/models/user.dart';

import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/tab_title.dart';

import '../subject/collection_sheet.dart';
import 'user_models.dart';
import 'zone_screen.dart';

/// 用户空间菜单 (原项目 user/v2 DATA_ME)
const kUserMenus = [
  ('我的空间', Icons.person_pin_outlined, 'zone'),
  ('我的好友', Icons.group_outlined, 'friends'),
  ('我的反向好友', Icons.group_add_outlined, 'rev-friends'),
  ('我的人物', Icons.person_outline, '/my-mono'),
  ('我的目录', Icons.folder_special_outlined, '/my-catalogs'),
  ('我的日志', Icons.edit_note_outlined, '/my-blogs'),
  ('我的词云', Icons.cloud_outlined, '/wordcloud'),
  ('时光机', Icons.timeline, '/my-timeline'),
  ('Netaba 统计', Icons.bar_chart_outlined, 'netaba'),
  ('照片墙', Icons.photo_library_outlined, '/my-milestone'),
  ('本地管理', Icons.folder_outlined, '/settings/smb'),
  ('本地备份', Icons.inbox_outlined, '/settings/backup'),
  ('设置', Icons.settings_outlined, '/settings'),
];

/// 收藏状态 Tab (原项目 COLLECTION_STATUS, 无「全部」)
const kMyStatusTabs = [
  (CollectionStatus.wish, '想看'),
  (CollectionStatus.collect, '看过'),
  (CollectionStatus.doing, '在看'),
  (CollectionStatus.onHold, '搁置'),
  (CollectionStatus.dropped, '抛弃'),
];

/// 收藏排序 (原项目 COLLECTIONS_ORDERBY)
const kMyOrderOptions = [
  ('', '收藏时间'),
  ('rate', '评价'),
  ('date', '发售日'),
  ('title', '名称'),
  ('score', '网站评分'),
];

/// 收藏统计
final collectionStatsProvider = FutureProvider<CollectionStats>((ref) async {
  final client = ref.read(apiClientProvider);
  final me = ref.read(currentUserProvider);
  if (me == null) return const CollectionStats();
  final userId = me.username.isEmpty ? '${me.id}' : me.username;
  final data = await client.get(apiUserCollectionsStatus(userId));
  return CollectionStats.fromJson(data);
});

/// 「我的」Tab 收藏浏览查询
typedef MyCollectionsArg = ({String type, int status});

final myCollectionsProvider =
    AsyncNotifierProvider.family<
      MyCollectionsNotifier,
      ZoneCollectionsData,
      MyCollectionsArg
    >(MyCollectionsNotifier.new);

class MyCollectionsNotifier
    extends FamilyAsyncNotifier<ZoneCollectionsData, MyCollectionsArg> {
  @override
  Future<ZoneCollectionsData> build(MyCollectionsArg arg) => _fetch(0);

  Future<ZoneCollectionsData> _fetch(int offset) async {
    final me = ref.read(currentUserProvider);
    if (me == null) return const ZoneCollectionsData(hasMore: false);
    final userId = me.username.isEmpty ? '${me.id}' : me.username;
    final client = ref.read(apiClientProvider);
    final data = await client.get(
      apiV0UsersCollections(
        userId,
        '${v0SubjectTypeInt(arg.type)}',
        100,
        offset,
        '${arg.status}',
      ),
    );
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
      state = AsyncData(
        ZoneCollectionsData(
          items: [...current.items, ...next.items],
          offset: next.offset,
          total: next.total,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {}
  }
}

/// 用户 Tab (Tab 5) — 对齐原项目 screens/user/v2 收藏浏览
class UserScreen extends ConsumerStatefulWidget {
  const UserScreen({super.key});

  @override
  ConsumerState<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends ConsumerState<UserScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(
    length: kMyStatusTabs.length,
    vsync: this,
  );
  String _type = 'anime';
  String _order = '';
  String _query = '';
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _tab.addListener(() {
      if (_tab.indexIsChanging) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String _userIdOf(User user) =>
      user.username.isEmpty ? '${user.id}' : user.username;
  @override
  Widget build(BuildContext context) {
    final isLogin = ref.watch(isLoggedInProvider);
    final user = ref.watch(currentUserProvider);
    if (!isLogin || user == null) {
      return Scaffold(
        appBar: AppBar(title: const TabLogoTitle('我的')),

        body: const _LoginGate(),
      );
    }

    final status = kMyStatusTabs[_tab.index].$1;
    final arg = (type: _type, status: status);
    final async = ref.watch(myCollectionsProvider(arg));
    final stats = ref.watch(collectionStatsProvider).valueOrNull;

    return Scaffold(
      body: Column(
        children: [
          _MyHeader(user: user, userId: _userIdOf(user)),
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                PopupMenuButton<String>(
                  tooltip: '类型',
                  onSelected: (v) => setState(() => _type = v),
                  itemBuilder: (_) => [
                    for (final t in kUserTypeTabs)
                      PopupMenuItem(value: t.$1, child: Text(t.$2)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          kUserTypeTabs
                              .firstWhere(
                                (e) => e.$1 == _type,
                                orElse: () => ('anime', '动画'),
                              )
                              .$2,
                          style: context.ds.label,
                        ),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBar(
                    controller: _tab,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    onTap: (_) => setState(() {}),
                    tabs: [
                      for (final t in kMyStatusTabs)
                        Tab(
                          child: _StatusTabLabel(
                            title: SubjectType.statusText(t.$1, _type),
                            count: stats?.count(_type, t.$1) ?? 0,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _MyToolBar(
            order: _order,
            searchOpen: _searchOpen,
            onOrder: (v) => setState(() => _order = v),
            onToggleSearch: () => setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) _query = '';
            }),
            onToggleLayout: () => unawaited(
              SettingsStore.instance.setUserList(
                !SettingsStore.instance.userList,
              ),
            ),
          ),
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: '搜索收藏',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
          Expanded(
            child: async.when(
              loading: () => const Loading(text: '加载中...'),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(apiErrorMessage(e), style: context.ds.caption),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(myCollectionsProvider(arg)),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
              data: (data) {
                final q = _query.trim();
                var items = _sorted(data.items, _order);
                if (q.isNotEmpty) {
                  items = items
                      .where(
                        (e) =>
                            pinYinFilterValue(e.subject.displayName, q) !=
                                null ||
                            pinYinFilterValue(e.subject.name, q) != null ||
                            pinYinFilterValue(e.subject.nameCn, q) != null,
                      )
                      .toList();
                }
                if (items.isEmpty) {
                  return const Center(child: Text('暂无收藏'));
                }
                final store = ref.watch(settingsStoreProvider);
                final showMore =
                    data.hasMore && q.isEmpty && !store.userPagination;
                final extra = showMore || store.userPagination ? 1 : 0;
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(myCollectionsProvider(arg)),
                  child: store.userList
                      ? ListView.builder(
                          itemCount: items.length + extra,
                          itemBuilder: (context, index) {
                            if (index >= items.length) {
                              return _MyListFooter(
                                loaded: items.length,
                                total: data.total,
                                showMore: showMore,
                                onMore: () => unawaited(
                                  ref
                                      .read(myCollectionsProvider(arg).notifier)
                                      .loadMore(),
                                ),
                              );
                            }
                            return _MyCollectionRow(
                              item: items[index],
                              showManage: store.userShowManage,
                              commentsFull: store.userCommentsFull,
                              commentsLines: store.userCommentsLines,
                            );
                          },
                        )
                      : CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.all(8),
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: store.userGridNum,
                                      childAspectRatio: 0.62,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _MyCollectionCard(
                                    item: items[index],
                                    showManage: store.userShowManage,
                                  ),
                                  childCount: items.length,
                                ),
                              ),
                            ),
                            if (extra > 0)
                              SliverToBoxAdapter(
                                child: _MyListFooter(
                                  loaded: items.length,
                                  total: data.total,
                                  showMore: showMore,
                                  onMore: () => unawaited(
                                    ref
                                        .read(
                                          myCollectionsProvider(arg).notifier,
                                        )
                                        .loadMore(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<CollectionItem> _sorted(List<CollectionItem> items, String order) {
    final next = [...items];
    switch (order) {
      case 'rate':
        next.sort((a, b) => b.rate.compareTo(a.rate));
      case 'date':
        next.sort((a, b) => b.subject.airDate.compareTo(a.subject.airDate));
      case 'title':
        next.sort(
          (a, b) => a.subject.displayName.compareTo(b.subject.displayName),
        );
      case 'score':
        next.sort(
          (a, b) => (b.subject.rating?.score ?? 0).compareTo(
            a.subject.rating?.score ?? 0,
          ),
        );
      default:
        break;
    }
    return next;
  }
}

class _MyHeader extends ConsumerWidget {
  final User user;
  final String userId;

  const _MyHeader({required this.user, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (user.avatarUrl.isNotEmpty)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Image.network(user.avatarUrl, fit: BoxFit.cover),
            )
          else
            ColoredBox(color: context.ds.accent),
          const ColoredBox(color: Color(0x66000000)),
          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/settings/user'),
                        child: Avatar(
                          url: user.avatarUrl,
                          size: 72,
                          name: user.displayName,
                          userId: userId,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: ref.watch(settingsStoreProvider).logoToggleTheme
                            ? () => ref
                                  .read(settingsStoreProvider)
                                  .toggleThemeMode()
                            : null,
                        onLongPress: () => context.push('/settings'),
                        child: Text(
                          user.displayName,
                          style: context.ds.title.copyWith(color: Colors.white),
                        ),
                      ),

                      GestureDetector(
                        onLongPress: () =>
                            Clipboard.setData(ClipboardData(text: userId)),
                        child: Text(
                          '@$userId',
                          style: context.ds.caption.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Row(
                    children: [
                      PopupMenuButton<String>(
                        tooltip: '更多',
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (path) {
                          switch (path) {
                            case 'zone':
                              context.push('/user/$userId');
                            case 'friends':
                              context.push('/my-friends');
                            case 'rev-friends':
                              context.push('/my-friends?rev=1');
                            case 'netaba':
                              context.push(
                                '/web/${Uri.encodeComponent('https://netaba.re/user/$userId')}',
                              );
                            case '/my-timeline':
                              context.push('/user/$userId/timeline');
                            case '/my-milestone':
                              context.push('/user/$userId/milestone');
                            default:
                              context.push(path);
                          }
                        },
                        itemBuilder: (_) => [
                          for (final menu in kUserMenus)
                            PopupMenuItem(value: menu.$3, child: Text(menu.$1)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        tooltip: '退出登录',
                        onPressed: () =>
                            ref.read(authControllerProvider.notifier).logout(),
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
  }
}

class _MyToolBar extends StatelessWidget {
  final String order;
  final bool searchOpen;
  final ValueChanged<String> onOrder;
  final VoidCallback onToggleSearch;
  final VoidCallback onToggleLayout;

  const _MyToolBar({
    required this.order,
    required this.searchOpen,
    required this.onOrder,
    required this.onToggleSearch,
    required this.onToggleLayout,
  });

  @override
  Widget build(BuildContext context) {
    final store = SettingsStore.instance;
    final orderLabel = kMyOrderOptions
        .firstWhere((e) => e.$1 == order, orElse: () => ('', '收藏时间'))
        .$2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 4),
      child: Row(
        children: [
          PopupMenuButton<String>(
            tooltip: '排序',
            onSelected: onOrder,
            itemBuilder: (_) => [
              for (final o in kMyOrderOptions)
                PopupMenuItem(value: o.$1, child: Text(o.$2)),
            ],
            child: _ChipLabel(text: orderLabel, icon: Icons.sort),
          ),
          const Spacer(),
          IconButton(
            tooltip: searchOpen ? '关闭搜索' : '搜索',
            icon: Icon(searchOpen ? Icons.close : Icons.search),
            onPressed: onToggleSearch,
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'layout':
                  onToggleLayout();
                case 'pagination':
                  unawaited(store.setUserPagination(!store.userPagination));
                case 'year':
                  unawaited(store.setUserShowYear(!store.userShowYear));
                case 'setting':
                  context.push('/settings');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'layout',
                child: Text(store.userList ? '布局: 网格' : '布局: 列表'),
              ),
              PopupMenuItem(
                value: 'pagination',
                child: Text(store.userPagination ? '分页: 关闭' : '分页: 开启'),
              ),
              if (!store.userList)
                PopupMenuItem(
                  value: 'year',
                  child: Text(store.userShowYear ? '年份: 不显示' : '年份: 显示'),
                ),
              const PopupMenuItem(value: 'setting', child: Text('设置')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MyCollectionCard extends StatelessWidget {
  final CollectionItem item;
  final bool showManage;

  const _MyCollectionCard({required this.item, required this.showManage});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/subject/${item.subject.id}'),
      onLongPress: showManage
          ? () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => CollectionSheet(subjectId: item.subject.id),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Cover(
              url: item.subject.images.common,
              width: double.infinity,
              height: double.infinity,
              radius: 6,
              type: item.subject.type,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.subject.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.ds.caption,
          ),
          if (SettingsStore.instance.userShowYear &&
              item.subject.airDate.isNotEmpty)
            Text(
              formatSubjectAirDate(
                item.subject.airDate,
                showMonth: item.subject.type == 'anime',
              ),
              style: context.ds.tiny,
            ),
        ],
      ),
    );
  }
}

class _MyListFooter extends StatelessWidget {
  final int loaded;
  final int total;
  final bool showMore;
  final VoidCallback onMore;

  const _MyListFooter({
    required this.loaded,
    required this.total,
    required this.showMore,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    if (showMore) {
      return Center(
        child: TextButton(onPressed: onMore, child: const Text('加载更多')),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Center(
        child: Text('已加载 $loaded / $total', style: context.ds.caption),
      ),
    );
  }
}

class _StatusTabLabel extends StatelessWidget {
  final String title;
  final int count;

  const _StatusTabLabel({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        if (count > 0) ...[
          const SizedBox(width: 4),
          Text('$count', style: context.ds.tiny),
        ],
      ],
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final String text;
  final IconData icon;

  const _ChipLabel({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ds.surfaceCard,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ds.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ds.textHint),
          const SizedBox(width: 4),
          Text(text, style: ds.caption),
          Icon(Icons.arrow_drop_down, size: 16, color: ds.textHint),
        ],
      ),
    );
  }
}

class _MyCollectionRow extends StatelessWidget {
  final CollectionItem item;
  final bool showManage;
  final bool commentsFull;
  final int commentsLines;

  const _MyCollectionRow({
    required this.item,
    this.showManage = false,
    this.commentsFull = true,
    this.commentsLines = 8,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final score = item.subject.rating?.score ?? 0;
    final comment = item.comment.trim();
    final commentText = comment.isEmpty
        ? null
        : Text(
            comment,
            maxLines: commentsLines,
            overflow: commentsLines >= 100
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: ds.caption,
          );
    return InkWell(
      onTap: () => context.push('/subject/${item.subject.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Cover(
                  url: item.subject.images.common,
                  width: 48,
                  height: 64,
                  type: item.subject.type,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.subject.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ds.bodyStrong.copyWith(
                          fontSize: visualFontSize(
                            item.subject.displayName,
                            const [(32, 10), (20, 11), (0, 12)],
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),
                      Text(
                        [
                          SubjectType.statusText(item.type, item.subject.type),
                          if (item.epStatus > 0) '看到第${item.epStatus}话',
                          if (item.rate > 0) '我的评分 ${item.rate}',
                          if (score > 0) '站点 ${score.toStringAsFixed(1)}',
                        ].join(' · '),

                        style: ds.caption.copyWith(color: ds.textHint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!commentsFull && commentText != null) commentText,
                    ],
                  ),
                ),
                if (showManage)
                  IconButton(
                    tooltip: '收藏管理',
                    icon: const Icon(Icons.star_outline, size: 20),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) =>
                          CollectionSheet(subjectId: item.subject.id),
                    ),
                  ),
              ],
            ),
            if (commentsFull && commentText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: commentText,
              ),
          ],
        ),
      ),
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
          Icon(
            Icons.account_circle_outlined,
            size: 56,
            color: context.ds.textHint,
          ),
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

/// 用户收藏列表页 (用户空间收藏 tab, 按类型入口)
final userCollectionsProvider =
    FutureProvider.family<List<CollectionItem>, String>((ref, type) async {
      final client = ref.read(apiClientProvider);
      final me = ref.read(currentUserProvider);
      if (me == null) return const [];
      final userId = me.username.isEmpty ? '${me.id}' : me.username;
      final data = await client.get(
        apiV0UsersCollections(userId, type, 100, 0, '3'),
      );
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
              leading: Cover(
                url: item.subject.images.common,
                width: 44,
                height: 58,
              ),
              title: Text(
                item.subject.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${SubjectType.statusText(item.type, item.subject.type)} · 第${item.epStatus}话',
              ),
              onTap: () => context.push('/subject/${item.subject.id}'),
            );
          },
        ),
      ),
    );
  }
}
