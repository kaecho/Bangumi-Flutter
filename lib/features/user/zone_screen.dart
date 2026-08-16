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

import '../../features/tinygrail/tinygrail_models.dart';
import '../../shared/models/collection.dart';
import '../../shared/models/user.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';

import 'user_models.dart';
import 'user_timeline_screen.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/bgm_button.dart';

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

class ZoneCollectionsData {
  final List<CollectionItem> items;
  final int offset;
  final int total;
  final bool hasMore;
  final int pageTotal;

  const ZoneCollectionsData({
    this.items = const [],
    this.offset = 0,
    this.total = 0,
    this.hasMore = true,
    this.pageTotal = 1,
  });
}

typedef ZoneOverviewArg = ({String userId, String type});

final zoneCollectionsOverviewProvider =
    FutureProvider.family<List<ZoneCollectionSection>, ZoneOverviewArg>((
      ref,
      arg,
    ) async {
      final data = await ref
          .read(apiClientProvider)
          .get(
            apiUserCollections(arg.type, arg.userId),
            query: {'max_results': '100', 'app_id': kAppId},
          );
      return parseZoneCollectionsOverview(data);
    });

class ZoneTypeController extends Notifier<String> {
  @override
  String build() => 'anime';

  void setType(String type) => state = type;
}

final zoneTypeProvider = NotifierProvider<ZoneTypeController, String>(
  ZoneTypeController.new,
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
  late final TabController _tab = TabController(length: 6, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _selectStat(String type, int status) {
    ref.read(zoneTypeProvider.notifier).setType(type);
    _tab.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(zoneUserProvider(widget.userId));
    final type = ref.watch(zoneTypeProvider);
    final typeLabel = kUserTypeTabs
        .firstWhere((e) => e.$1 == type, orElse: () => ('anime', '动画'))
        .$2;
    return Scaffold(
      body: userAsync.when(
        loading: () => const Loading(),
        error: (_, _) => BgmRetry(
          onRetry: () => ref.invalidate(zoneUserProvider(widget.userId)),
        ),
        data: (user) => Column(
          children: [
            _ZoneHeader(
              user: user,
              userId: widget.userId,
              onStatTap: _selectStat,
            ),
            BgmControlledTabStrip(
              controller: _tab,
              scrollable: true,
              tabs: [
                const Text('关于'),
                PopupMenuButton<String>(
                  tooltip: '收藏类型',
                  onSelected: (v) =>
                      ref.read(zoneTypeProvider.notifier).setType(v),
                  itemBuilder: (_) => [
                    for (final t in kUserTypeTabs)
                      PopupMenuItem(value: t.$1, child: Text(t.$2)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('收藏 $typeLabel'),
                  ),
                ),
                const Text('统计'),
                const Text('时间线'),
                const Text('超展开'),
                const Text('小圣杯'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _ZoneAboutTab(user: user),
                  _ZoneCollectionsTab(userId: widget.userId, type: type),
                  _ZoneStatsTab(user: user),
                  UserTimelineBody(userId: widget.userId),
                  _ZoneRakuenTab(userId: widget.userId),
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
                  child: BgmHeaderAction(
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
              BgmFilterChip(
                label: '日志',
                selected: false,
                onTap: () => context.push('/user/$userId/blogs'),
              ),
              BgmFilterChip(
                label: '目录',
                selected: false,
                onTap: () => context.push('/user/$userId/catalogs'),
              ),
              BgmFilterChip(
                label: '好友',
                selected: false,
                onTap: () => context.push('/user/$userId/friends'),
              ),
              if (!isMe)
                BgmFilterChip(
                  label: '发短信',
                  selected: false,
                  onTap: () => context.push('/pm/chat/${user.id}'),
                ),
              BgmFilterChip(
                label: '浏览器查看',
                selected: false,
                onTap: () => context.push(
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
          child: BgmCard(
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
    final saved = await showBgmDialog<bool>(
      context: context,
      title: '备注',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('在页面中出现该用户，使用备注内容高亮覆盖'),
          const SizedBox(height: 8),
          BgmField(controller: controller, autofocus: true, hintText: '输入备注'),
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

/// 原版空间 MENU_DS + 加好友/绝交/报告疑虑
List<(String, String)> zoneMoreItems({required bool blocked}) => [
  ('browser', '浏览器查看'),
  ('copyLink', '复制链接'),
  ('copyShare', '复制分享'),
  ('pm', '发短信'),
  ('collect', 'TA的收藏'),
  ('friends', 'TA的好友'),
  ('revFriends', '谁加TA为好友'),
  ('characters', 'TA的人物'),
  ('connect', '加为好友'),
  if (!blocked) ('block', '绝交'),
  ('report', '报告疑虑'),
];

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
    return BgmHeaderMore(
      iconColor: Colors.white,
      items: zoneMoreItems(blocked: isBlocked),
      onSelected: (action) => _handle(context, ref, action),
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
        await context.push(
          '/character?userName=${Uri.encodeQueryComponent(username)}',
        );

      case 'connect':
        await _connectOrUnblock(context, ref, isBlocked: isBlocked);
      case 'block':
        await ref.read(rakuenSettingsProvider.notifier).addBlockUser(userId);
        if (context.mounted) {
          showBgmToast(context, '已绝交', duration: const Duration(seconds: 1));
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
        showBgmToast(context, '加好友需要登录 (OAuth 或站点 Cookie)');
      }
      return;
    }
    String gh = '';
    try {
      gh = await ref.read(formhashProvider.future);
    } catch (_) {}
    if (gh.isEmpty) {
      if (context.mounted) {
        showBgmToast(context, '操作失败, 请确认已配置站点 Cookie');
      }
      return;
    }
    try {
      final client = ref.read(apiClientProvider);
      await client.post(apiConnect(userId, gh), host: kHost);
      if (context.mounted) {
        showBgmToast(context, '已发送好友申请');
      }
    } catch (_) {
      if (context.mounted) {
        showBgmToast(context, '申请失败, 请稍后重试');
      }
    }
  }
}

/// 空间收藏概览 (原项目 zone bangumi-list: 状态分组封面, 每组最多 20)
class _ZoneCollectionsTab extends ConsumerStatefulWidget {
  final String userId;
  final String type;

  const _ZoneCollectionsTab({required this.userId, required this.type});

  @override
  ConsumerState<_ZoneCollectionsTab> createState() =>
      _ZoneCollectionsTabState();
}

class _ZoneCollectionsTabState extends ConsumerState<_ZoneCollectionsTab> {
  final _expand = <int, bool>{
    CollectionStatus.doing: true,
    CollectionStatus.collect: false,
    CollectionStatus.wish: false,
    CollectionStatus.onHold: false,
    CollectionStatus.dropped: false,
  };

  void _toggle(int status) {
    setState(() {
      if (SettingsStore.instance.zoneCollapse) {
        for (final key in _expand.keys) {
          _expand[key] = key == status ? !(_expand[key] ?? false) : false;
        }
      } else {
        _expand[status] = !(_expand[status] ?? false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      zoneCollectionsOverviewProvider((
        userId: widget.userId,
        type: widget.type,
      )),
    );
    final store = ref.watch(settingsStoreProvider);
    return async.when(
      loading: () => const Loading(),
      error: (_, _) => BgmRetry(
        onRetry: () => ref.invalidate(
          zoneCollectionsOverviewProvider((
            userId: widget.userId,
            type: widget.type,
          )),
        ),
      ),
      data: (sections) {
        if (sections.isEmpty) {
          return const Center(child: Text('暂无收藏'));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            for (final section in sections) ...[
              InkWell(
                onTap: () => _toggle(section.status),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        section.title,
                        style: context.ds.bodyStrong.copyWith(fontSize: 15),
                      ),
                      const SizedBox(width: 6),
                      Text('${section.count}', style: context.ds.caption),
                      const Spacer(),
                      Icon(
                        (_expand[section.status] ?? false)
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (_expand[section.status] ?? false)
                _ZoneCoverWrap(items: section.items.take(20).toList()),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BgmTextAction(
                  '查看TA的所有收藏',
                  onPressed: () => context.push('/user/${widget.userId}/list'),
                ),
                PopupMenuButton<String>(
                  tooltip: '空间收藏设置',
                  onSelected: (value) {
                    if (value.startsWith('collapse')) {
                      unawaited(store.setZoneCollapse(!store.zoneCollapse));
                    } else {
                      unawaited(
                        store.setZoneAlignCenter(!store.zoneAlignCenter),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    for (final item in zoneCollectionMoreItems(
                      collapse: store.zoneCollapse,
                      alignCenter: store.zoneAlignCenter,
                    ))
                      PopupMenuItem(
                        value: item.startsWith('自动') ? 'collapse' : 'align',
                        child: Text(item),
                      ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.settings, size: 16),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ZoneCoverWrap extends StatelessWidget {
  final List<ZoneCollectionCover> items;

  const _ZoneCoverWrap({required this.items});

  @override
  Widget build(BuildContext context) {
    final alignCenter = SettingsStore.instance.zoneAlignCenter;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = MediaQuery.sizeOf(context).width;
        final cols = width >= 600 ? 7 : 5;
        final itemW = (constraints.maxWidth - 8 * (cols - 1)) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: itemW,
                child: InkWell(
                  onTap: () => context.push('/subject/${item.id}'),
                  child: Column(
                    crossAxisAlignment: alignCenter
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      Cover(
                        url: item.cover,
                        width: itemW,
                        height: itemW * 1.4,
                        radius: 6,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.displayName,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: alignCenter
                            ? TextAlign.center
                            : TextAlign.start,
                        style: context.ds.tiny.copyWith(
                          fontSize: item.displayName.length > 14 ? 10 : 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
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
        BgmSettingRow(title: '昵称', subtitle: user.displayName),
        BgmSettingRow(
          title: '用户名',
          subtitle: user.username.isEmpty ? '${user.id}' : user.username,
        ),
        BgmSettingRow(title: '用户组', subtitle: group),
        if (user.sign.isNotEmpty)
          BgmSettingRow(title: '签名', subtitle: user.sign),
      ],
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
        BgmSettingRow(
          title: 'Netaba 用户统计',
          subtitle: name,
          arrow: true,
          onTap: () => context.push(
            '/web/${Uri.encodeComponent('https://netaba.re/user/$name')}',
          ),
        ),
        BgmSettingRow(
          title: '主站用户页',
          arrow: true,
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
      error: (_, _) => BgmRetry(
        message: '未找到小圣杯资产',
        onRetry: () => ref.invalidate(zoneTinygrailAssetsProvider(name)),
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
            BgmSettingRow(
              title: '查看持仓',
              arrow: true,
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
      error: (_, _) =>
          BgmRetry(onRetry: () => ref.invalidate(mineTopicsProvider(userId))),
      data: (topics) {
        if (topics.isEmpty) return const Center(child: Text('暂无主题'));
        return ListView.separated(
          itemCount: topics.length,
          separatorBuilder: (_, _) => const BgmHairline(),
          itemBuilder: (_, i) {
            final t = topics[i];
            return BgmTextRow(
              title: t.title,
              replies: t.replies,
              subtitle: [
                if (t.group?.title.isNotEmpty == true) t.group!.title,
                if (t.displayTime.isNotEmpty) t.displayTime,
              ].join(' · '),
              onTap: () => context.push('/rakuen/topic/${t.topicId}'),
            );
          },
        );
      },
    );
  }
}
