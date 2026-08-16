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
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/tab_title.dart';
import '../../shared/widgets/app_bar.dart';

import '../../shared/widgets/mesume.dart';
import '../../shared/widgets/score.dart';

import '../progress/progress_filter.dart';

import '../subject/collection_sheet.dart';
import 'user_models.dart';
import 'zone_screen.dart';

/// 用户空间菜单 (原项目 user/v2 DATA_ME)
const kUserMenus = [
  ('我的空间', Icons.person_pin_outlined, 'zone'),
  ('我的好友', Icons.group_outlined, 'friends'),
  ('谁加我为好友', Icons.group_add_outlined, 'rev-friends'),
  ('我的人物', Icons.person_outline, '/my-mono'),
  ('我的目录', Icons.folder_special_outlined, '/my-catalogs'),
  ('我的日志', Icons.edit_note_outlined, '/my-blogs'),
  ('我的词云', Icons.cloud_outlined, '/wordcloud'),
  ('我的时间线', Icons.timeline, '/my-timeline'),
  ('我的netaba.re', Icons.bar_chart_outlined, 'netaba'),
];

/// 原版时光机工具栏更多
List<(String, String)> myCollectionMoreItems({
  required bool list,
  required bool pagination,
  required bool showYear,
}) => [
  ('layout', '布　局〔${list ? '列表' : '网格'}〕'),
  ('pagination', '分页器〔${pagination ? '开启' : '关闭'}〕'),
  if (!list) ('year', '年　份〔${showYear ? '显示' : '不显示'}〕'),
  ('setting', '设置'),
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
typedef MyCollectionsArg = ({
  String userId,
  String type,
  int status,
  int page,
  bool pagination,
  String order,
  String tag,
});

final myCollectionsProvider =
    AsyncNotifierProvider.family<
      MyCollectionsNotifier,
      ZoneCollectionsData,
      MyCollectionsArg
    >(MyCollectionsNotifier.new);

class MyCollectionsNotifier
    extends FamilyAsyncNotifier<ZoneCollectionsData, MyCollectionsArg> {
  static const pageSize = 24;

  @override
  Future<ZoneCollectionsData> build(MyCollectionsArg arg) =>
      _fetch(arg.pagination ? arg.page : 1);

  Future<ZoneCollectionsData> _fetch(int page) async {
    final userId = arg.userId;
    if (userId.isEmpty) return const ZoneCollectionsData(hasMore: false);
    final client = ref.read(apiClientProvider);
    try {
      final html = await client.fetchHtml(
        htmlUserCollections(
          userId,
          scope: arg.type,
          type: htmlCollectionStatus(arg.status),
          order: arg.order,
          tag: arg.tag,
          page: page,
        ),
      );
      final parsed = parseUserCollections(
        html,
        subjectType: arg.type,
        status: arg.status,
      );
      if (parsed.items.isNotEmpty || parsed.pageTotal > 1) {
        return ZoneCollectionsData(
          items: parsed.items,
          offset: (page - 1) * pageSize,
          total: parsed.pageTotal * pageSize,
          hasMore: page < parsed.pageTotal,
          pageTotal: parsed.pageTotal,
        );
      }
    } catch (_) {}
    final data = await client.get(
      apiV0UsersCollections(
        userId,
        '${v0SubjectTypeInt(arg.type)}',
        100,
        arg.pagination ? (arg.page - 1) * 100 : 0,
        '${arg.status}',
      ),
    );

    final parsed = UserCollection.fromJson(data as Map<String, dynamic>);
    return ZoneCollectionsData(
      items: parsed.data,
      offset: parsed.offset,
      total: parsed.total,
      hasMore: parsed.offset + parsed.data.length < parsed.total,
      pageTotal: (parsed.total / 100).ceil().clamp(1, 9999),
    );
  }

  Future<void> loadMore() async {
    if (arg.pagination) return;
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final nextPage = (current.offset ~/ pageSize) + 2;
      final next = await _fetch(nextPage);
      state = AsyncData(
        ZoneCollectionsData(
          items: [...current.items, ...next.items],
          offset: next.offset,
          total: next.total,
          hasMore: next.hasMore,
          pageTotal: next.pageTotal,
        ),
      );
    } catch (_) {}
  }
}

typedef MyCollectionTagsArg = ({String userId, String type, int status});

/// 时光机标签 (原项目 userCollectionsTags, 主站 #userTagList)
final myCollectionTagsProvider =
    FutureProvider.family<List<UserCollectionTag>, MyCollectionTagsArg>((
      ref,
      arg,
    ) async {
      try {
        final html = await ref
            .read(apiClientProvider)
            .fetchHtml(
              htmlUserCollections(
                arg.userId,
                scope: arg.type,
                type: htmlCollectionStatus(arg.status),
              ),
            );
        return parseUserCollectionsTags(html);
      } catch (_) {
        return const [];
      }
    });

/// 用户 Tab (Tab 5) — 对齐原项目 screens/user/v2 收藏浏览
class UserScreen extends ConsumerStatefulWidget {
  final String? userId;

  const UserScreen({super.key, this.userId});

  @override
  ConsumerState<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends ConsumerState<UserScreen> {
  int _status = 0;
  String _type = 'anime';
  String _order = '';
  String _tag = '';
  String _query = '';
  int _page = 1;
  bool _searchOpen = false;
  bool _fixed = false;
  final _filterController = TextEditingController();

  static const _headerHeight = 280.0;
  static const _fixedOffset = 20.0;

  String _userIdOf(User user) =>
      user.username.isEmpty ? '${user.id}' : user.username;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final next = n.metrics.pixels >= _headerHeight - 88 - _fixedOffset;
    if (next != _fixed) setState(() => _fixed = next);
    return false;
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = ref.watch(isLoggedInProvider);
    final me = ref.watch(currentUserProvider);
    final targetId = widget.userId?.trim() ?? '';
    final isMe = targetId.isEmpty || (me != null && _userIdOf(me) == targetId);
    if (isMe && (!isLogin || me == null)) {
      return Scaffold(appBar: const LogoHeader(), body: const _LoginGate());
    }
    final user = isMe
        ? me!
        : User(id: 0, username: targetId, nickname: targetId);

    final status = kMyStatusTabs[_status].$1;
    final pagination = ref.watch(
      settingsStoreProvider.select((s) => s.userPagination),
    );
    final arg = (
      userId: _userIdOf(user),
      type: _type,
      status: status,
      page: _page,
      pagination: pagination,
      order: _order,
      tag: _tag,
    );

    final async = ref.watch(myCollectionsProvider(arg));
    final stats = ref.watch(collectionStatsProvider).valueOrNull;
    final tags =
        ref
            .watch(
              myCollectionTagsProvider((
                userId: _userIdOf(user),
                type: _type,
                status: status,
              )),
            )
            .valueOrNull ??
        const [];

    return Scaffold(
      appBar: isMe
          ? null
          : BgmAppBar(title: '$targetId的收藏', showBackButton: true),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Column(
          children: [
            if (isMe)
              _MyHeader(user: user, userId: _userIdOf(user), fixed: _fixed),

            ColoredBox(
              color: context.ds.surfaceCard,
              child: Row(
                children: [
                  PopupMenuButton<String>(
                    tooltip: '类型',
                    onSelected: (v) => setState(() {
                      _type = v;
                      _tag = '';
                      _page = 1;
                    }),
                    itemBuilder: (_) => [
                      for (final t in kUserTypeTabs)
                        PopupMenuItem(value: t.$1, child: Text(t.$2)),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                      child: _UserTypeBtn(
                        label: kUserTypeTabs
                            .firstWhere(
                              (e) => e.$1 == _type,
                              orElse: () => ('anime', '动画'),
                            )
                            .$2,
                      ),
                    ),
                  ),

                  Expanded(
                    child: BgmTabStrip(
                      scrollable: true,
                      index: _status,
                      onSelect: (i) => setState(() {
                        _status = i;
                        _tag = '';
                        _page = 1;
                      }),
                      tabs: [
                        for (final t in kMyStatusTabs)
                          _StatusTabLabel(
                            title: SubjectType.statusText(t.$1, _type),
                            count: stats?.count(_type, t.$1) ?? 0,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _MyToolBar(
              order: _order,
              tag: _tag,
              tags: tags,
              searchOpen: _searchOpen,
              page: _page,
              pageTotal: pagination ? (async.valueOrNull?.pageTotal ?? 1) : 0,
              onOrder: (v) => setState(() {
                _order = v;
                _page = 1;
              }),
              onTag: (v) => setState(() {
                _tag = parseUserCollectionTagSelect(v);
                _page = 1;
              }),

              onPage: (v) => setState(() => _page = v),
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
              ProgressFilterBar(
                controller: _filterController,
                length: 0,
                fetching: false,
                onChanged: (v) => setState(() => _query = v.trim()),
              ),

            Expanded(
              child: async.when(
                loading: () => const Loading(text: '加载中...'),
                error: (e, _) => BgmRetry(
                  message: apiErrorMessage(e),
                  onRetry: () => ref.invalidate(myCollectionsProvider(arg)),
                ),
                data: (data) {
                  final q = _query.trim();
                  var items = data.items;
                  if (q.isNotEmpty) {
                    items = [
                      for (final e in items)
                        if (pinYinFilterValue(e.subject.displayName, q) !=
                                null ||
                            pinYinFilterValue(e.subject.name, q) != null ||
                            pinYinFilterValue(e.subject.nameCn, q) != null)
                          e,
                    ];
                  }

                  if (items.isEmpty) {
                    return const Center(child: _MyEmpty());
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
                                  page: _page,
                                  pageTotal: data.pageTotal,
                                  onPage: store.userPagination
                                      ? (v) => setState(() => _page = v)
                                      : null,
                                  onMore: () => unawaited(
                                    ref
                                        .read(
                                          myCollectionsProvider(arg).notifier,
                                        )
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
                                    page: _page,
                                    pageTotal: data.pageTotal,
                                    onPage: store.userPagination
                                        ? (v) => setState(() => _page = v)
                                        : null,
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
      ),
    );
  }
}

class _UserTypeBtn extends StatelessWidget {
  final String label;

  const _UserTypeBtn({required this.label});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Container(
      width: 56,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ds.accentSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ds.accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: ds.caption.copyWith(
          color: ds.accent,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MyEmpty extends StatelessWidget {
  const _MyEmpty();

  @override
  Widget build(BuildContext context) {
    final speech = SettingsStore.instance.speech;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Mesume(size: 80),
          const SizedBox(height: 12),
          Text(
            speech ? randomMesumeSpeech() : '暂无收藏',
            style: context.ds.caption.copyWith(fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MyHeader extends ConsumerWidget {
  final User user;
  final String userId;
  final bool fixed;

  const _MyHeader({
    required this.user,
    required this.userId,
    required this.fixed,
  });

  static const double _height = 280;
  static const double _bar = 88;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = context.ds;
    final top = MediaQuery.paddingOf(context).top;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: fixed ? _bar + top : _height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (user.avatarUrl.isNotEmpty)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Image.network(user.avatarUrl, fit: BoxFit.cover),
            )
          else
            ColoredBox(color: ds.accent),
          ColoredBox(color: Color(fixed ? 0x99000000 : 0x3D000000)),
          SafeArea(
            bottom: false,
            child: fixed
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        _menu(context),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => context.push('/settings/user'),
                          child: Avatar(
                            url: user.avatarUrl,
                            size: 28,
                            name: user.displayName,
                            userId: userId,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ds.bodyStrong.copyWith(color: Colors.white),
                          ),
                        ),
                        _trailing(context),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => context.push('/settings/user'),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xCCFFFFFF),
                                  shape: BoxShape.circle,
                                ),
                                child: Avatar(
                                  url: user.avatarUrl,
                                  size: 72,
                                  name: user.displayName,
                                  userId: userId,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap:
                                      ref
                                          .watch(settingsStoreProvider)
                                          .logoToggleTheme
                                      ? () => ref
                                            .read(settingsStoreProvider)
                                            .toggleThemeMode()
                                      : null,
                                  onLongPress: () => context.push('/settings'),
                                  child: Text(
                                    user.displayName,
                                    style: ds.title.copyWith(
                                      color: Colors.white,
                                      shadows: const [
                                        Shadow(
                                          color: Color(0x66000000),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onLongPress: () => Clipboard.setData(
                                    ClipboardData(text: userId),
                                  ),
                                  child: Text(
                                    ' @$userId',
                                    style: ds.title.copyWith(
                                      color: Colors.white,
                                      shadows: const [
                                        Shadow(
                                          color: Color(0x66000000),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(top: 4, left: 4, child: _menu(context)),
                      Positioned(top: 4, right: 4, child: _trailing(context)),
                    ],
                  ),
          ),
          if (!fixed)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: ds.surfaceCard,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '菜单',
      icon: const Icon(Icons.menu, color: Colors.white),
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
    );
  }

  Widget _trailing(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BgmHeaderAction(
          tooltip: '照片墙',
          icon: const Icon(
            Icons.image_aspect_ratio,
            color: Colors.white,
            size: 21,
          ),
          onPressed: () => context.push('/user/$userId/milestone'),
        ),
        BgmHeaderAction(
          icon: Icon(BgmIcons.setting, color: Colors.white, size: 20),
          tooltip: '设置',
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }
}

class _MyToolBar extends StatelessWidget {
  final String order;
  final String tag;
  final List<UserCollectionTag> tags;
  final bool searchOpen;
  final int page;
  final int pageTotal;
  final ValueChanged<String> onOrder;
  final ValueChanged<String> onTag;
  final ValueChanged<int> onPage;
  final VoidCallback onToggleSearch;
  final VoidCallback onToggleLayout;

  const _MyToolBar({
    required this.order,
    required this.tag,
    required this.tags,
    required this.searchOpen,
    required this.page,
    required this.pageTotal,
    required this.onOrder,
    required this.onTag,
    required this.onPage,
    required this.onToggleSearch,
    required this.onToggleLayout,
  });

  @override
  Widget build(BuildContext context) {
    final store = SettingsStore.instance;
    final orderLabel = kMyOrderOptions
        .firstWhere((e) => e.$1 == order, orElse: () => ('', '收藏时间'))
        .$2;
    final tagItems = userCollectionTagMenuItems(tags);
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
          PopupMenuButton<String>(
            tooltip: '标签',
            onSelected: onTag,
            itemBuilder: (_) => [
              for (final item in tagItems)
                PopupMenuItem(value: item, child: Text(item)),
            ],
            child: _ChipLabel(
              text: userCollectionTagLabel(tag),
              icon: Icons.bookmark_border,
            ),
          ),
          if (store.userPagination)
            PopupMenuButton<int>(
              tooltip: '分页',
              onSelected: onPage,
              itemBuilder: (_) => [
                for (var i = 1; i <= pageTotal; i++)
                  PopupMenuItem(value: i, child: Text('$i')),
              ],
              child: _ChipLabel(text: '$page', icon: Icons.notes),
            ),
          const Spacer(),
          BgmHeaderAction(
            tooltip: searchOpen ? '关闭搜索' : '搜索',
            icon: Icon(searchOpen ? Icons.close : Icons.search),
            onPressed: onToggleSearch,
          ),

          BgmHeaderMore(
            items: myCollectionMoreItems(
              list: store.userList,
              pagination: store.userPagination,
              showYear: store.userShowYear,
            ),
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
          ? () => showBgmSheet<void>(
              context: context,
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
          if (SettingsStore.instance.userShowYear)
            Text(
              formatSubjectAirDate(
                item.subject.airDate.isNotEmpty
                    ? item.subject.airDate
                    : item.tip,
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
  final int page;
  final int pageTotal;
  final ValueChanged<int>? onPage;
  final VoidCallback onMore;

  const _MyListFooter({
    required this.loaded,
    required this.total,
    required this.showMore,
    this.page = 1,
    this.pageTotal = 1,
    this.onPage,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    if (showMore) {
      return LoadMoreLink(onTap: onMore);
    }
    if (onPage != null && pageTotal > 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            BgmTextAction(
              '上一页',
              onPressed: page > 1 ? () => onPage!(page - 1) : null,
            ),
            Expanded(
              child: Text(
                '$page / $pageTotal',
                textAlign: TextAlign.center,
                style: context.ds.caption,
              ),
            ),
            BgmTextAction(
              '下一页',
              onPressed: page < pageTotal ? () => onPage!(page + 1) : null,
            ),
          ],
        ),
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
      constraints: const BoxConstraints(minWidth: 32, minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ds.surfaceCard.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: ds.textPrimary),
          const SizedBox(width: 4),
          Text(
            text,
            style: ds.caption.copyWith(
              color: ds.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
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

                      if (item.tip.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.tip,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ds.tiny.copyWith(color: ds.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (item.rate > 0) '★ ${item.rate}',
                          if (score > 0) score.toStringAsFixed(1),
                          if (item.updatedAt.isNotEmpty) item.updatedAt,
                          if (item.tags.isNotEmpty) item.tags.take(4).join(' '),
                        ].join(' · '),
                        style: ds.tiny.copyWith(color: ds.textHint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (!commentsFull && commentText != null) commentText,
                    ],
                  ),
                ),
                if (showManage)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showBgmSheet<void>(
                      context: context,
                      builder: (_) =>
                          CollectionSheet(subjectId: item.subject.id),
                    ),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(Icons.star_outline, size: 20),
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
          const Mesume(size: 80),
          const SizedBox(height: 12),
          Text(
            '登录后同步你的收藏与进度',
            style: context.ds.caption.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 16),
          BgmButton(
            '登录',
            expand: false,
            onPressed: () => context.push('/login'),
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
      appBar: BgmAppBar(title: '我的${SubjectType.pluralText(type)}'),
      body: async.when(
        loading: () => const Loading(),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return BgmTextRow(
              leading: Cover(
                url: item.subject.images.common,
                width: 44,
                height: 58,
                radius: 4,
              ),
              title: item.subject.displayName,
              subtitle:
                  '${SubjectType.statusText(item.type, item.subject.type)} · 第${item.epStatus}话',
              onTap: () => context.push('/subject/${item.subject.id}'),
            );
          },
        ),
      ),
    );
  }
}
