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

import '../rakuen/rakuen_providers.dart';
import '../discovery/discovery_screen.dart';

import '../discovery/calendar_screen.dart';
import '../subject/collection_sheet.dart';
import '../subject/ep_menu.dart';
import '../subject/subject_providers.dart';

import '../user/origin_setting_screen.dart';
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

  const ProgressData({
    this.items = const [],
    this.page = 1,
    this.hasMore = true,
  });
}

final progressProvider =
    AsyncNotifierProvider.family<ProgressNotifier, ProgressData, String>(
      ProgressNotifier.new,
    );

class ProgressNotifier extends FamilyAsyncNotifier<ProgressData, String> {
  @override
  Future<ProgressData> build(String type) async {
    ref.watch(settingsStoreProvider.select((s) => s.showGame));
    return _fetch(1, type);
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

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(current.page + 1, arg);
      state = AsyncData(
        ProgressData(
          items: [...current.items, ...next.items],
          page: next.page,
          hasMore: next.hasMore,
        ),
      );
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
    try {
      await client.post(
        apiSubjectUpdateWatched(subject.id),
        data: {'watched_eps': watchedEps, 'watched_vols': ?watchedVols},
      );
      ref.invalidate(progressProvider(arg));
      return true;
    } catch (_) {
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

class _ProgressScreenState extends ConsumerState<ProgressScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  List<(String, String)> get _tabs {
    final settings = ref.watch(settingsStoreProvider);
    final visible = settings.homeTabs.toSet();
    final tabs = [
      for (final t in kProgressTabs)
        if (t.$2 == 'game' ? settings.showGame : visible.contains(t.$2)) t,
    ];
    return tabs.isEmpty ? const [('全部', 'all')] : tabs;
  }

  void _syncTabs(int length) {
    final current = _tabController;
    if (current != null && current.length == length) return;
    current?.dispose();
    _tabController = TabController(length: length, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = ref.watch(isLoggedInProvider);
    final unread = ref.watch(notifyCountProvider).valueOrNull ?? 0;
    final store = ref.watch(settingsStoreProvider);
    final tabs = _tabs;
    _syncTabs(tabs.length);
    return Scaffold(
      appBar: AppBar(
        title: const TabLogoTitle('进度'),
        leadingWidth: isLogin ? 112 : null,
        leading: isLogin
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '电波提醒',
                    onPressed: () => context.push('/rakuen/notify'),
                    icon: Badge(
                      isLabelVisible: unread > 0,
                      label: Text('$unread'),
                      child: const Icon(Icons.notifications_outlined),
                    ),
                  ),
                  ..._homeHeaderActions(context, store.homeTopExtraCustom),
                ],
              )
            : null,
        actions: [
          if (isLogin)
            IconButton(
              tooltip: store.progressGrid ? '列表布局' : '宫格布局',
              icon: Icon(
                store.progressGrid
                    ? Icons.view_list_outlined
                    : Icons.grid_view_outlined,
              ),
              onPressed: () {
                store.setProgressGrid(!store.progressGrid);
              },
            ),
          if (isLogin) ..._homeHeaderActions(context, store.homeTopLeftCustom),
          if (isLogin) ..._homeHeaderActions(context, store.homeTopRightCustom),
        ],
        bottom: isLogin
            ? TabBar(
                controller: _tabController,
                tabs: [for (final t in _tabs) Tab(text: t.$1)],
              )
            : null,
      ),
      body: isLogin
          ? TabBarView(
              controller: _tabController,
              children: [for (final t in tabs) _ProgressList(type: t.$2)],
            )
          : const _ProgressLoginGate(),
    );
  }
}

List<Widget> _homeHeaderActions(BuildContext context, String key) {
  if (key.isEmpty) return const [];
  DiscoveryMenuItem? item;
  for (final e in kDiscoveryMenus) {
    if (e.key == key) {
      item = e;
      break;
    }
  }
  if (item == null || item.key == 'Open') return const [];
  return [
    IconButton(
      tooltip: item.name,
      icon: item.text != null
          ? Text(
              item.text!,
              style: const TextStyle(fontWeight: FontWeight.w700),
            )
          : Icon(item.icon),
      onPressed: () {
        if (item!.key == 'Link') {
          showClipboardModal(context);
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
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('加载失败'),
            TextButton(
              onPressed: () => ref.invalidate(progressProvider(widget.type)),
              child: const Text('重试'),
            ),
          ],
        ),
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

        if (data.items.isEmpty) {
          return _ProgressEmpty(
            type: widget.type,
            filter: q,
            filteredEmpty: false,
          );
        }
        if (items.isEmpty) {
          return _ProgressEmpty(
            type: widget.type,
            filter: q,
            filteredEmpty: true,
          );
        }

        final filterBar = store.homeFilter
            ? Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TextField(
                  controller: _filterController,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: items.isEmpty && q.isEmpty
                        ? '筛选'
                        : '${items.length}',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _filter = v.trim()),
                ),
              )
            : const SizedBox.shrink();
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
                ),
                Expanded(
                  child: GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: store.homeGridCoverLayout == 'square'
                          ? (store.homeGridTitle ? 0.72 : 0.92)
                          : (store.homeGridTitle ? 0.58 : 0.68),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _ProgressGridCard(
                        item: item,
                        selected: _selected?.subject.id == item.subject.id,
                        pinned: pinned.contains(item.subject.id),
                        onPin: () =>
                            store.toggleProgressPinned(item.subject.id),
                        onSelect: () => setState(() => _selected = item),
                      );
                    },
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
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ProgressItemView(
                      item: item,
                      type: widget.type,
                      pinned: pinned.contains(item.subject.id),
                      onPin: () => store.toggleProgressPinned(item.subject.id),
                      filter: q,
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
  final bool initiallyExpanded;
  final String filter;

  const _ProgressItemView({
    required this.item,
    required this.type,
    required this.pinned,
    required this.onPin,
    this.initiallyExpanded = false,
    this.filter = '',
  });

  @override
  ConsumerState<_ProgressItemView> createState() => _ProgressItemViewState();
}

class _ProgressItemViewState extends ConsumerState<_ProgressItemView> {
  late bool _expanded = widget.initiallyExpanded;

  CollectionItem get item => widget.item;
  String get type => widget.type;

  @override
  Widget build(BuildContext context) {
    final subject = item.subject;
    final isBook = subject.type == 'book';
    final isGame = subject.type == 'game';
    final store = ref.watch(settingsStoreProvider);
    final compact = store.homeListCompact;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 4 : 8,
      ),

      child: Column(
        children: [
          InkWell(
            onTap: () => context.push('/subject/${subject.id}'),
            onLongPress: () => _editProgress(context, ref),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Cover(
                      url: subject.images.common,
                      width: 60,
                      height: 80,
                      radius: 4,
                      type: subject.type,
                    ),

                    if (widget.pinned)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: GestureDetector(
                          onTap: widget.onPin,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: context.ds.accent,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 10),
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

                          if (!isBook && !isGame)
                            _OnAirLabel(
                              weekday: subject.airWeekday,
                              subjectId: subject.id,
                              current: item.epStatus,
                              total: subject.eps > 0
                                  ? subject.eps
                                  : subject.epsCount,
                            ),
                        ],
                      ),

                      if (!SettingsStore.instance.hideScore &&
                          subject.rating != null &&
                          subject.rating!.score > 0)
                        Row(
                          children: [
                            Icon(Icons.star, size: 13, color: context.ds.star),
                            const SizedBox(width: 2),
                            Text(
                              subject.rating!.score.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.ds.star,
                              ),
                            ),
                          ],
                        ),

                      if (!compact && (subject.collection?.doing ?? 0) > 0)
                        Text(
                          '${subject.collection!.doing} 人在${isBook
                              ? '读'
                              : isGame
                              ? '玩'
                              : '看'}',
                          style: context.ds.tiny,
                        ),

                      const SizedBox(height: 2),
                      if (isBook)
                        Text(
                          'Chap. ${item.epStatus}${subject.eps > 0 ? ' / ${subject.eps}' : ''}   Vol. ${item.volStatus}',
                          style: context.ds.caption,
                        )
                      else if (isGame)
                        Text(
                          item.updatedAt.isEmpty
                              ? '在玩'
                              : '${friendlyTime(item.updatedAt)} 在玩',
                          style: context.ds.caption,
                        )
                      else
                        InkWell(
                          onTap: () => setState(() => _expanded = !_expanded),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              Text(
                                homeCountText(
                                  current: item.epStatus,
                                  total: subject.eps,
                                  style: store.homeCountView,
                                ),
                                style: context.ds.caption.copyWith(
                                  color: context.ds.accent,
                                ),
                              ),
                              if (store.homeAnimeInfoInline == 2) ...[
                                _SeasonLeftInfo(
                                  item: item,
                                  isAnime: subject.type == 'anime',
                                ),
                                _NextAirInfo(subjectId: subject.id),
                              ],
                            ],
                          ),
                        ),
                      if (!isBook &&
                          !isGame &&
                          store.homeAnimeInfoInline == 1) ...[
                        _SeasonLeftInfo(
                          item: item,
                          isAnime: subject.type == 'anime',
                        ),
                        _NextAirInfo(subjectId: subject.id),
                      ],

                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (store.homeOrigin != 'hide')
                            _OriginButton(
                              item: item,
                              onPin: widget.onPin,
                              pinned: widget.pinned,
                              showOrigins: store.homeOrigin == 'all',
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
                                showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  useSafeArea: true,
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
          ),
          if (_expanded && !isBook && !isGame)
            _ProgressEpGrid(
              subjectId: subject.id,
              type: type,
              compact: store.progressGrid,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('更新进度失败')));
    }
  }

  Future<void> _editProgress(BuildContext context, WidgetRef ref) async {
    final subject = item.subject;
    final epsCtrl = TextEditingController(text: '${item.epStatus}');
    final volCtrl = TextEditingController(text: '${item.volStatus}');
    final isBook = subject.type == 'book';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置观看进度'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: epsCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isBook ? 'Chap.' : '看到第几话',
                suffixText: subject.eps > 0 ? '/ ${subject.eps}' : null,
              ),
            ),
            if (isBook) ...[
              const SizedBox(height: 8),
              TextField(
                controller: volCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Vol.'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('自定义放送'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  value: wd,
                  isExpanded: true,
                  items: [
                    for (var i = 0; i < 7; i++)
                      DropdownMenuItem(value: i, child: Text(kWeekdayCn[i])),
                  ],
                  onChanged: (v) => setLocal(() => wd = v ?? wd),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        value: hour,
                        isExpanded: true,
                        items: [
                          for (var h = 0; h < 24; h++)
                            DropdownMenuItem(
                              value: h.toString().padLeft(2, '0'),
                              child: Text(h.toString().padLeft(2, '0')),
                            ),
                        ],
                        onChanged: (v) => setLocal(() => hour = v ?? hour),
                      ),
                    ),
                    const Text(' : '),
                    Expanded(
                      child: DropdownButton<String>(
                        value: minute,
                        isExpanded: true,
                        items: [
                          for (final m in const ['00', '15', '30', '45'])
                            DropdownMenuItem(value: m, child: Text(m)),
                        ],
                        onChanged: (v) => setLocal(() => minute = v ?? minute),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ref.read(settingsStoreProvider).clearCustomOnAir(subjectId);
                  Navigator.pop(ctx, false);
                },
                child: const Text('恢复默认'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('保存'),
              ),
            ],
          ),
        );
      },
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
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
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
                            !(status?.isWatched(ep.id) ?? false),
                          );
                          ref.invalidate(epStatusProvider(subjectId));
                          ref.invalidate(progressProvider(type));
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('更新章节失败')),
                            );
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

  const _OriginButton({
    required this.item,
    required this.pinned,
    required this.onPin,
    this.showOrigins = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origins = showOrigins
        ? originsForType(
            ref.watch(originConfigProvider).valueOrNull ?? const {},
            item.subjectType.isEmpty ? item.subject.type : item.subjectType,
          )
        : const <OriginItem>[];
    return PopupMenuButton<String>(
      tooltip: showOrigins ? '源头' : '更多',
      icon: Icon(
        showOrigins && origins.length > 1 ? Icons.cast : Icons.more_horiz,
        size: 20,
      ),
      onSelected: (value) async {
        if (value == 'pin') {
          onPin();
          return;
        }
        if (value == 'manage') {
          if (context.mounted) await context.push('/settings/origin');
          return;
        }
        if (value == 'ics') {
          final eps =
              ref.read(epListProvider(item.subject.id)).valueOrNull?.eps ??
              const <Ep>[];
          final custom = SettingsStore.instance.customOnAirOf(item.subject.id);
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已复制地址，即将跳转')));
        }
        await openExternalUrl(url);
      },
      itemBuilder: (_) => [
        if (showOrigins)
          for (final o in origins)
            PopupMenuItem(value: o.uuid, child: Text(o.name)),
        PopupMenuItem(value: 'pin', child: Text(pinned ? '取消置顶' : '置顶')),
        if (SettingsStore.instance.exportICS)
          const PopupMenuItem(value: 'ics', child: Text('导出日程')),
        if (showOrigins)
          const PopupMenuItem(value: 'manage', child: Text('源头管理')),
      ],
    );
  }
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
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: label == null
          ? Icon(icon, size: 20)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 2),
                Text(label!, style: context.ds.caption),
              ],
            ),
      onPressed: onTap,
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
    if (eps == null || eps.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    Ep? next;
    for (final ep in eps) {
      if (ep.airdate.isEmpty) continue;
      final parsed = DateTime.tryParse(ep.airdate);
      if (parsed == null) continue;
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      if (day.isAfter(today)) {
        next = ep;
        break;
      }
    }
    if (next == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text('完结', style: context.ds.tiny),
      );
    }
    final parsed = DateTime.tryParse(next.airdate);
    final days = parsed == null
        ? 0
        : DateTime(
            parsed.year,
            parsed.month,
            parsed.day,
          ).difference(today).inDays;
    final date = next.airdate.length >= 10
        ? next.airdate.substring(2)
        : next.airdate;
    final text = days > 0
        ? 'ep${next.sort} · $date ($days 天后)'
        : 'ep${next.sort} · $date';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(text, style: context.ds.tiny),
    );
  }
}

class _SeasonLeftInfo extends ConsumerWidget {
  final CollectionItem item;
  final bool isAnime;

  const _SeasonLeftInfo({required this.item, required this.isAnime});

  static const _seasons = ['冬', '春', '夏', '秋'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = item.subject;
    final season = _calcSeason(subject.airDate);
    final eps =
        ref.watch(epListProvider(subject.id)).valueOrNull?.eps ?? const [];
    final status = ref.watch(epStatusProvider(subject.id)).valueOrNull;
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
    final parts = <String>[];
    if (season.$1 > 0) {
      parts.add(
        isAnime ? '${season.$1} ${_seasons[season.$2 - 1]}' : '${season.$1}',
      );
    }
    if (leftover > 0) parts.add('$leftover 集未看');
    if (parts.isEmpty) return const SizedBox.shrink();
    const colors = [
      Color(0xFF7EC8E8),
      Color(0xFFF09CB0),
      Color(0xFF8CD4B8),
      Color(0xFFF5C898),
    ];
    final barColor = isAnime && season.$2 >= 1 && season.$2 <= 4
        ? colors[season.$2 - 1]
        : context.ds.border;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 8,
            margin: const EdgeInsets.only(right: 7),
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(child: Text(parts.join(' · '), style: context.ds.tiny)),
        ],
      ),
    );
  }

  (int, int) _calcSeason(String airDate) {
    final parsed = DateTime.tryParse(airDate);
    if (parsed == null) return (0, 1);
    var year = parsed.year;
    var adj = parsed.month;
    if (parsed.day >= 22 && parsed.month % 3 == 0) adj = parsed.month + 1;
    if (adj > 12) {
      adj -= 12;
      year += 1;
    }
    return (year, (adj / 3).ceil());
  }
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

class _ProgressEmpty extends StatelessWidget {
  final String type;
  final String filter;
  final bool filteredEmpty;

  const _ProgressEmpty({
    required this.type,
    required this.filter,
    required this.filteredEmpty,
  });

  static const _emptyText = {
    'all': '当前没有可管理的条目哦',
    'anime': '当前没有在追的番组哦',
    'book': '当前没有在读的书籍哦',
    'real': '当前没有在追的电视剧哦',
    'game': '当前没有在玩的游戏哦',
  };

  @override
  Widget build(BuildContext context) {
    final searchType = switch (type) {
      'book' => '书籍',
      'real' => '三次元',
      'game' => '游戏',
      'all' => '条目',
      _ => '动画',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: context.ds.textHint),
            const SizedBox(height: 12),
            Text(
              filteredEmpty ? '没有匹配的条目' : (_emptyText[type] ?? '当前没有可管理的条目哦'),
              style: context.ds.caption,
              textAlign: TextAlign.center,
            ),
            if (SettingsStore.instance.speech && !filteredEmpty) ...[
              const SizedBox(height: 8),
              Text('Bangumi 娘: 列表到底啦', style: context.ds.tiny),
            ],
            if (filteredEmpty && filter.isNotEmpty) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => context.push(
                  '/search?q=${Uri.encodeQueryComponent(filter)}&type=${Uri.encodeQueryComponent(searchType)}',
                ),
                child: const Text('前往搜索'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressLoginGate extends ConsumerWidget {
  const _ProgressLoginGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.manage_search, size: 48, color: context.ds.textHint),
          const SizedBox(height: 12),
          const Text('登录后管理你的追番进度'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('登录'),
          ),
        ],
      ),
    );
  }
}

class _ProgressGridPanel extends StatelessWidget {
  final CollectionItem? item;
  final String type;
  final bool pinned;
  final VoidCallback? onPin;

  const _ProgressGridPanel({
    required this.item,
    required this.type,
    required this.pinned,
    required this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    final selected = item;
    if (selected == null) {
      return Container(
        height: 88,
        alignment: Alignment.center,
        child: Text('请先点击下方封面', style: context.ds.caption),
      );
    }
    return _ProgressItemView(
      item: selected,
      type: type,
      pinned: pinned,
      onPin: onPin ?? () {},
      initiallyExpanded: true,
    );
  }
}

class _ProgressGridCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final subject = item.subject;
    final isGame = subject.type == 'game';
    final store = SettingsStore.instance;
    final square = store.homeGridCoverLayout == 'square';
    final total = subject.eps > 0 ? subject.eps : subject.epsCount;
    final ratio = total > 0 ? (item.epStatus / total).clamp(0.0, 1.0) : 0.0;
    return InkWell(
      onTap: onSelect,
      onLongPress: () => context.push('/subject/${subject.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(square ? 4 : 6),
                border: Border.all(
                  color: selected ? context.ds.accent : Colors.transparent,
                  width: 2,
                ),
              ),
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
                  if (!isGame && total > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(6),
                        ),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 3,
                          backgroundColor: Colors.black26,
                          color: context.ds.accent,
                        ),
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
              current: item.epStatus,
              total: total,
            ),
          Text(
            isGame
                ? SubjectType.statusText(item.type, item.subject.type)
                : homeCountText(
                    current: item.epStatus,
                    total: total,
                    style: SettingsStore.instance.homeCountView,
                  ),
            style: context.ds.tiny,
          ),
        ],
      ),
    );
  }
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
