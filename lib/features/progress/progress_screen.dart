import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';
import '../../core/utils/format.dart';
import '../../design_system/design_system.dart';
import '../../shared/models/collection.dart';
import '../../shared/models/ep.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/tab_title.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/menu_mark.dart';
import '../../shared/widgets/mesume.dart';

import 'progress_empty.dart';
import 'progress_filter.dart';

import '../rakuen/rakuen_providers.dart';
import '../discovery/discovery_screen.dart';

import '../discovery/calendar_screen.dart';
import '../subject/collection_sheet.dart';
import '../subject/ep_menu.dart';
import '../subject/subject_providers.dart';

import '../user/origin_setting_screen.dart';
import '../user/pm_screen.dart';
import '../user/user_models.dart';

import '../user/origin_utils.dart';

/// 首页 Tab 类型 (与原项目 TABS_ITEM 一致)
const kProgressTabs = [
  ('全部', 'all'),
  ('动画', 'anime'),
  ('书籍', 'book'),
  ('三次元', 'real'),
  ('游戏', 'game'),
];

/// 收藏列表数据
class ProgressData {
  final List<CollectionItem> items;
  final int page;
  final bool hasMore;
  final Set<int> fetchingIds;
  final bool prefetching;
  final int prefetchCurrent;
  final int prefetchTotal;

  const ProgressData({
    this.items = const [],
    this.page = 1,
    this.hasMore = true,
    this.fetchingIds = const {},
    this.prefetching = false,
    this.prefetchCurrent = 0,
    this.prefetchTotal = 0,
  });

  ProgressData copyWith({
    List<CollectionItem>? items,
    int? page,
    bool? hasMore,
    Set<int>? fetchingIds,
    bool? prefetching,
    int? prefetchCurrent,
    int? prefetchTotal,
  }) {
    return ProgressData(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      fetchingIds: fetchingIds ?? this.fetchingIds,
      prefetching: prefetching ?? this.prefetching,
      prefetchCurrent: prefetchCurrent ?? this.prefetchCurrent,
      prefetchTotal: prefetchTotal ?? this.prefetchTotal,
    );
  }
}

final progressProvider =
    AsyncNotifierProvider.family<ProgressNotifier, ProgressData, String>(
      ProgressNotifier.new,
    );

class ProgressNotifier extends FamilyAsyncNotifier<ProgressData, String> {
  @override
  Future<ProgressData> build(String type) async {
    ref.watch(settingsStoreProvider.select((s) => s.showGame));
    final data = await _fetch(1, type);
    unawaited(_prefetch(data));
    return data.copyWith(prefetching: true, prefetchCurrent: 0);
  }

  Future<ProgressData> _fetch(int page, String type) async {
    final client = ref.read(apiClientProvider);
    final me = ref.read(currentUserProvider);
    if (me == null) return const ProgressData(items: [], hasMore: false);
    final userId = me.username.isEmpty ? '${me.id}' : me.username;
    final subjectType = type == 'all' ? 'anime' : type;
    final data = await client.get(
      apiV0UsersCollections(userId, subjectType, 100, (page - 1) * 100, '3'),
    );
    final uc = UserCollection.fromJson(data as Map<String, dynamic>);

    if (type == 'all') {
      final all = [...uc.data];
      final extra = ref.read(settingsStoreProvider).showGame
          ? const ['book', 'real', 'game']
          : const ['book', 'real'];
      for (final t in extra) {
        try {
          final d2 = await client.get(
            apiV0UsersCollections(userId, t, 100, (page - 1) * 100, '3'),
          );
          all.addAll(UserCollection.fromJson(d2 as Map<String, dynamic>).data);
        } catch (_) {}
      }
      return ProgressData(items: all, page: page, hasMore: false);
    }

    return ProgressData(
      items: uc.data,
      page: page,
      hasMore: uc.data.length >= 100,
    );
  }

  Future<void> _prefetch(ProgressData seed) async {
    final ids = [
      for (final item in seed.items)
        if (item.subject.type != 'book' && item.subject.type != 'game')
          item.subject.id,
    ].take(24).toList();
    final now = state.valueOrNull ?? seed;
    state = AsyncData(
      now.copyWith(
        prefetching: ids.isNotEmpty,
        prefetchCurrent: 0,
        prefetchTotal: ids.length,
      ),
    );
    if (ids.isEmpty) return;
    var cursor = 0;
    var done = 0;
    Future<void> worker() async {
      while (cursor < ids.length) {
        final id = ids[cursor++];
        try {
          await ref.read(epListProvider(id).future);
        } catch (_) {}
        try {
          await ref.read(epStatusProvider(id).future);
        } catch (_) {}
        done += 1;
        final latest = state.valueOrNull;
        if (latest != null) {
          state = AsyncData(latest.copyWith(prefetchCurrent: done));
        }
      }
    }

    try {
      await Future.wait([worker(), worker()]);
    } finally {
      final latest = state.valueOrNull;
      if (latest != null) {
        state = AsyncData(
          latest.copyWith(prefetching: false, prefetchCurrent: ids.length),
        );
      }
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(current.page + 1, arg);
      final merged = current.copyWith(
        items: [...current.items, ...next.items],
        page: next.page,
        hasMore: next.hasMore,
        prefetching: true,
      );
      state = AsyncData(merged);
      unawaited(_prefetch(next));
    } catch (_) {}
  }

  /// 看过下一话
  Future<bool> updateProgress(CollectionItem item) async {
    return setWatched(item, item.epStatus + 1);
  }

  /// 批量设置进度 (书籍可同时改卷)
  Future<bool> setWatched(
    CollectionItem item,
    int watchedEps, {
    int? watchedVols,
  }) async {
    final client = ref.read(apiClientProvider);
    final subject = item.subject;
    if (subject.id <= 0) return false;
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        current.copyWith(fetchingIds: {...current.fetchingIds, subject.id}),
      );
    }
    try {
      await client.post(
        apiSubjectUpdateWatched(subject.id),
        data: {'watched_eps': watchedEps, 'watched_vols': ?watchedVols},
      );
      ref.invalidate(progressProvider(arg));
      return true;
    } catch (_) {
      final now = state.valueOrNull;
      if (now != null) {
        state = AsyncData(
          now.copyWith(fetchingIds: {...now.fetchingIds}..remove(subject.id)),
        );
      }
      return false;
    }
  }

  /// 变更收藏状态
  Future<bool> changeStatus(CollectionItem item, int status) async {
    final client = ref.read(apiClientProvider);
    final subject = item.subject;
    if (subject.id <= 0) return false;
    try {
      await client.post(
        apiCollectionAction(subject.id, 'update'),
        data: {'type': status},
      );
      ref.invalidate(progressProvider(arg));
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// 首页 (Tab 3): 收藏进度管理
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _tab = 0;

  List<(String, String)> get _tabs {
    final settings = ref.watch(settingsStoreProvider);
    final visible = settings.homeTabs.toSet();
    final tabs = [
      for (final t in kProgressTabs)
        if (t.$2 == 'game' ? settings.showGame : visible.contains(t.$2)) t,
    ];
    return tabs.isEmpty ? const [('全部', 'all')] : tabs;
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = ref.watch(isLoggedInProvider);
    final unread = ref.watch(notifyCountProvider).valueOrNull ?? 0;
    final hasPm = hasNewPm(ref.watch(pmInboxProvider).valueOrNull ?? const []);

    final store = ref.watch(settingsStoreProvider);
    final tabs = _tabs;
    if (_tab >= tabs.length) _tab = 0;
    final searchType = tabs.length >= 2 && tabs[_tab].$2 != 'all'
        ? tabs[_tab].$1
        : '';
    if (!isLogin) {
      return const Scaffold(body: _ProgressLoginGate());
    }
    return Scaffold(
      appBar: LogoHeader(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BgmHeaderAction(
              tooltip: '电波提醒',
              onPressed: () => context.push(
                hasPm ? '/rakuen/notify?type=pm' : '/rakuen/notify',
              ),
              icon: BgmNotifyMark(unread: unread > 0 || hasPm),
            ),
            ..._homeHeaderActions(context, store.homeTopExtraCustom, searchType),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._homeHeaderActions(context, store.homeTopLeftCustom, searchType),
            ..._homeHeaderActions(context, store.homeTopRightCustom, searchType),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (tabs.length >= 2)
                BgmTabStrip(
                  index: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                  tabs: [for (final t in tabs) Text(t.$1)],
                ),
              Expanded(child: _ProgressList(type: tabs[_tab].$2)),
            ],
          ),
          const _ProgressTips(),
        ],
      ),
    );
  }
}

List<Widget> _homeHeaderActions(
  BuildContext context,
  String key, [
  String searchType = '',
]) {
  if (key.isEmpty) return const [];
  final item = discoveryMenuByKey(key);
  if (item == null || item.key == 'Open' || item.key == 'Netabare') {
    return const [];
  }
  return [
    BgmHeaderAction(
      tooltip: item.name,
      icon: BgmMenuMark(
        icon: item.icon,
        badge: item.badge,
        text: item.text,
        wrap: false,
        size: (item.text != null ? 16 : 24).toDouble(),
      ),
      onPressed: () {
        if (item.key == 'Link') {
          showClipboardModal(context);
          return;
        }
        if (item.key == 'Search') {
          final q = searchType.isEmpty
              ? '/search'
              : '/search?type=${Uri.encodeQueryComponent(searchType)}';
          context.push(q);
          return;
        }
        final route = item.route;
        if (route == null || route.isEmpty) return;
        context.push(route);
      },
    ),
  ];
}

class _ProgressList extends ConsumerStatefulWidget {
  final String type;

  const _ProgressList({required this.type});

  @override
  ConsumerState<_ProgressList> createState() => _ProgressListState();
}

class _ProgressListState extends ConsumerState<_ProgressList> {
  final _scrollController = ScrollController();
  final _filterController = TextEditingController();
  CollectionItem? _selected;
  String _filter = '';
  final _expandedIds = <int>{};

  void _toggleExpand(int id) {
    setState(() {
      if (!_expandedIds.remove(id)) _expandedIds.add(id);
    });
  }

  void _expandAll(Iterable<CollectionItem> items) {
    setState(() {
      for (final item in items) {
        final type = item.subject.type;
        if (type != 'book' && type != 'game') {
          _expandedIds.add(item.subject.id);
        }
      }
    });
  }

  void _collapseAll() {
    setState(() => _expandedIds.clear());
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(progressProvider(widget.type).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(progressProvider(widget.type));
    return async.when(
      loading: () => const Loading(),
      error: (e, _) => BgmRetry(
        onRetry: () => ref.invalidate(progressProvider(widget.type)),
      ),

      data: (data) {
        final store = ref.watch(settingsStoreProvider);
        final q = store.homeFilter ? _filter.trim() : '';
        final pinned = store.progressPinnedIds.toSet();
        var items = q.isEmpty
            ? [...data.items]
            : data.items.where((e) {
                final names = [
                  e.subject.displayName,
                  e.subject.name,
                  e.subject.nameCn,
                ];
                return names.any((name) => pinYinFilterValue(name, q) != null);
              }).toList();

        items.sort((a, b) {
          final ap = pinned.contains(a.subject.id) ? 0 : 1;
          final bp = pinned.contains(b.subject.id) ? 0 : 1;
          final pin = ap.compareTo(bp);
          if (pin != 0) return pin;
          if (store.homeSorting != 'web') {
            final aw = homeSortWeight(
              DateTime.tryParse(a.subject.airDate) ?? DateTime(1970),
              weekday: a.subject.airWeekday,
              mode: store.homeSorting,
            );
            final bw = homeSortWeight(
              DateTime.tryParse(b.subject.airDate) ?? DateTime(1970),
              weekday: b.subject.airWeekday,
              mode: store.homeSorting,
            );
            final byAir = aw.compareTo(bw);
            if (byAir != 0) return byAir;
          }
          if (!store.homeSortSink) return 0;
          final as = _unwatchedAiredCount(ref, a) == 0 && a.epStatus > 0
              ? 1
              : 0;
          final bs = _unwatchedAiredCount(ref, b) == 0 && b.epStatus > 0
              ? 1
              : 0;
          return as.compareTo(bs);
        });

        final filterBar = store.homeFilter
            ? ProgressFilterBar(
                controller: _filterController,
                length: items.length,
                fetching: data.prefetching,
                onChanged: (v) => setState(() => _filter = v.trim()),
              )
            : const SizedBox.shrink();
        if (data.items.isEmpty || items.isEmpty) {
          return Column(
            children: [
              filterBar,
              Expanded(
                child: Center(
                  child: ProgressEmpty(
                    type: widget.type,
                    filter: q,
                    length: items.length,
                  ),
                ),
              ),
            ],
          );
        }

        if (store.progressGrid) {
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(progressProvider(widget.type)),
            child: Column(
              children: [
                filterBar,
                _ProgressGridPanel(
                  item: _selected,
                  type: widget.type,
                  pinned:
                      _selected != null &&
                      pinned.contains(_selected!.subject.id),
                  onPin: _selected == null
                      ? null
                      : () => store.toggleProgressPinned(_selected!.subject.id),
                  onExpandAll: () => _expandAll(items),
                  onCollapseAll: _collapseAll,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = homeGridNumColumns(
                            MediaQuery.sizeOf(context),
                          );
                          final square = store.homeGridCoverLayout == 'square';
                          final titled = store.homeGridTitle;

                          return GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(10),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  childAspectRatio: square
                                      ? (titled ? 0.62 : 0.82)
                                      : (titled ? 0.50 : 0.60),
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return _ProgressGridCard(
                                item: item,
                                selected:
                                    _selected?.subject.id == item.subject.id,
                                pinned: pinned.contains(item.subject.id),
                                onPin: () =>
                                    store.toggleProgressPinned(item.subject.id),
                                onSelect: () =>
                                    setState(() => _selected = item),
                              );
                            },
                          );
                        },
                      ),
                      if (Theme.of(context).brightness == Brightness.dark)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: 24,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    context.ds.surfaceBase,
                                    context.ds.surfaceBase.withValues(
                                      alpha: 0.8,
                                    ),
                                    context.ds.surfaceBase.withValues(
                                      alpha: 0.24,
                                    ),
                                    context.ds.surfaceBase.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(progressProvider(widget.type)),
          child: Column(
            children: [
              filterBar,
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      return ProgressEmpty(
                        type: widget.type,
                        filter: q,
                        length: items.length,
                      );
                    }
                    final item = items[index];
                    return _ProgressItemView(
                      item: item,
                      type: widget.type,
                      pinned: pinned.contains(item.subject.id),
                      onPin: () => store.toggleProgressPinned(item.subject.id),
                      filter: q,
                      expanded: _expandedIds.contains(item.subject.id),
                      onToggleExpand: () => _toggleExpand(item.subject.id),
                      onExpandAll: () => _expandAll(items),
                      onCollapseAll: _collapseAll,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressItemView extends ConsumerStatefulWidget {
  final CollectionItem item;
  final String type;
  final bool pinned;
  final VoidCallback onPin;
  final String filter;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onExpandAll;
  final VoidCallback onCollapseAll;

  const _ProgressItemView({
    required this.item,
    required this.type,
    required this.pinned,
    required this.onPin,
    this.filter = '',
    required this.expanded,
    required this.onToggleExpand,
    required this.onExpandAll,
    required this.onCollapseAll,
  });

  @override
  ConsumerState<_ProgressItemView> createState() => _ProgressItemViewState();
}

class _ProgressItemViewState extends ConsumerState<_ProgressItemView> {
  CollectionItem get item => widget.item;
  String get type => widget.type;

  @override
  Widget build(BuildContext context) {
    final subject = item.subject;
    final isBook = subject.type == 'book';
    final isGame = subject.type == 'game';
    final store = ref.watch(settingsStoreProvider);
    final compact = store.homeListCompact;
    final fetching =
        ref
            .watch(progressProvider(type))
            .valueOrNull
            ?.fetchingIds
            .contains(subject.id) ??
        false;
    final loadingEps =
        !isBook && !isGame && ref.watch(epListProvider(subject.id)).isLoading;
    final bar = _onAirBar(ref, item);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 4 : 8,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              InkWell(
                onTap: () => context.push('/subject/${subject.id}'),
                onLongPress: () => _editProgress(context, ref),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) {
                        final cover = homeListCoverSize(
                          MediaQuery.sizeOf(context),
                          compact: compact,
                        );
                        return Cover(
                          url: subject.images.common,
                          width: cover.width,
                          height: cover.height,
                          radius: 4,
                          type: subject.type,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text.rich(
                                  _highlightTitle(
                                    subject.displayName,
                                    widget.filter,
                                    fontSize: homeTitleFontSize(
                                      subject.displayName,
                                    ),
                                  ),
                                  maxLines:
                                      compact || store.homeAnimeInfoInline == 2
                                      ? 2
                                      : 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (fetching || loadingEps)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: BgmSpinner(
                                    size: 16,
                                    color: context.ds.textSecondary,
                                  ),
                                ),
                              if (!isBook && !isGame)
                                _OnAirLabel(
                                  weekday: subject.airWeekday,
                                  subjectId: subject.id,
                                  current: bar.aired,
                                  total: bar.total,
                                ),
                            ],
                          ),
                          if (!compact)
                            _ProgressMetaLine(item: item, store: store),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: compact ? 32 : 40,
                            child: Row(
                              children: [
                                if (isBook)
                                  Text(
                                    'Chap. ${item.epStatus}${subject.eps > 0 ? ' / ${subject.eps}' : ''}   Vol. ${item.volStatus}',
                                    style: context.ds.caption,
                                  )
                                else if (!isGame)
                                  InkWell(
                                    onTap: widget.onToggleExpand,
                                    child: Text(
                                      homeCountText(
                                        current: item.epStatus,
                                        total: subject.eps,
                                        style: store.homeCountView,
                                      ),
                                      style: context.ds.caption.copyWith(
                                        color: context.ds.accent,
                                      ),
                                    ),
                                  ),

                                const Spacer(),
                                if (store.homeOrigin != 'hide')
                                  _OriginButton(
                                    item: item,
                                    onPin: widget.onPin,
                                    pinned: widget.pinned,
                                    showOrigins: store.homeOrigin == 'all',
                                    onExpandAll: widget.onExpandAll,
                                    onCollapseAll: widget.onCollapseAll,
                                  ),
                                if (isBook) ...[
                                  _IconAction(
                                    tooltip: 'Chap +1',
                                    icon: Icons.check_circle_outline,
                                    onTap: () =>
                                        _bump(context, ref, item.epStatus + 1),
                                  ),
                                  _IconAction(
                                    tooltip: 'Vol +1',
                                    icon: Icons.menu_book_outlined,
                                    onTap: () => _bump(
                                      context,
                                      ref,
                                      item.epStatus,
                                      vols: item.volStatus + 1,
                                    ),
                                  ),
                                ] else if (!isGame)
                                  _NextEpAction(
                                    item: item,
                                    type: type,
                                    onBump: () =>
                                        _bump(context, ref, item.epStatus + 1),
                                  ),
                                _IconAction(
                                  tooltip: '收藏管理',
                                  icon: Icons.star_outline,
                                  onTap: () =>
                                      showBgmSheet<void>(
                                        context: context,
                                        builder: (_) => CollectionSheet(
                                          subjectId: subject.id,
                                        ),
                                      ).then((_) {
                                        ref.invalidate(progressProvider(type));
                                      }),
                                ),
                              ],
                            ),
                          ),
                          if (isGame)
                            Padding(
                              padding: EdgeInsets.only(top: compact ? 4 : 8),
                              child: Text(
                                item.updatedAt.isEmpty
                                    ? '在玩'
                                    : '${friendlyTime(item.updatedAt)} 在玩',
                                style: context.ds.caption,
                              ),
                            )
                          else if (!isBook)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: _OnAirProgress(
                                watched: item.epStatus,
                                aired: bar.aired,
                                total: bar.total,
                                compact: compact,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isBook && !isGame && store.homeAnimeInfoInline == 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 9, 0, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SeasonLeftInfo(
                          item: item,
                          isAnime: subject.type == 'anime',
                        ),
                      ),
                      _NextAirInfo(subjectId: subject.id),
                    ],
                  ),
                ),

              if (widget.expanded && !isBook && !isGame)
                _ProgressEpGrid(
                  subjectId: subject.id,
                  type: type,
                  compact: store.progressGrid,
                ),
            ],
          ),
          if (widget.pinned)
            Positioned(
              top: 0,
              right: 0,
              child: _ProgressPinCorner(onUnpin: widget.onPin),
            ),
        ],
      ),
    );
  }

  Future<void> _bump(
    BuildContext context,
    WidgetRef ref,
    int eps, {
    int? vols,
  }) async {
    final ok = await ref
        .read(progressProvider(type).notifier)
        .setWatched(item, eps, watchedVols: vols);
    if (context.mounted && !ok) {
      showBgmToast(context, '更新进度失败');
    }
  }

  Future<void> _editProgress(BuildContext context, WidgetRef ref) async {
    final subject = item.subject;
    final epsCtrl = TextEditingController(text: '${item.epStatus}');
    final volCtrl = TextEditingController(text: '${item.volStatus}');
    final isBook = subject.type == 'book';
    final saved = await showBgmDialog<bool>(
      context: context,
      title: '设置观看进度',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BgmField(
            controller: epsCtrl,
            keyboardType: TextInputType.number,
            hintText: isBook
                ? 'Chap.${subject.eps > 0 ? ' / ${subject.eps}' : ''}'
                : '看到第几话${subject.eps > 0 ? ' / ${subject.eps}' : ''}',
          ),
          if (isBook) ...[
            const SizedBox(height: 8),
            BgmField(
              controller: volCtrl,
              keyboardType: TextInputType.number,
              hintText: 'Vol.',
            ),
          ],
        ],
      ),
      actions: (ctx) => [
        BgmButton(
          '取消',
          type: BgmButtonType.plain,
          expand: false,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        BgmButton(
          '保存',
          expand: false,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    );
    if (saved != true) {
      epsCtrl.dispose();
      volCtrl.dispose();
      return;
    }
    final eps = int.tryParse(epsCtrl.text.trim()) ?? item.epStatus;
    final vols = isBook ? int.tryParse(volCtrl.text.trim()) : null;
    epsCtrl.dispose();
    volCtrl.dispose();
    if (!context.mounted) return;
    await _bump(context, ref, eps, vols: vols);
  }
}

class _OnAirLabel extends ConsumerWidget {
  final int weekday;
  final int subjectId;
  final int current;
  final int total;

  const _OnAirLabel({
    required this.weekday,
    required this.subjectId,
    this.current = 0,
    this.total = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(settingsStoreProvider);
    final custom = store.customOnAirOf(subjectId);
    var wd = weekday;
    var clock = '';
    if (custom != null) {
      final parts = custom.split('|');
      wd = int.tryParse(parts.first) ?? weekday;
      if (parts.length > 1 && parts[1].length == 4) {
        clock = ' ${parts[1].substring(0, 2)}:${parts[1].substring(2)}';
      }
    } else {
      if (weekday <= 0) return const SizedBox.shrink();
      final time = ref.watch(onAirTimeProvider).valueOrNull?[subjectId];
      clock = (time != null && time != '99:99') ? ' $time' : '';
    }
    // 防止完结番因放送数据滞后一直显示放送中 (原项目 OnAir current>=8 && current==total)
    if (!store.homeOnAir &&
        custom == null &&
        current >= 8 &&
        total >= 8 &&
        current == total) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now();
    final today = now.weekday % 7;
    final target = wd % 7;
    final text = target == today
        ? '今天$clock'
        : target == (today + 1) % 7
        ? '明天$clock'
        : (store.homeOnAir || custom != null)
        ? '${kWeekdayCn[target]}$clock'
        : '';
    if (text.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onLongPress: () => _edit(context, ref, wd, clock.trim()),
      child: Text(
        text,
        style: context.ds.tiny.copyWith(
          color: target == today ? context.ds.success : null,
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    int weekday,
    String clock,
  ) async {
    var wd = weekday <= 0 ? DateTime.now().weekday % 7 : weekday % 7;
    var hour = '20';
    var minute = '00';
    if (clock.contains(':')) {
      final parts = clock.split(':');
      hour = parts[0].padLeft(2, '0');
      minute = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
    }
    final saved = await showBgmDialog<bool>(
      context: context,
      title: '自定义放送',
      content: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: BgmSelect<int>(
                value: wd,
                items: [for (var i = 0; i < 7; i++) (i, kWeekdayCn[i])],
                onChanged: (v) => setLocal(() => wd = v),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                BgmSelect<String>(
                  value: hour,
                  items: [
                    for (var h = 0; h < 24; h++)
                      (
                        h.toString().padLeft(2, '0'),
                        h.toString().padLeft(2, '0'),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => hour = v),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(':'),
                ),
                BgmSelect<String>(
                  value: minute,
                  items: const [
                    ('00', '00'),
                    ('15', '15'),
                    ('30', '30'),
                    ('45', '45'),
                  ],
                  onChanged: (v) => setLocal(() => minute = v),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: (ctx) => [
        BgmButton(
          '恢复默认',
          type: BgmButtonType.plain,
          expand: false,
          onPressed: () {
            ref.read(settingsStoreProvider).clearCustomOnAir(subjectId);
            Navigator.pop(ctx, false);
          },
        ),
        BgmButton(
          '保存',
          expand: false,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    );
    if (saved == true) {
      await ref
          .read(settingsStoreProvider)
          .setCustomOnAir(subjectId, wd, '$hour$minute');
    }
  }
}

class _ProgressEpGrid extends ConsumerWidget {
  final int subjectId;
  final String type;
  final bool compact;

  const _ProgressEpGrid({
    required this.subjectId,
    required this.type,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epsAsync = ref.watch(epListProvider(subjectId));
    final status = ref.watch(epStatusProvider(subjectId)).valueOrNull;
    return epsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: BgmSpinner()),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('章节加载失败'),
      ),
      data: (list) {
        final raw = list.eps;
        if (raw.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('暂无章节'),
          );
        }
        final eps = visibleHomeEps(
          raw,
          isWatched: (ep) => status?.isWatched(ep.id) ?? false,
          startAtLast: SettingsStore.instance.homeEpStartAtLast,
        );
        final comments = [for (final ep in raw) ep.comment];
        final min = comments.isEmpty
            ? 0
            : comments.reduce((a, b) => a < b ? a : b);
        final max = comments.isEmpty
            ? 1
            : comments.reduce((a, b) => a > b ? a : b);

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final count = eps.length;
              var chipWidth = 36.0;
              if (compact &&
                  SettingsStore.instance.homeGridEpAutoAdjust &&
                  count > 0 &&
                  count <= 18) {
                final available = constraints.maxWidth;
                chipWidth = ((available - 6 * (6 - 1)) / 6).clamp(36.0, 64.0);
              }
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final ep in eps)
                    _EpChip(
                      ep: ep,
                      watched: status?.isWatched(ep.id) ?? false,
                      heatMin: min,
                      heatMax: max,
                      width: chipWidth,
                      onTap: () async {
                        try {
                          await setEpStatusAction(
                            ref,
                            ep.id,
                            (status?.isWatched(ep.id) ?? false)
                                ? 'remove'
                                : 'watched',
                          );

                          ref.invalidate(epStatusProvider(subjectId));
                          ref.invalidate(progressProvider(type));
                        } catch (_) {
                          if (context.mounted) {
                            showBgmToast(context, '更新章节失败');
                          }
                        }
                      },
                      onLongPress: () => showEpActionMenu(
                        context,
                        ref,
                        subjectId: subjectId,
                        ep: ep,
                        watched: status?.isWatched(ep.id) ?? false,
                        onChanged: () => ref.invalidate(progressProvider(type)),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _EpChip extends StatelessWidget {
  final Ep ep;
  final bool watched;
  final int heatMin;
  final int heatMax;
  final double width;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _EpChip({
    required this.ep,
    required this.watched,
    required this.heatMin,
    required this.heatMax,
    this.width = 36,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final heat = SettingsStore.instance.heatMap
        ? heatMapOpacity(ep.comment, min: heatMin, max: heatMax)
        : 0.0;
    final kind = epAirKind(ep.airdate, watched: watched);
    final bg = switch (kind) {
      'watched' => context.ds.accentSoft,
      'today' => context.ds.success.withValues(alpha: 0.16),
      _ => context.ds.surfaceCard,
    };
    final border = switch (kind) {
      'watched' => context.ds.accent,
      'today' => context.ds.success,
      'air' => context.ds.textSecondary.withValues(alpha: 0.45),
      _ => context.ds.border,
    };
    final fg = switch (kind) {
      'watched' => context.ds.accent,
      'today' => context.ds.success,
      'na' => context.ds.textHint,
      _ => context.ds.textPrimary,
    };
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            Container(
              width: width,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: border),
              ),
              child: Text(
                '${ep.sort}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),

            if (heat > 0)
              Container(
                margin: const EdgeInsets.only(top: 2),
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA000).withValues(alpha: heat),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OriginButton extends ConsumerWidget {
  final CollectionItem item;
  final bool pinned;
  final VoidCallback onPin;
  final bool showOrigins;
  final VoidCallback? onExpandAll;
  final VoidCallback? onCollapseAll;

  const _OriginButton({
    required this.item,
    required this.pinned,
    required this.onPin,
    this.showOrigins = true,
    this.onExpandAll,
    this.onCollapseAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origins = showOrigins
        ? originsForType(
            ref.watch(originConfigProvider).valueOrNull ?? const {},
            item.subjectType.isEmpty ? item.subject.type : item.subjectType,
          )
        : const <OriginItem>[];
    final type = item.subject.type;
    final isAnime = type == 'anime' || type == 'real';
    final eps =
        ref.watch(epListProvider(item.subject.id)).valueOrNull?.eps ??
        const <Ep>[];
    final status = ref.watch(epStatusProvider(item.subject.id)).valueOrNull;
    final hasUnaired =
        isAnime &&
        eps.any(
          (ep) => canAddEpCalendar(
            type: ep.type,
            airdate: ep.airdate,
            watched: status?.isWatched(ep.id) ?? false,
          ),
        );
    return PopupMenuButton<String>(
      tooltip: showOrigins ? '源头' : '更多',
      padding: EdgeInsets.zero,
      iconSize: 20,
      splashRadius: 18,
      icon: Icon(
        origins.length > 1 ? Icons.cast : Icons.menu,
        size: origins.length > 1 ? 17 : 21,
      ),
      onSelected: (value) async {
        switch (value) {
          case 'pin':
            onPin();
            return;
          case 'expandAll':
            onExpandAll?.call();
            return;
          case 'collapseAll':
            onCollapseAll?.call();
            return;
          case 'remind':
            await _addUnairedReminders(context, ref, item);
            return;
          case 'ics':
            final custom = SettingsStore.instance.customOnAirOf(
              item.subject.id,
            );
            final clock = custom != null && custom.contains('|')
                ? custom.split('|').last
                : '2000';
            await shareSubjectIcs(
              subjectId: item.subject.id,
              title: item.subject.displayName,
              clock: clock,
              eps: [
                for (final ep in eps)
                  if (ep.type == 0)
                    (
                      id: ep.id,
                      sort: ep.sort,
                      name: ep.displayName,
                      airdate: ep.airdate,
                    ),
              ],
            );
            return;
        }
        final origin = origins.cast<OriginItem?>().firstWhere(
          (e) => e?.uuid == value,
          orElse: () => null,
        );
        if (origin == null) return;
        final year = RegExp(
          r'(\d{4})',
        ).firstMatch(item.subject.airDate)?.group(1);
        final url = replaceOriginUrl(
          origin.url,
          cn: item.subject.displayName,
          jp: item.subject.name.isEmpty
              ? item.subject.displayName
              : item.subject.name,
          id: item.subject.id,
          year: year ?? '',
        );
        if (url.isEmpty) return;
        if (context.mounted && SettingsStore.instance.openInfo) {
          showBgmToast(context, '已复制地址，即将跳转');
        }
        await openExternalUrl(url);
      },
      itemBuilder: (_) => [
        if (showOrigins)
          for (final o in origins)
            PopupMenuItem(value: o.uuid, child: Text(o.name)),
        PopupMenuItem(value: 'pin', child: Text(pinned ? '取消置顶' : '置顶')),
        if (isAnime) ...[
          const PopupMenuItem(value: 'expandAll', child: Text('全部展开')),
          const PopupMenuItem(value: 'collapseAll', child: Text('全部收起')),
          if (hasUnaired)
            const PopupMenuItem(value: 'remind', child: Text('一键添加提醒')),
          if (SettingsStore.instance.exportICS && eps.isNotEmpty)
            const PopupMenuItem(value: 'ics', child: Text('导出放送日程ICS')),
        ],
      ],
    );
  }
}

class _ProgressPinCorner extends StatelessWidget {
  final VoidCallback onUnpin;

  const _ProgressPinCorner({required this.onUnpin});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final ok = await showBgmConfirm(context, title: '确定取消置顶?');
        if (ok) onUnpin();
      },
      child: SizedBox(
        width: 32,
        height: 32,
        child: Align(
          alignment: Alignment.topRight,
          child: Opacity(
            opacity: 0.8,
            child: CustomPaint(
              size: const Size(16, 16),
              painter: _PinCornerPainter(color: context.ds.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinCornerPainter extends CustomPainter {
  final Color color;

  const _PinCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinCornerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _IconAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final String? label;

  const _IconAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.label,
  });
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 34,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: label == null ? 20 : 19,
                  color: context.ds.textSecondary,
                ),
                if (label != null) ...[
                  const SizedBox(width: 2),
                  Text(label!, style: context.ds.caption),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NextEpAction extends ConsumerWidget {
  final CollectionItem item;
  final String type;
  final VoidCallback onBump;

  const _NextEpAction({
    required this.item,
    required this.type,
    required this.onBump,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eps = ref.watch(epListProvider(item.subject.id)).valueOrNull?.eps;
    var next = item.epStatus + 1;
    if (eps != null) {
      for (final ep in eps) {
        if (ep.sort > item.epStatus) {
          next = ep.sort;
          break;
        }
      }
    }
    return _IconAction(
      tooltip: '看到第 $next 话',
      icon: Icons.check_circle_outline,
      label: '$next',
      onTap: onBump,
    );
  }
}

class _NextAirInfo extends ConsumerWidget {
  final int subjectId;

  const _NextAirInfo({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eps = ref.watch(epListProvider(subjectId)).valueOrNull?.eps;
    final text = homeNextInfo(
      eps: [
        for (final ep in eps ?? const <Ep>[])
          (sort: ep.sort, airdate: ep.airdate),
      ],
    );
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: context.ds.tiny.copyWith(
        color: context.ds.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SeasonLeftInfo extends ConsumerWidget {
  final CollectionItem item;
  final bool isAnime;

  const _SeasonLeftInfo({required this.item, required this.isAnime});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leftover = _unwatchedAiredCount(ref, item);
    final season = calcHomeSeason(item.subject.airDate);
    final text = homeLeftText(
      seasonYear: season.year,
      quarter: season.quarter,
      airedUnwatched: leftover < 0 ? 0 : leftover,
      type: item.subject.type,
      hasNewEp: leftover != 0,
      sink: SettingsStore.instance.homeSortSink,
    );
    if (text.isEmpty) return const SizedBox.shrink();
    const colors = [
      Color(0xFF7EC8E8),
      Color(0xFFF09CB0),
      Color(0xFF8CD4B8),
      Color(0xFFF5C898),
    ];
    final barColor = isAnime && season.quarter >= 1 && season.quarter <= 4
        ? colors[season.quarter - 1]
        : context.ds.border;
    return Row(
      children: [
        Container(
          width: 4,
          height: 8,
          margin: const EdgeInsets.only(right: 7, top: 1),
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: context.ds.tiny.copyWith(
              color: context.ds.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressMetaLine extends ConsumerWidget {
  final CollectionItem item;
  final SettingsStore store;

  const _ProgressMetaLine({required this.item, required this.store});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = item.subject;
    final inline = store.homeAnimeInfoInline == 2;
    final weekday =
        int.tryParse(store.customOnAirOf(subject.id)?.split('|').first ?? '') ??
        subject.airWeekday;

    final doing = homeDoingMetaText(
      doing: subject.collection?.doing ?? 0,
      type: subject.type,
      weekday: weekday,
      onAir:
          subject.type != 'book' &&
          subject.type != 'game' &&
          (subject.airWeekday > 0 || store.customOnAirOf(subject.id) != null),
      homeOnAir: store.homeOnAir,
    );
    var left = '';
    var next = '';
    if (inline && subject.type != 'book' && subject.type != 'game') {
      final leftover = _unwatchedAiredCount(ref, item);
      final season = calcHomeSeason(subject.airDate);
      left = homeLeftText(
        seasonYear: season.year,
        quarter: season.quarter,
        airedUnwatched: leftover < 0 ? 0 : leftover,
        type: subject.type,
        hasNewEp: leftover != 0,
        sink: store.homeSortSink,
        twoDigitYear: true,
      );
      final eps = ref.watch(epListProvider(subject.id)).valueOrNull?.eps;
      if (eps != null) {
        next = homeNextInfo(
          eps: [for (final ep in eps) (sort: ep.sort, airdate: ep.airdate)],
          showSplit: false,
        );
      }
    }
    final text = joinHomeMeta(doing, left: left, next: next);
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        style: context.ds.caption.copyWith(fontSize: inline ? 11 : 12),
      ),
    );
  }
}

({int aired, int total}) _onAirBar(WidgetRef ref, CollectionItem item) {
  final subject = item.subject;
  final total = subject.eps > 0 ? subject.eps : subject.epsCount;
  final eps = ref.watch(epListProvider(subject.id)).valueOrNull?.eps;
  if (eps == null || eps.isEmpty) {
    return onairProgressCounts(aired: 0, total: total);
  }
  final mapped = [
    for (final ep in eps)
      (type: ep.type, sort: ep.sort, status: ep.status, airdate: ep.airdate),
  ];
  var aired = currentOnAir(eps: mapped);
  if (aired > total && total > 0) {
    aired = airedRegularCount(eps: mapped);
  }
  return onairProgressCounts(aired: aired, total: total);
}

TextSpan _highlightTitle(
  String text,
  String filter, {
  required double fontSize,
}) {
  final style = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600);
  final hit = pinYinFilterValue(text, filter);
  if (hit == null) return TextSpan(text: text, style: style);
  final index = text.toLowerCase().indexOf(hit.toLowerCase());
  if (index < 0) return TextSpan(text: text, style: style);
  return TextSpan(
    style: style,
    children: [
      TextSpan(text: text.substring(0, index)),
      TextSpan(
        text: text.substring(index, index + hit.length),
        style: const TextStyle(color: Color(0xFFE53935)),
      ),
      TextSpan(text: text.substring(index + hit.length)),
    ],
  );
}

int _unwatchedAiredCount(WidgetRef ref, CollectionItem item) {
  final eps = ref.watch(epListProvider(item.subject.id)).valueOrNull?.eps;
  if (eps == null || eps.isEmpty) return -1;
  final status = ref.watch(epStatusProvider(item.subject.id)).valueOrNull;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var leftover = 0;
  for (final ep in eps) {
    if (ep.airdate.isEmpty) continue;
    final parsed = DateTime.tryParse(ep.airdate);
    if (parsed == null) continue;
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    if (!day.isAfter(today) && !(status?.isWatched(ep.id) ?? false)) {
      leftover++;
    }
  }
  return leftover;
}

class _ProgressLoginGate extends ConsumerWidget {
  const _ProgressLoginGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = context.ds;
    final store = ref.watch(settingsStoreProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              InkWell(
                onTap: () => openExternalUrl(kZhinanHost),
                child: Row(
                  children: [
                    Icon(
                      Icons.chrome_reader_mode_outlined,
                      size: 20,
                      color: ds.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text('指南', style: ds.label),
                  ],
                ),
              ),
              BgmHeaderAction(
                tooltip: '切换主题',
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.dark_mode
                      : Icons.wb_sunny_outlined,
                  size: 18,
                ),
                onPressed: store.toggleThemeMode,
              ),
              const Spacer(),
              BgmHeaderAction(
                tooltip: '搜索',
                icon: const Icon(Icons.search, size: 22),
                onPressed: () => context.push('/search'),
              ),
              BgmHeaderAction(
                tooltip: '设置',
                icon: const Icon(Icons.settings, size: 18),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 96),
              child: SizedBox(
                width: 160,
                child: BgmButton(
                  '登录后管理进度',
                  onPressed: () => context.push('/login'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressTips extends ConsumerWidget {
  const _ProgressTips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ProgressData? active;
    for (final t in kProgressTabs) {
      final data = ref.watch(progressProvider(t.$2)).valueOrNull;
      if (data != null && data.prefetching && data.prefetchTotal > 0) {
        active = data;
        break;
      }
    }
    if (active == null) return const SizedBox.shrink();
    final ds = context.ds;
    final total = active.prefetchTotal;
    final current = active.prefetchCurrent.clamp(0, total);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(8),
          color: ds.surfaceCard,
          child: SizedBox(
            width: 200,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '请求中', style: ds.body),
                        TextSpan(
                          text: ' $current / $total',
                          style: ds.tiny,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : current / total,
                      minHeight: 3,
                      color: ds.accent,
                      backgroundColor: ds.border,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressGridPanel extends ConsumerWidget {
  final CollectionItem? item;
  final String type;
  final bool pinned;
  final VoidCallback? onPin;
  final VoidCallback? onExpandAll;
  final VoidCallback? onCollapseAll;

  const _ProgressGridPanel({
    required this.item,
    required this.type,
    required this.pinned,
    required this.onPin,
    this.onExpandAll,
    this.onCollapseAll,
  });

  static const _prevText = {
    'all': '条目',
    'anime': '番组',
    'book': '书籍',
    'real': '电视剧',
    'game': '游戏',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = item;
    if (selected == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mesume(size: 80),
            const SizedBox(height: 8),
            Text(
              '请先点击下方${_prevText[type] ?? '条目'}',
              style: context.ds.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    final subject = selected.subject;
    final isBook = subject.type == 'book';
    final isGame = subject.type == 'game';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Cover(
                url: subject.images.common,
                width: 64,
                height: 90,
                radius: 4,
                type: subject.type,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.displayName,
                      style: context.ds.bodyStrong,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (isBook)
                          Text(
                            'Chap. ${selected.epStatus}${subject.eps > 0 ? ' / ${subject.eps}' : ''}   Vol. ${selected.volStatus}',
                            style: context.ds.caption,
                          )
                        else if (isGame)
                          Text(
                            selected.updatedAt.isEmpty
                                ? '在玩'
                                : '${friendlyTime(selected.updatedAt)} 在玩',
                            style: context.ds.caption,
                          )
                        else
                          Text(
                            homeCountText(
                              current: selected.epStatus,
                              total: subject.eps,
                              style: SettingsStore.instance.homeCountView,
                            ),
                            style: context.ds.caption.copyWith(
                              color: context.ds.accent,
                            ),
                          ),
                        const Spacer(),
                        if (SettingsStore.instance.homeOrigin != 'hide' &&
                            (subject.type == 'anime' || subject.type == 'real'))
                          _OriginButton(
                            item: selected,
                            onPin: onPin ?? () {},
                            pinned: pinned,
                            showOrigins:
                                SettingsStore.instance.homeOrigin == 'all',
                            onExpandAll: onExpandAll,
                            onCollapseAll: onCollapseAll,
                          ),
                        if (isBook) ...[
                          _IconAction(
                            tooltip: 'Chap +1',
                            icon: Icons.check_circle_outline,
                            onTap: () => unawaited(
                              _bumpGrid(
                                context,
                                ref,
                                selected,
                                selected.epStatus + 1,
                              ),
                            ),
                          ),
                          _IconAction(
                            tooltip: 'Vol +1',
                            icon: Icons.menu_book_outlined,
                            onTap: () => unawaited(
                              _bumpGrid(
                                context,
                                ref,
                                selected,
                                selected.epStatus,
                                vols: selected.volStatus + 1,
                              ),
                            ),
                          ),
                        ] else if (!isGame)
                          _NextEpAction(
                            item: selected,
                            type: type,
                            onBump: () => unawaited(
                              _bumpGrid(
                                context,
                                ref,
                                selected,
                                selected.epStatus + 1,
                              ),
                            ),
                          ),
                        _IconAction(
                          tooltip: '收藏管理',
                          icon: Icons.star_outline,
                          onTap: () =>
                              showBgmSheet<void>(
                                context: context,
                                builder: (_) =>
                                    CollectionSheet(subjectId: subject.id),
                              ).then((_) {
                                ref.invalidate(progressProvider(type));
                              }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isBook && !isGame)
            _ProgressEpGrid(subjectId: subject.id, type: type, compact: true),
        ],
      ),
    );
  }

  Future<void> _bumpGrid(
    BuildContext context,
    WidgetRef ref,
    CollectionItem item,
    int eps, {
    int? vols,
  }) async {
    final ok = await ref
        .read(progressProvider(type).notifier)
        .setWatched(item, eps, watchedVols: vols);
    if (context.mounted && !ok) {
      showBgmToast(context, '更新进度失败');
    }
  }
}

class _ProgressGridCard extends ConsumerWidget {
  final CollectionItem item;
  final bool selected;
  final bool pinned;
  final VoidCallback onPin;
  final VoidCallback onSelect;

  const _ProgressGridCard({
    required this.item,
    required this.selected,
    required this.pinned,
    required this.onPin,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = item.subject;
    final isGame = subject.type == 'game';
    final store = SettingsStore.instance;
    final square = store.homeGridCoverLayout == 'square';
    final bar = _onAirBar(ref, item);
    return InkWell(
      onTap: onSelect,
      onLongPress: () => context.push('/subject/${subject.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Opacity(
              opacity: selected ? 0.64 : 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Cover(
                      url: subject.images.common,
                      width: double.infinity,
                      height: double.infinity,
                      radius: square ? 4 : 6,
                      type: subject.type,
                    ),
                  ),
                  if (pinned)
                    const Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        Icons.push_pin,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  if (!isGame)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _OnAirProgress(
                        watched: item.epStatus,
                        aired: bar.aired,
                        total: bar.total,
                        compact: true,
                        height: 3,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (store.homeGridTitle) ...[
            const SizedBox(height: 4),
            Text(
              subject.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.ds.caption,
            ),
          ],
          if (!isGame)
            _OnAirLabel(
              weekday: subject.airWeekday,
              subjectId: subject.id,
              current: bar.aired,
              total: bar.total,
            ),
          Text(
            isGame
                ? SubjectType.statusText(item.type, item.subject.type)
                : homeCountText(
                    current: item.epStatus,
                    total: bar.total,
                    style: SettingsStore.instance.homeCountView,
                  ),
            style: context.ds.tiny,
          ),
        ],
      ),
    );
  }
}

/// 原版 OnairProgress: 灰=已放送, 粉=已看
class _OnAirProgress extends StatelessWidget {
  final int watched;
  final int aired;
  final int total;
  final bool compact;
  final double? height;

  const _OnAirProgress({
    required this.watched,
    this.aired = 0,
    required this.total,
    this.compact = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final barHeight = height ?? (compact ? 5.0 : 6.0);
    final ratios = onairProgressRatios(
      watched: watched,
      aired: aired,
      total: total,
    );
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: AppRadius.sAll,
      child: SizedBox(
        height: barHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: dark
                  ? Colors.white.withValues(alpha: 0.1)
                  : ds.border.withValues(alpha: 0.35),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratios.aired,
                child: ColoredBox(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0x33808080),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratios.watched,
                child: ColoredBox(color: ds.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _addUnairedReminders(
  BuildContext context,
  WidgetRef ref,
  CollectionItem item,
) async {
  final eps =
      ref.read(epListProvider(item.subject.id)).valueOrNull?.eps ??
      const <Ep>[];
  final status = ref.read(epStatusProvider(item.subject.id)).valueOrNull;
  final unaired = [
    for (final ep in eps)
      if (canAddEpCalendar(
        type: ep.type,
        airdate: ep.airdate,
        watched: status?.isWatched(ep.id) ?? false,
      ))
        (id: ep.id, sort: ep.sort, name: ep.displayName, airdate: ep.airdate),
  ];
  if (unaired.isEmpty) {
    if (context.mounted) showBgmToast(context, '已没有未放送的章节');
    return;
  }
  final title = item.subject.displayName;
  final ok = await showBgmConfirm(
    context,
    title: '一键添加放送提醒',
    message: '「$title」\n是否一键添加 ${unaired.length} 个章节的提醒?',
    confirmLabel: '添加',
  );
  if (ok != true || !context.mounted) return;
  final custom = SettingsStore.instance.customOnAirOf(item.subject.id);
  final clock = custom != null && custom.contains('|')
      ? custom.split('|').last
      : '2000';
  await shareSubjectIcs(
    subjectId: item.subject.id,
    title: title,
    clock: clock,
    eps: unaired,
  );
}
