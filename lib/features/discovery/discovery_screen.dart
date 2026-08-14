import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';
import '../../core/utils/format.dart';
import '../../shared/models/subject.dart';
import '../../shared/models/timeline.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/horizontal_mask.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/tab_title.dart';
import '../../design_system/design_system.dart';
import '../subject/collection_sheet.dart';
import 'calendar_screen.dart';
import 'channel_screen.dart';
import 'clipboard_sheet.dart';
import 'widgets/discovery_html.dart';

/// 发现页菜单项 (移植自原项目 constants/constants/data.ts MENU_MAP)
class DiscoveryMenuItem {
  final String key;
  final String name;
  final IconData icon;
  final String? route;
  final bool login;
  final String? text;

  const DiscoveryMenuItem({
    required this.key,
    required this.name,
    required this.icon,
    this.route,
    this.login = false,
    this.text,
  });
}

/// 默认菜单顺序 (与原项目一致)
const List<DiscoveryMenuItem> kDiscoveryMenus = [
  DiscoveryMenuItem(
    key: 'Rank',
    name: '排行榜',
    icon: Icons.leaderboard_outlined,
    route: '/rank',
  ),
  DiscoveryMenuItem(
    key: 'Anime',
    name: '找条目',
    icon: Icons.live_tv_outlined,
    route: '/anime',
  ),
  DiscoveryMenuItem(
    key: 'Calendar',
    name: '每日放送',
    icon: Icons.calendar_month_outlined,
    route: '/calendar',
  ),
  DiscoveryMenuItem(
    key: 'Browser',
    name: '索引',
    icon: Icons.data_usage_outlined,
    route: '/browser',
  ),
  DiscoveryMenuItem(
    key: 'Catalog',
    name: '目录',
    icon: Icons.folder_open_outlined,
    route: '/catalog',
  ),
  DiscoveryMenuItem(
    key: 'Staff',
    name: '新番',
    icon: Icons.play_circle_outline,
    route: '/staff',
  ),
  DiscoveryMenuItem(
    key: 'Tags',
    name: '标签',
    icon: Icons.bookmark_outline,
    route: '/tags',
  ),
  DiscoveryMenuItem(
    key: 'Dollars',
    name: 'Dollars',
    icon: Icons.attach_money,
    text: 'D',
    route: '/dollars',
    login: true,
  ),
  DiscoveryMenuItem(
    key: 'DiscoveryBlog',
    name: '日志',
    icon: Icons.edit_outlined,
    route: '/blogs',
  ),
  DiscoveryMenuItem(key: 'Open', name: '自定义', icon: Icons.tune),
  DiscoveryMenuItem(
    key: 'Search',
    name: '搜索',
    icon: Icons.search,
    route: '/search',
  ),
  DiscoveryMenuItem(
    key: 'Like',
    name: '猜你喜欢',
    icon: Icons.favorite_outline,
    route: '/like',
  ),
  DiscoveryMenuItem(
    key: 'Anitama',
    name: '资讯',
    icon: Icons.article_outlined,
    route: '/anitama',
  ),
  DiscoveryMenuItem(
    key: 'Series',
    name: '关联系列',
    icon: Icons.workspaces_outline,
    route: '/series',
    login: true,
  ),
  DiscoveryMenuItem(
    key: 'DiscoveryUsers',
    name: '社区项目',
    icon: Icons.whatshot_outlined,
    route: '/users',
  ),
  DiscoveryMenuItem(
    key: 'Tinygrail',
    name: '小圣杯',
    icon: Icons.emoji_events_outlined,
    route: '/tinygrail',
  ),
  DiscoveryMenuItem(
    key: 'Milestone',
    name: '照片墙',
    icon: Icons.photo_library_outlined,
    route: '/my-milestone',
  ),
  DiscoveryMenuItem(
    key: 'WordCloud',
    name: '我的词云',
    icon: Icons.cloud_outlined,
    route: '/wordcloud',
    login: true,
  ),
  DiscoveryMenuItem(
    key: 'UserTimeline',
    name: '时间线',
    icon: Icons.timeline_outlined,
    route: '/my-timeline',
    login: true,
  ),
  DiscoveryMenuItem(
    key: 'Wiki',
    name: '维基人',
    icon: Icons.people_alt_outlined,
    route: '/wiki',
  ),
  DiscoveryMenuItem(
    key: 'Yearbook',
    name: '年鉴',
    icon: Icons.auto_stories_outlined,
    route: '/yearbook',
  ),
  DiscoveryMenuItem(
    key: 'BilibiliSync',
    name: 'bilibili 同步',
    icon: Icons.sync_outlined,
    route: '/sync/bilibili',
  ),
  DiscoveryMenuItem(
    key: 'DoubanSync',
    name: '豆瓣同步',
    icon: Icons.sync_outlined,
    route: '/sync/douban',
  ),
  DiscoveryMenuItem(
    key: 'Backup',
    name: '本地备份',
    icon: Icons.inbox_outlined,
    route: '/settings/backup',
    login: true,
  ),
  DiscoveryMenuItem(
    key: 'Smb',
    name: '本地管理',
    icon: Icons.folder_outlined,
    route: '/settings/smb',
  ),
  DiscoveryMenuItem(
    key: 'Character',
    name: '我的人物',
    icon: Icons.person_outline,
    route: '/my-mono',
    login: true,
  ),
  DiscoveryMenuItem(
    key: 'Catalogs',
    name: '我的目录',
    icon: Icons.folder_special_outlined,
    route: '/my-catalogs',
    login: true,
  ),
  DiscoveryMenuItem(
    key: 'Blogs',
    name: '我的日志',
    icon: Icons.edit_note_outlined,
    route: '/my-blogs',
    login: true,
  ),
  DiscoveryMenuItem(
    key: 'Friends',
    name: '我的好友',
    icon: Icons.group_outlined,
    route: '/my-friends',
    login: true,
  ),
  DiscoveryMenuItem(key: 'Link', name: '剪贴板', icon: Icons.link_outlined),
];

/// 自定义菜单 (设置中开启的菜单 key)
///
/// 未设置时与原项目一致: 只显示到「自定义」(Open) 为止的 10 项;
/// 设置过则按自定义顺序展示。
List<DiscoveryMenuItem> getDiscoveryMenus(WidgetRef ref) {
  final custom = ref.watch(settingsStoreProvider).discoveryMenu;
  if (custom == null || custom.isEmpty) {
    final cutoff = kDiscoveryMenus.indexWhere((m) => m.key == 'Open');
    return cutoff < 0
        ? kDiscoveryMenus
        : kDiscoveryMenus.sublist(0, cutoff + 1);
  }
  final byKey = {for (final m in kDiscoveryMenus) m.key: m};
  final result = <DiscoveryMenuItem>[];
  for (final key in custom) {
    final m = byKey[key];
    if (m != null) result.add(m);
  }
  // 未在自定义列表中的新菜单追加在末尾 (与原项目一致)
  for (final m in kDiscoveryMenus) {
    if (!result.contains(m)) result.add(m);
  }
  return result;
}

/// 今日放送数据
final todayOnAirProvider = FutureProvider<List<Subject>>((ref) async {
  ref.watch(settingsStoreProvider.select((s) => s.filter18x));
  final client = ref.watch(apiClientProvider);
  final data = await client.get(apiCalendar());
  final days = (data as List)
      .map((e) => CalendarDay.fromJson(e as Map<String, dynamic>))
      .toList();
  final today =
      DateTime.now().weekday % 7; // weekday: 1=Mon..7=Sun; bgm: 0=Sun..6=Sat
  final day = days.firstWhere(
    (d) => d.weekday == today,
    orElse: () => days.first,
  );
  return [
    for (final item in day.items)
      if (!SettingsStore.instance.filter18x ||
          !isSensitiveSubject(
            nsfw: item.nsfw,
            name: item.name,
            nameCn: item.nameCn,
          ))
        item,
  ];
});

/// 本周放送按类型分组 (原项目发现页 anime/book/game/real 横滑)
final weeklyTypedOnAirProvider = FutureProvider<Map<String, List<Subject>>>((
  ref,
) async {
  ref.watch(settingsStoreProvider.select((s) => s.filter18x));
  final client = ref.watch(apiClientProvider);
  final data = await client.get(apiCalendar());
  final days = (data as List)
      .map((e) => CalendarDay.fromJson(e as Map<String, dynamic>))
      .toList();
  final map = <String, List<Subject>>{
    'anime': [],
    'book': [],
    'game': [],
    'real': [],
  };
  for (final day in days) {
    for (final item in day.items) {
      if (SettingsStore.instance.filter18x &&
          isSensitiveSubject(
            nsfw: item.nsfw,
            name: item.name,
            nameCn: item.nameCn,
          )) {
        continue;
      }
      map.putIfAbsent(item.type, () => []).add(item);
    }
  }
  return map;
});

/// 主站在线人数 (原项目 fetchOnline: 抓主站首页正则提取 online: N)

/// 主站在线人数 (原项目 fetchOnline: 抓主站首页正则提取 online: N)
final onlineUsersProvider = FutureProvider<int?>((ref) async {
  final client = ref.watch(apiClientProvider);
  try {
    final html = await client.fetchHtml('$kHost/');
    final match = RegExp(
      r'<small class="grey rr">online: (\d+)</small>',
    ).firstMatch(html);
    return match == null ? null : int.tryParse(match.group(1)!);
  } catch (_) {
    return null;
  }
});

/// 年度评选横幅 (移植自原项目 discovery/index component/award)
class _AwardBanner extends StatefulWidget {
  const _AwardBanner();

  @override
  State<_AwardBanner> createState() => _AwardBannerState();
}

class _AwardBannerState extends State<_AwardBanner> {
  bool _scrolled = false;

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (!_scrolled &&
            n is ScrollUpdateNotification &&
            n.metrics.pixels >= 20) {
          setState(() => _scrolled = true);
        }
        return false;
      },
      child: SizedBox(
        height: 92,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            AppGap.x6,
            AppGap.x5,
            0,
            AppGap.x2,
          ),
          children: [
            for (final y in [year, year - 1, year - 2])
              GestureDetector(
                onTap: () => context.push('/award/$y'),
                child: Container(
                  width: y == year ? 240 : 150,
                  margin: const EdgeInsets.only(right: AppGap.x4),
                  padding: const EdgeInsets.all(AppGap.x6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: y == year
                          ? const [Color(0xFF1A1A2E), Color(0xFF16213E)]
                          : y == year - 1
                          ? const [Color(0xFF2B1B17), Color(0xFF3D2A22)]
                          : const [Color(0xFF1B2430), Color(0xFF243044)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppGap.x5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '^_ // Bangumi $y',
                        style: context.ds.caption.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: AppGap.x3),
                      Text(
                        '$y 年度动画大赏',
                        style: context.ds.bodyStrong.copyWith(
                          color: Colors.white,
                          fontSize: y == year ? 16 : 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppGap.x2),
                      Text(
                        'open /award/$y · rank anime',
                        style: context.ds.tiny.copyWith(color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              ),
            if (_scrolled)
              GestureDetector(
                onTap: () => context.push('/yearbook'),
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.only(right: AppGap.x4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(AppGap.x5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '更多',
                        style: context.ds.bodyStrong.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '年鉴',
                        style: context.ds.bodyStrong.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 在线状态 + 今日日期 (原项目 dashboard 行)
class _OnlineStatusRow extends ConsumerWidget {
  const _OnlineStatusRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineUsersProvider);
    final now = DateTime.now();
    String week(int w) =>
        const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][w - 1];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGap.x8, AppGap.x2, AppGap.x8, 0),
      child: Row(
        children: [
          online.when(
            data: (n) => n == null
                ? const SizedBox.shrink()
                : Text('online $n', style: context.ds.caption),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const Spacer(),
          Text(
            '${now.month}月${now.day}日 ${week(now.weekday)}',
            style: context.ds.caption,
          ),
        ],
      ),
    );
  }
}

/// 发现页 (Tab 1)
class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menus = getDiscoveryMenus(ref);

    return Scaffold(
      appBar: AppBar(
        title: const TabLogoTitle('发现'),

        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: '剪贴板',
            onPressed: () => showClipboardModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '自定义菜单',
            onPressed: () => showDiscoveryMenuDialog(context, menus),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayOnAirProvider);
          ref.invalidate(onlineUsersProvider);
          ref.invalidate(weeklyTypedOnAirProvider);
        },
        child: ListView(
          padding: AppGap.listBottom,
          children: [
            const _AwardBanner(),
            GridView.count(
              crossAxisCount: ref.watch(settingsStoreProvider).discoveryMenuNum,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppGap.x4,
                vertical: AppGap.x4,
              ),
              children: [
                for (final menu in menus)
                  _MenuCell(
                    menu: menu,
                    onTap: () {
                      if (menu.login && !ref.read(isLoggedInProvider)) {
                        context.push('/login');
                        return;
                      }
                      if (menu.key == 'Open') {
                        showDiscoveryMenuDialog(context, menus);
                        return;
                      }
                      if (menu.key == 'Link') {
                        showClipboardModal(context);
                        return;
                      }
                      if (menu.route != null) context.push(menu.route!);
                    },
                  ),
              ],
            ),
            const _OnlineStatusRow(),
            if (ref.watch(settingsStoreProvider).discoveryTodayOnair) ...[
              const _TodaySection(),
              const _TypedOnAirRails(),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuCell extends StatelessWidget {
  final DiscoveryMenuItem menu;
  final VoidCallback onTap;

  const _MenuCell({required this.menu, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lAll,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.ds.accentSoft,
              borderRadius: BorderRadius.circular(AppGap.x5),
            ),
            child: menu.text != null
                ? Center(
                    child: Text(
                      menu.text!,
                      style: context.ds.display.copyWith(
                        fontSize: 18,
                        color: context.ds.accent,
                      ),
                    ),
                  )
                : Icon(menu.icon, size: 22, color: context.ds.accent),
          ),
          const SizedBox(height: AppGap.x2),
          Text(
            menu.name,
            style: context.ds.meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TodaySection extends ConsumerWidget {
  const _TodaySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayOnAirProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppGap.x7,
            AppGap.x6,
            AppGap.x7,
            AppGap.x2,
          ),
          child: Row(
            children: [
              Text(
                '今日放送 (${kWeekdayCn[DateTime.now().weekday % 7]})',
                style: context.ds.section,
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/calendar'),
                child: Text(
                  '全部',
                  style: context.ds.caption.copyWith(color: context.ds.accent),
                ),
              ),
            ],
          ),
        ),
        today.when(
          data: (subjects) => SizedBox(
            height: 170,
            child: HorizontalMask(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: AppGap.pageH,
                itemCount: subjects.length + (subjects.length > 2 ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(width: AppGap.x5),
                itemBuilder: (context, index) {
                  if (subjects.length > 2 && index == 2) {
                    return const _NowSplit();
                  }
                  final i = subjects.length > 2 && index > 2
                      ? index - 1
                      : index;
                  return _TodayCard(subject: subjects[i]);
                },
              ),
            ),
          ),

          loading: () =>
              const SizedBox(height: 170, child: Center(child: Loading())),
          error: (_, _) => const SizedBox(height: 100),
        ),
      ],
    );
  }
}

class _TodayCard extends ConsumerWidget {
  final Subject subject;

  const _TodayCard({required this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raw = ref.watch(onAirTimeProvider).valueOrNull?[subject.id] ?? '';
    final clock = raw.length >= 4
        ? '${raw.substring(0, 2)}:${raw.substring(2, 4)}'
        : '';
    final weekday = kWeekdayCn[DateTime.now().weekday % 7];
    return GestureDetector(
      onTap: () => context.push('/subject/${subject.id}'),
      onLongPress: () => showCollectionSheet(context, subject.id),

      child: SizedBox(
        width: 100,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.m),
          child: Stack(
            children: [
              Cover(
                url: subject.images.common,
                width: 100,
                height: 130,
                radius: 0,
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xCC000000)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (clock.isNotEmpty)
                      Text(
                        '$clock · $weekday',
                        style: context.ds.tiny.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    Text(
                      subject.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.ds.tiny.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypedOnAirRails extends ConsumerWidget {
  const _TypedOnAirRails();

  static const _rails = [
    ('anime', '动画'),
    ('book', '书籍'),
    ('game', '游戏'),
    ('real', '三次元'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyTypedOnAirProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (map) => Column(
        children: [
          for (final (type, title) in _rails)
            if ((map[type] ?? const <Subject>[]).isNotEmpty)
              _TypeRail(type: type, title: title, items: map[type]!),
        ],
      ),
    );
  }
}

class _TypeRail extends ConsumerWidget {
  final String type;
  final String title;
  final List<Subject> items;

  const _TypeRail({
    required this.type,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = items.first;
    final rest = items.skip(1).take(19).toList();
    final friends =
        ref.watch(channelProvider(type)).valueOrNull?.friends ??
        const <ChannelFriendItem>[];
    return Padding(
      padding: const EdgeInsets.only(top: AppGap.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppGap.x7,
              AppGap.x4,
              AppGap.x7,
              AppGap.x2,
            ),
            child: Row(
              children: [
                Expanded(child: Text(title, style: context.ds.section)),
                IconButton(
                  tooltip: '$title频道',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.navigate_next),
                  onPressed: () => context.push(
                    '/channel?type=${Uri.encodeComponent(type)}',
                  ),
                ),
              ],
            ),
          ),

          _CoverLg(subject: first, typeLabel: title),
          if (rest.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppGap.x4),
              child: SizedBox(
                height: 170,
                child: HorizontalMask(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: AppGap.pageH,
                    itemCount: rest.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppGap.x5),
                    itemBuilder: (context, index) =>
                        _CoverSm(subject: rest[index], typeLabel: title),
                  ),
                ),
              ),
            ),
          if (friends.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppGap.x3),
              child: SizedBox(
                height: title == '音乐' ? 84 : 110,
                child: HorizontalMask(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: AppGap.pageH,
                    itemCount: friends.take(12).length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppGap.x4),
                    itemBuilder: (context, index) =>
                        _FriendCover(item: friends[index], typeLabel: title),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FriendCover extends StatelessWidget {
  final ChannelFriendItem item;
  final String typeLabel;
  const _FriendCover({required this.item, required this.typeLabel});

  @override
  Widget build(BuildContext context) {
    final isMusic = typeLabel == '音乐';
    const width = 68.0;
    final height = isMusic ? width : width * 1.38;
    final hasAvatar = item.userId.isNotEmpty;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () => context.push('/subject/${item.id}'),
            onLongPress: () => showCollectionSheet(context, item.id),

            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.s),
              child: Stack(
                children: [
                  Cover(
                    url: item.cover,
                    width: width,
                    height: height,
                    radius: 0,
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0xB3000000)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: hasAvatar ? 22 : 4,
                    right: 3,
                    bottom: 3,
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.ds.tiny.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasAvatar)
            Positioned(
              left: -4,
              bottom: -1,
              child: GestureDetector(
                onTap: () => context.push('/user/${item.userId}'),
                child: Avatar(
                  url: item.avatar,
                  size: 20,
                  name: item.userName,
                  userId: item.userId,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NowSplit extends StatelessWidget {
  const _NowSplit();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 2, height: 2, color: context.ds.textHint),
          const SizedBox(height: 4),
          Text('now', style: context.ds.tiny),
          const SizedBox(height: 4),
          Container(width: 2, height: 2, color: context.ds.textHint),
        ],
      ),
    );
  }
}

class _CoverLg extends StatelessWidget {
  final Subject subject;
  final String typeLabel;

  const _CoverLg({required this.subject, required this.typeLabel});

  @override
  Widget build(BuildContext context) {
    final isMusic = typeLabel == '音乐';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppGap.x7),
      child: GestureDetector(
        onTap: () => context.push('/subject/${subject.id}'),
        onLongPress: () => showCollectionSheet(context, subject.id),

        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.m),
          child: AspectRatio(
            aspectRatio: isMusic ? 1 : 1 / 1.38,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Cover(
                  url: subject.images.large.isEmpty
                      ? subject.images.common
                      : subject.images.large,
                  width: double.infinity,
                  height: double.infinity,
                  radius: 0,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0xA3000000),
                        Color(0xD6000000),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeLabel,
                        style: context.ds.caption.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subject.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.ds.title.copyWith(
                          color: Colors.white,
                          fontSize: 22,
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
    );
  }
}

class _CoverSm extends StatelessWidget {
  final Subject subject;
  final String typeLabel;

  const _CoverSm({required this.subject, required this.typeLabel});

  @override
  Widget build(BuildContext context) {
    final isMusic = typeLabel == '音乐';
    return GestureDetector(
      onTap: () => context.push('/subject/${subject.id}'),
      onLongPress: () => showCollectionSheet(context, subject.id),

      child: SizedBox(
        width: 100,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.m),
          child: AspectRatio(
            aspectRatio: isMusic ? 1 : 100 / 130,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Cover(
                  url: subject.images.common,
                  width: 100,
                  height: isMusic ? 100 : 130,
                  radius: 0,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xCC000000)],
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeLabel,
                        maxLines: 1,
                        style: context.ds.tiny.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subject.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.ds.tiny.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
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
    );
  }
}

/// 剪贴板识别弹窗 (原项目 Link 入口): 粘贴 bgm.tv 链接 → 打开对应页面
Future<void> showClipboardModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ClipboardSheet(),
  );
}

/// 自定义菜单对话框 (原项目 Open 入口)
Future<void> showDiscoveryMenuDialog(
  BuildContext context,
  List<DiscoveryMenuItem> menus,
) {
  return showModalBottomSheet(
    context: context,
    builder: (context) => const _MenuSettingSheet(),
  );
}

class _MenuSettingSheet extends ConsumerStatefulWidget {
  const _MenuSettingSheet();

  @override
  ConsumerState<_MenuSettingSheet> createState() => _MenuSettingSheetState();
}

class _MenuSettingSheetState extends ConsumerState<_MenuSettingSheet> {
  late Set<String> _enabled = _initialEnabled(ref);

  Set<String> _initialEnabled(WidgetRef ref) {
    final custom = ref.read(settingsStoreProvider).discoveryMenu;
    if (custom != null && custom.isNotEmpty) return custom.toSet();
    return kDiscoveryMenus.map((m) => m.key).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              '自定义菜单',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Flexible(
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              padding: AppGap.pageH,
              children: [
                for (final menu in kDiscoveryMenus)
                  FilterChip(
                    label: Text(
                      menu.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: _enabled.contains(menu.key),
                    onSelected: (v) => setState(() {
                      v ? _enabled.add(menu.key) : _enabled.remove(menu.key);
                    }),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                TextButton(
                  onPressed: () async {
                    setState(
                      () =>
                          _enabled = kDiscoveryMenus.map((m) => m.key).toSet(),
                    );
                    await ref.read(settingsStoreProvider).resetDiscoveryMenu();
                  },
                  child: const Text('重置'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    await ref
                        .read(settingsStoreProvider)
                        .setDiscoveryMenu(_enabled.toList());
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('完成'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
