import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/site_cookies.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';
import '../../features/rakuen/rakuen_providers.dart';
import '../../features/rakuen/rakuen_settings.dart';
import '../../features/tinygrail/tinygrail_api.dart';
import '../subject/collection_sheet.dart';

import '../../features/tinygrail/tinygrail_models.dart';
import '../../shared/models/collection.dart';
import '../../shared/models/user.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';

import 'blogs_screen.dart';
import 'catalogs_screen.dart';
import 'friends_screen.dart';
import 'user_models.dart';
import 'user_timeline_screen.dart';
import '../../design_system/design_system.dart';

/// 用户信息 (旧版 API /user/{uid})
final zoneUserProvider = FutureProvider.family<User, String>((
  ref,
  userId,
) async {
  final client = ref.read(apiClientProvider);
  final data = await client.get(apiUserInfo(userId));
  return User.fromJson(data as Map<String, dynamic>);
});

/// 用户收藏统计 (旧版 API /user/{uid}/collections/status)
/// 返回数组 [{type, name, collects:[{status:{id}, count}]}], 转成 CollectionStats
final zoneStatsProvider = FutureProvider.family<CollectionStats, String>((
  ref,
  userId,
) async {
  final client = ref.read(apiClientProvider);
  final data = await client.get(
    apiUserCollectionsStatus(userId),
    query: {'app_id': kAppId},
  );
  return CollectionStats.fromJson(data);
});

/// 用户主页加入/活跃 (原项目 users.join / recent)
final zoneHomeExtraProvider = FutureProvider.family<UserHomeExtra, String>((
  ref,
  userId,
) async {
  try {
    final client = ref.read(apiClientProvider);
    final html = await client.get(apiUserHomeHtml(userId), host: kHost);
    return parseUserHomeExtra(html as String);
  } catch (_) {
    return const UserHomeExtra();
  }
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

final zoneCollectionsProvider =
    AsyncNotifierProvider.family<
      ZoneCollectionsNotifier,
      ZoneCollectionsData,
      ({String userId, String type, int status})
    >(ZoneCollectionsNotifier.new);

class ZoneCollectionsNotifier
    extends
        FamilyAsyncNotifier<
          ZoneCollectionsData,
          ({String userId, String type, int status})
        > {
  @override
  Future<ZoneCollectionsData> build(arg) => _fetch(0);

  Future<ZoneCollectionsData> _fetch(int offset) async {
    final client = ref.read(apiClientProvider);
    final status = arg.status == 0 ? '0' : '${arg.status}';
    final data = await client.get(
      apiV0UsersCollections(
        arg.userId,
        '${v0SubjectTypeInt(arg.type)}',
        100,
        offset,
        status,
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

/// 收藏 tab 过滤状态 (类型 + 状态)
class ZoneFilterController extends Notifier<({String type, int status})> {
  @override
  ({String type, int status}) build() => (type: 'anime', status: 0);

  void setFilter(String type, int status) {
    final store = ref.read(settingsStoreProvider);
    if (store.zoneCollapse && status == 0) {
      state = (type: type, status: CollectionStatus.doing);
      return;
    }
    state = (type: type, status: status);
  }
}

final zoneScreenControllerProvider =
    NotifierProvider<ZoneFilterController, ({String type, int status})>(
      ZoneFilterController.new,
    );

/// 用户空间 (bgm.tv 用户主页)
class ZoneScreen extends ConsumerStatefulWidget {
  final String userId;

  const ZoneScreen({super.key, required this.userId});

  @override
  ConsumerState<ZoneScreen> createState() => _ZoneScreenState();
}

class _ZoneScreenState extends ConsumerState<ZoneScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 9, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _selectStat(String type, int status) {
    final store = ref.read(settingsStoreProvider);
    final next = store.zoneCollapse && status == 0
        ? CollectionStatus.doing
        : status;
    ref.read(zoneScreenControllerProvider.notifier).setFilter(type, next);
    _tab.animateTo(1);
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
                onPressed: () =>
                    ref.invalidate(zoneUserProvider(widget.userId)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (user) => Column(
          children: [
            _ZoneHeader(
              user: user,
              userId: widget.userId,
              onStatTap: _selectStat,
            ),
            TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: '关于'),
                Tab(text: '收藏'),
                Tab(text: '统计'),
                Tab(text: '时间线'),
                Tab(text: '超展开'),
                Tab(text: '日志'),
                Tab(text: '目录'),
                Tab(text: '好友'),
                Tab(text: '小圣杯'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _ZoneAboutTab(user: user),
                  _ZoneCollectionsTab(
                    userId: widget.userId,
                    type: filter.type,
                    status: filter.status,
                  ),
                  _ZoneStatsTab(user: user),
                  UserTimelineBody(userId: widget.userId),
                  _ZoneRakuenTab(userId: widget.userId),
                  UserBlogsList(userId: widget.userId),
                  UserCatalogsTabs(userId: widget.userId),

                  FriendsList(userId: widget.userId),
                  _ZoneTinygrailTab(user: user),
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

  const _ZoneHeader({
    required this.user,
    required this.userId,
    required this.onStatTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    errorBuilder: (_, _, _) =>
                        Container(color: context.ds.accentSoft),
                  ),
                )
              else
                Container(color: context.ds.accentSoft),
              Container(color: Colors.black.withValues(alpha: 0.25)),
              Positioned(
                left: 16,
                bottom: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Avatar(
                      url: user.avatarUrl,
                      size: 68,
                      name: user.displayName,
                      userId: user.username.isNotEmpty ? user.username : userId,
                    ),
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
                        Row(
                          children: [
                            Text(
                              '@${user.username.isNotEmpty ? user.username : user.id}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            UserAgeBadge(
                              userId: user.username.isNotEmpty
                                  ? user.username
                                  : userId,
                            ),
                          ],
                        ),
                        if (!isMe)
                          _ZoneRemarkChip(
                            userId: user.username.isNotEmpty
                                ? user.username
                                : userId,
                          ),
                        _ZoneJoinRecent(userId: userId),
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
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                    ),
                    tooltip: '设置',
                    onPressed: () => context.push('/settings'),
                  ),
                )
              else
                Positioned(
                  top: 8,
                  right: 8,
                  child: _ZoneMenu(
                    user: user,
                    userId: userId,
                    onGoCollect: () => onStatTap('anime', 0),
                  ),
                ),
            ],
          ),
        ),
        if (user.sign.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                user.sign,
                style: context.ds.caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ActionChip(
                label: const Text('日志'),
                onPressed: () => context.push('/user/$userId/blogs'),
              ),
              ActionChip(
                label: const Text('目录'),
                onPressed: () => context.push('/user/$userId/catalogs'),
              ),
              ActionChip(
                label: const Text('好友'),
                onPressed: () => context.push('/user/$userId/friends'),
              ),
              if (!isMe)
                ActionChip(
                  label: const Text('发短信'),
                  onPressed: () => context.push('/pm/chat/${user.id}'),
                ),
              ActionChip(
                label: const Text('浏览器查看'),
                onPressed: () => context.push(
                  '/web/${Uri.encodeComponent('$kHost/user/$userId')}',
                ),
              ),
            ],
          ),
        ),
        // 收藏统计

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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 3,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 48,
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            for (final (status, statusLabel) in [
                              (
                                CollectionStatus.wish,
                                SubjectType.statusText(
                                  CollectionStatus.wish,
                                  type,
                                ),
                              ),
                              (
                                CollectionStatus.doing,
                                SubjectType.statusText(
                                  CollectionStatus.doing,
                                  type,
                                ),
                              ),
                              (
                                CollectionStatus.collect,
                                SubjectType.statusText(
                                  CollectionStatus.collect,
                                  type,
                                ),
                              ),
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
                                          color: context.ds.textSecondary,
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

class _ZoneRemarkChip extends ConsumerWidget {
  final String userId;

  const _ZoneRemarkChip({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remark = ref.watch(settingsStoreProvider).userRemarkOf(userId);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: () => _edit(context, ref, remark),
        child: Text(
          remark.isEmpty ? '备注' : '[$remark]',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('备注'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('在页面中出现该用户，使用备注内容高亮覆盖'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '输入备注',
                isDense: true,
              ),
            ),
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
    final text = controller.text;
    controller.dispose();
    if (saved == true) {
      await ref.read(settingsStoreProvider).setUserRemark(userId, text);
    }
  }
}

class _ZoneJoinRecent extends ConsumerWidget {
  final String userId;

  const _ZoneJoinRecent({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extra = ref.watch(zoneHomeExtraProvider(userId)).valueOrNull;
    if (extra == null) return const SizedBox.shrink();
    final join = extra.join;
    var recent = extra.recent;
    if (recent.contains(' ·')) recent = recent.split(' ·').first.trim();
    recent = recent.replaceAll('·', '').trim();
    final parts = <String>[
      if (join.isNotEmpty) join,
      if (extra.percent > 0)
        extra.hobby.isEmpty
            ? '同步率 ${extra.percent}%'
            : '同步率 ${extra.percent}% (${extra.hobby})',
      if (recent.isNotEmpty) '$recent活跃',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        parts.join(' · '),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// 用户空间右上角菜单 (移植自原项目 zone menu: 浏览器/复制/短信/收藏/好友/反向好友/加好友/绝交)
class _ZoneMenu extends ConsumerWidget {
  final User user;
  final String userId;
  final VoidCallback onGoCollect;

  const _ZoneMenu({
    required this.user,
    required this.userId,
    required this.onGoCollect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBlocked = ref.watch(rakuenSettingsProvider).isUserBlocked(userId);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      tooltip: '更多',
      onSelected: (action) => _handle(context, ref, action),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'browser', child: Text('浏览器查看')),
        const PopupMenuItem(value: 'copyLink', child: Text('复制链接')),
        const PopupMenuItem(value: 'copyShare', child: Text('复制分享文案')),
        const PopupMenuItem(value: 'pm', child: Text('发短信')),
        const PopupMenuItem(value: 'collect', child: Text('TA的收藏')),
        const PopupMenuItem(value: 'friends', child: Text('TA的好友')),
        const PopupMenuItem(value: 'revFriends', child: Text('谁加TA为好友')),
        const PopupMenuItem(value: 'characters', child: Text('TA的人物')),

        PopupMenuItem(
          value: 'connect',
          child: Text(isBlocked ? '解除绝交' : '加为好友'),
        ),
        if (!isBlocked) const PopupMenuItem(value: 'block', child: Text('绝交')),
        const PopupMenuItem(value: 'report', child: Text('报告疑虑')),
      ],
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final username = user.username.isNotEmpty ? user.username : '${user.id}';
    final url = '$kHost/user/$username';
    final isBlocked = ref.read(rakuenSettingsProvider).isUserBlocked(userId);
    switch (action) {
      case 'browser':
        await openExternalUrl(url);

      case 'copyLink':
        await Clipboard.setData(ClipboardData(text: url));
      case 'copyShare':
        await Clipboard.setData(
          ClipboardData(text: '【链接】${user.displayName} | Bangumi番组计划\n$url'),
        );
      case 'pm':
        await context.push('/pm/chat/${user.id}');
      case 'collect':
        onGoCollect();
      case 'friends':
        await context.push('/user/$username/friends');
      case 'revFriends':
        await context.push('/user/$username/friends?rev=1');
      case 'characters':
        await context.push('/user/$username/mono');
      case 'connect':
        await _connectOrUnblock(context, ref, isBlocked: isBlocked);
      case 'block':
        await ref.read(rakuenSettingsProvider.notifier).addBlockUser(userId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已绝交'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      case 'report':
        await openExternalUrl('$kHost/report?type=6&id=${user.id}');
    }
  }

  /// 加好友 (站点 Cookie + formhash) / 解除绝交
  Future<void> _connectOrUnblock(
    BuildContext context,
    WidgetRef ref, {
    required bool isBlocked,
  }) async {
    if (isBlocked) {
      await ref.read(rakuenSettingsProvider.notifier).removeBlockUser(userId);
      return;
    }
    if (!ref.read(canActAsLoggedInProvider)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('加好友需要登录 (OAuth 或站点 Cookie)')),
        );
      }
      return;
    }
    String gh = '';
    try {
      gh = await ref.read(formhashProvider.future);
    } catch (_) {}
    if (gh.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('操作失败, 请确认已配置站点 Cookie')));
      }
      return;
    }
    try {
      final client = ref.read(apiClientProvider);
      await client.post(apiConnect(userId, gh), host: kHost);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已发送好友申请')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('申请失败, 请稍后重试')));
      }
    }
  }
}

/// 收藏 tab: 类型 + 状态 + 搜索
class _ZoneCollectionsTab extends StatefulWidget {
  final String userId;
  final String type;
  final int status;

  const _ZoneCollectionsTab({
    required this.userId,
    required this.type,
    required this.status,
  });

  @override
  State<_ZoneCollectionsTab> createState() => _ZoneCollectionsTabState();
}

class _ZoneCollectionsTabState extends State<_ZoneCollectionsTab> {
  String _query = '';
  bool _grid = false;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final async = ref.watch(
          zoneCollectionsProvider((
            userId: widget.userId,
            type: widget.type,
            status: widget.status,
          )),
        );
        return Column(
          children: [
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
                        selected: widget.type == t,
                        onSelected: (_) => ref
                            .read(zoneScreenControllerProvider.notifier)
                            .setFilter(t, widget.status),
                      ),
                    ),
                ],
              ),
            ),
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
                        selected: widget.status == s,
                        onSelected: (_) => ref
                            .read(zoneScreenControllerProvider.notifier)
                            .setFilter(widget.type, s),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 18),
                        hintText: '搜索收藏',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                  IconButton(
                    tooltip: _grid ? '列表' : '网格',
                    icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
                    onPressed: () => setState(() => _grid = !_grid),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Loading(),
                error: (_, _) => const Center(child: Text('加载失败')),
                data: (data) {
                  final q = _query.toLowerCase();
                  final filtered = q.isEmpty
                      ? data.items
                      : data.items
                            .where(
                              (e) =>
                                  e.subject.displayName.toLowerCase().contains(
                                    q,
                                  ) ||
                                  e.subject.name.toLowerCase().contains(q),
                            )
                            .toList();
                  if (filtered.isEmpty) {
                    return const Center(child: Text('暂无收藏'));
                  }
                  final store = ref.watch(settingsStoreProvider);
                  final me = ref.watch(currentUserProvider);
                  final isMe =
                      me != null &&
                      (me.username == widget.userId ||
                          '${me.id}' == widget.userId);
                  final showManage = !isMe || store.userShowManage;
                  final cols = store.userGridNum;
                  final showMore =
                      data.hasMore && q.isEmpty && !store.userPagination;
                  return Column(
                    children: [
                      Expanded(
                        child: _grid
                            ? GridView.builder(
                                padding: const EdgeInsets.all(8),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: cols,
                                      childAspectRatio: 0.62,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  return _ZoneCollectionCard(
                                    item: item,
                                    showManage: showManage,
                                    onManage: () =>
                                        _openManage(context, item.subject.id),
                                  );
                                },
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  return _ZoneCollectionRow(
                                    item: item,
                                    showManage: showManage,
                                    commentsFull: store.userCommentsFull,
                                    commentsLines: store.userCommentsLines,
                                    onManage: () =>
                                        _openManage(context, item.subject.id),
                                  );
                                },
                              ),
                      ),
                      if (showMore)
                        TextButton(
                          onPressed: () => unawaited(
                            ref
                                .read(
                                  zoneCollectionsProvider((
                                    userId: widget.userId,
                                    type: widget.type,
                                    status: widget.status,
                                  )).notifier,
                                )
                                .loadMore(),
                          ),
                          child: const Text('加载更多'),
                        )
                      else if (store.userPagination)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '已加载 ${filtered.length} / ${data.total}',
                            style: context.ds.caption,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

void _openManage(BuildContext context, int subjectId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CollectionSheet(subjectId: subjectId),
  );
}

class _ZoneCollectionCard extends StatelessWidget {
  final CollectionItem item;
  final bool showManage;
  final VoidCallback onManage;

  const _ZoneCollectionCard({
    required this.item,
    required this.showManage,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/subject/${item.subject.id}'),
      onLongPress: showManage ? onManage : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Cover(
                    url: item.subject.images.common,
                    width: double.infinity,
                    height: double.infinity,
                    radius: 6,
                    type: item.subject.type,
                  ),
                ),
                if (showManage)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '收藏管理',
                      icon: const Icon(
                        Icons.star_outline,
                        size: 18,
                        color: Colors.white,
                      ),
                      onPressed: onManage,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.subject.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: SettingsStore.instance.zoneAlignCenter
                ? TextAlign.center
                : TextAlign.start,
            style: context.ds.caption,
          ),
          if (SettingsStore.instance.userShowYear &&
              item.subject.airDate.isNotEmpty)
            Text(
              formatSubjectAirDate(
                item.subject.airDate,
                showMonth: item.subject.type == 'anime',
              ),
              textAlign: SettingsStore.instance.zoneAlignCenter
                  ? TextAlign.center
                  : TextAlign.start,
              style: context.ds.tiny,
            ),
        ],
      ),
    );
  }
}

class _ZoneAboutTab extends StatelessWidget {
  final User user;

  const _ZoneAboutTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final group = userGroupText[user.userGroup] ?? '会员';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('昵称'),
          subtitle: Text(user.displayName),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('用户名'),
          subtitle: Text(user.username.isEmpty ? '${user.id}' : user.username),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('用户组'),
          subtitle: Text(group),
        ),
        if (user.sign.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('签名'),
            subtitle: Text(user.sign),
          ),
      ],
    );
  }
}

class _ZoneCollectionRow extends StatelessWidget {
  final CollectionItem item;
  final bool showManage;
  final bool commentsFull;
  final int commentsLines;
  final VoidCallback onManage;

  const _ZoneCollectionRow({
    required this.item,
    required this.showManage,
    required this.commentsFull,
    required this.commentsLines,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final comment = item.comment.trim();
    final meta =
        '${SubjectType.statusText(item.type, item.subject.type)} · 第${item.epStatus}话';

    final commentText = comment.isEmpty
        ? null
        : Text(
            comment,
            maxLines: commentsLines,
            overflow: commentsLines >= 100
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: context.ds.caption,
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
                  width: 42,
                  height: 56,
                  type: item.subject.type,
                ),

                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.subject.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(meta, style: context.ds.caption),
                      if (!commentsFull && commentText != null) commentText,
                    ],
                  ),
                ),
                if (showManage)
                  IconButton(
                    tooltip: '收藏管理',
                    icon: const Icon(Icons.star_outline, size: 20),
                    onPressed: onManage,
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

class _ZoneStatsTab extends StatelessWidget {
  final User user;

  const _ZoneStatsTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user.username.isEmpty ? '${user.id}' : user.username;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('原版统计图表依赖云端 KV 快照, 本地用网页版等价', style: context.ds.caption),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.bar_chart_outlined),
          title: const Text('Netaba 用户统计'),
          subtitle: Text(name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(
            '/web/${Uri.encodeComponent('https://netaba.re/user/$name')}',
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.public),
          title: const Text('主站用户页'),
          onTap: () =>
              context.push('/web/${Uri.encodeComponent('$kHost/user/$name')}'),
        ),
      ],
    );
  }
}

class _ZoneTinygrailTab extends ConsumerWidget {
  final User user;

  const _ZoneTinygrailTab({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = user.username.isEmpty ? '${user.id}' : user.username;
    final async = ref.watch(zoneTinygrailAssetsProvider(name));
    return async.when(
      loading: () => const Loading(),
      error: (_, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('未找到小圣杯资产'),
            TextButton(
              onPressed: () =>
                  ref.invalidate(zoneTinygrailAssetsProvider(name)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (assets) {
        if (assets.hash.isEmpty && assets.total == 0 && assets.balance == 0) {
          return const Center(child: Text('暂无小圣杯数据'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '总资产 ${assets.total} / 现金 ${assets.balance}${assets.lastIndex > 0 ? ' / #${assets.lastIndex}' : ''}',
              style: context.ds.bodyStrong,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('查看持仓'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                '/tinygrail/tree?user=${Uri.encodeComponent(name)}',
              ),
            ),
          ],
        );
      },
    );
  }
}

final zoneTinygrailAssetsProvider =
    FutureProvider.family<TinygrailUser, String>((ref, hash) async {
      return ref.read(tinygrailApiProvider).fetchAssets(hash);
    });

class _ZoneRakuenTab extends ConsumerWidget {
  final String userId;

  const _ZoneRakuenTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mineTopicsProvider(userId));
    return async.when(
      loading: () => const Loading(),
      error: (_, _) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(mineTopicsProvider(userId)),
          child: const Text('重试'),
        ),
      ),
      data: (topics) {
        if (topics.isEmpty) return const Center(child: Text('暂无主题'));
        return ListView.separated(
          itemCount: topics.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final t = topics[i];
            return ListTile(
              title: Text(
                t.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  if (t.group?.title.isNotEmpty == true) t.group!.title,
                  if (t.replies > 0) '${t.replies} 回复',
                  if (t.displayTime.isNotEmpty) t.displayTime,
                ].join(' · '),
                style: context.ds.caption,
              ),
              onTap: () => context.push('/rakuen/topic/${t.topicId}'),
            );
          },
        );
      },
    );
  }
}
