import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';
import '../../core/html/bgm_html_parser.dart';

import '../../shared/models/subject.dart';
import '../../shared/models/timeline.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/horizontal_mask.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/bgm_button.dart';

import '../../shared/widgets/menu_mark.dart';

import '../../design_system/design_system.dart';

import '../subject/collection_sheet.dart';
import 'calendar_screen.dart';
import 'channel_screen.dart';
import 'clipboard_sheet.dart';
import 'widgets/discovery_html.dart';
import 'widgets/award_banner.dart';

/// 发现页菜单项 (移植自原项目 constants/constants/data.ts MENU_MAP)
class DiscoveryMenuItem {
  final String key;
  final String name;
  final IconData icon;
  final IconData? badge;
  final String? route;
  final bool login;
  final String? text;

  const DiscoveryMenuItem({
    required this.key,
    required this.name,
    required this.icon,
    this.badge,
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
    icon: Icons.equalizer,
    route: '/rank',
  ),
  DiscoveryMenuItem(
    key: 'Anime',
    name: '找条目',
    icon: Icons.live_tv,
    route: '/anime',
  ),
  DiscoveryMenuItem(
    key: 'Calendar',
    name: '每日放送',
    icon: Icons.calendar_today,
    route: '/calendar',
  ),
  DiscoveryMenuItem(
    key: 'Browser',
    name: '索引',
    icon: Icons.data_usage,
    route: '/browser',
  ),
  DiscoveryMenuItem(
    key: 'Catalog',
    name: '目录',
    icon: Icons.folder_open,
    route: '/catalog',
  ),
  DiscoveryMenuItem(
    key: 'Staff',
    name: '新番',
    icon: Icons.local_play,
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
    icon: Icons.edit,
    route: '/blogs',
  ),
  DiscoveryMenuItem(key: 'Open', name: '自定义', icon: Icons.more_horiz),
  DiscoveryMenuItem(
    key: 'Search',
    name: '搜索',
    icon: Icons.search,
    route: '/search',
  ),
  DiscoveryMenuItem(
    key: 'Like',
    name: '猜你喜欢',
    icon: Icons.looks,
    route: '/like',
  ),
  DiscoveryMenuItem(
    key: 'Anitama',
    name: '资讯',
    icon: Icons.text_format,
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
    icon: Icons.whatshot,
    route: '/users',
  ),
  DiscoveryMenuItem(
    key: 'Tinygrail',
    name: '小圣杯',
    icon: BgmIcons.trophy,
    route: '/tinygrail',
  ),
  DiscoveryMenuItem(
    key: 'Milestone',
    name: '照片墙',
    icon: Icons.image_aspect_ratio,
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
    icon: Icons.timeline,
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
    icon: Icons.menu_book_outlined,
    route: '/yearbook',
  ),
  DiscoveryMenuItem(
    key: 'BilibiliSync',
    name: 'bilibili 同步',
    icon: Icons.sync,
    route: '/sync/bilibili',
  ),
  DiscoveryMenuItem(
    key: 'DoubanSync',
    name: '豆瓣同步',
    icon: Icons.sync,
    route: '/sync/douban',
  ),
  DiscoveryMenuItem(
    key: 'Backup',
    name: '本地备份',
    icon: Icons.inbox,
    route: '/settings/backup',
    login: true,
  ),
  DiscoveryMenuItem(
    key: 'Smb',
    name: '本地管理',
    icon: Icons.folder,
    route: '/settings/smb',
  ),
  DiscoveryMenuItem(
    key: 'Character',
    name: '我的人物',
    icon: Icons.folder,
    badge: Icons.favorite,
    route: '/my-mono',
    login: true,
  ),
  DiscoveryMenuItem(
    key: 'Catalogs',
    name: '我的目录',
    icon: Icons.folder_special,
    route: '/my-catalogs',
    login: true,
  ),
  DiscoveryMenuItem(
    key: 'Blogs',
    name: '我的日志',
    icon: Icons.folder,
    badge: Icons.edit,
    route: '/my-blogs',
    login: true,
  ),
  DiscoveryMenuItem(
    key: 'Friends',
    name: '我的好友',
    icon: Icons.folder_shared,
    route: '/my-friends',
    login: true,
  ),
  DiscoveryMenuItem(key: 'Link', name: '剪贴板', icon: Icons.link),
];

DiscoveryMenuItem? discoveryMenuByKey(String key) {
  for (final item in kDiscoveryMenus) {
    if (item.key == key) return item;
  }
  return null;
}

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

/// 发现页今日放送扁平行 (原项目 todayBangumi)
class TodayBangumiItem {
  final Subject subject;
  final int weekday;
  final String timeLocal;

  const TodayBangumiItem({
    required this.subject,
    required this.weekday,
    required this.timeLocal,
  });
}

/// 今日放送: 按当前时刻取窗口 (原项目 todayBangumi)
final todayOnAirProvider = FutureProvider<List<TodayBangumiItem>>((ref) async {
  ref.watch(settingsStoreProvider.select((s) => s.filter18x));
  final client = ref.watch(apiClientProvider);
  final data = await client.get(apiCalendar());
  final days = (data as List)
      .map((e) => CalendarDay.fromJson(e as Map<String, dynamic>))
      .toList();
  final times = await ref.watch(onAirTimeProvider.future);
  final filter18x = SettingsStore.instance.filter18x;
  final flat = <TodayBangumiItem>[];
  for (final day in days) {
    final weekday = day.weekday == 0 ? 7 : day.weekday;
    final items = <TodayBangumiItem>[];
    for (final item in day.items) {
      if (filter18x &&
          isSensitiveSubject(
            nsfw: item.nsfw,
            name: item.name,
            nameCn: item.nameCn,
          )) {
        continue;
      }
      final digits = (times[item.id] ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty || digits == '2359') continue;
      items.add(
        TodayBangumiItem(
          subject: item,
          weekday: weekday,
          timeLocal: digits.length >= 4 ? digits.substring(0, 4) : digits,
        ),
      );
    }
    items.sort(
      (a, b) =>
          airClockDigits(b.timeLocal).compareTo(airClockDigits(a.timeLocal)),
    );
    flat.addAll(items);
  }
  return todayOnAirWindow(
    items: flat.reversed.toList(),
    stampOf: (item) => item.weekday * 10000 + airClockDigits(item.timeLocal),
  );
});

/// 本周放送按类型分组 (featured 失败时的回退)
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
    'music': [],
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

/// 主站首页聚合: 今日上映文案 + 在线人数 + featuredItems
class DiscoveryHomeData {
  final String today;
  final int? online;
  final List<DiscoveryHomeItem> featured;

  const DiscoveryHomeData({
    this.today = '',
    this.online,
    this.featured = const [],
  });
}

final discoveryHomeProvider = FutureProvider<DiscoveryHomeData>((ref) async {
  final client = ref.watch(apiClientProvider);
  try {
    final html = await client.fetchHtml('$kHost/');
    final match = RegExp(
      r'<small class="grey rr">online: (\d+)</small>',
    ).firstMatch(html);
    return DiscoveryHomeData(
      today: parseDiscoveryToday(html),
      online: match == null ? null : int.tryParse(match.group(1)!),
      featured: parseDiscoveryHome(html),
    );
  } catch (_) {
    return const DiscoveryHomeData();
  }
});

/// 在线状态 + 今日上映 (原项目 dashboard)
class _OnlineStatusRow extends ConsumerWidget {
  const _OnlineStatusRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(discoveryHomeProvider).valueOrNull;
    final today = home?.today ?? '';
    final online = home?.online;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGap.x8, AppGap.x2, AppGap.x8, 0),
      child: Row(
        children: [
          if (online != null) Text('online $online', style: context.ds.caption),
          Expanded(
            child: Text(
              today,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.ds.caption,
            ),
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
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(todayOnAirProvider);
            ref.invalidate(discoveryHomeProvider);
            ref.invalidate(weeklyTypedOnAirProvider);
            ref.invalidate(onAirTimeProvider);
          },

          child: ListView(
            padding: AppGap.listBottom,
            children: [
              const AwardBanner(),
              GridView.count(
                crossAxisCount: ref
                    .watch(settingsStoreProvider)
                    .discoveryMenuNum,
                childAspectRatio: 1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppGap.x4,
                  vertical: AppGap.x2,
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
              if (ref.watch(settingsStoreProvider).discoveryTodayOnair)
                const _TodaySection(),
              const _TypedOnAirRails(),
            ],
          ),
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
    final ds = context.ds;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BgmMenuMark(icon: menu.icon, badge: menu.badge, text: menu.text),
          const SizedBox(height: 6),
          Text(
            menu.name,
            style: ds.caption.copyWith(
              color: ds.textPrimary,
              fontWeight: FontWeight.w700,
            ),
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
    return today.when(
      loading: () =>
          const SizedBox(height: 148, child: Center(child: Loading())),
      error: (_, _) => const SizedBox(height: 8),
      data: (items) {
        if (items.isEmpty) return const SizedBox(height: 8);
        return SizedBox(
          height: 148,
          child: HorizontalMask(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                AppGap.x7,
                AppGap.x4,
                AppGap.x4,
                AppGap.x2,
              ),
              itemCount: items.length + (items.length > 2 ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: AppGap.x5),
              itemBuilder: (context, index) {
                if (items.length > 2 && index == 2) {
                  return const _NowSplit();
                }
                final i = items.length > 2 && index > 2 ? index - 1 : index;
                return _TodayCard(item: items[i]);
              },
            ),
          ),
        );
      },
    );
  }
}

class _TodayCard extends StatelessWidget {
  final TodayBangumiItem item;

  const _TodayCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final subject = item.subject;
    final digits = item.timeLocal;
    final clock = digits.length >= 4
        ? '${digits.substring(0, 2)}:${digits.substring(2, 4)}'
        : '';
    final weekday = '周${weekdayShort(item.weekday)}';
    return GestureDetector(
      onTap: () => context.push('/subject/${subject.id}'),
      onLongPress: () => showCollectionSheet(context, subject.id),
      child: SizedBox(
        width: 100,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.m),
          child: AspectRatio(
            aspectRatio: 1 / 1.38,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Cover(
                  url: subject.images.common,
                  width: 100,
                  height: 138,
                  radius: 0,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
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
    ('music', '音乐'),
    ('real', '三次元'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(discoveryHomeProvider).valueOrNull?.featured;
    if (featured != null && featured.isNotEmpty) {
      return Column(
        children: [
          for (final (type, title) in _rails)
            if (featured.any((item) => item.type == type))
              _TypeRail(
                type: type,
                title: title,
                items: [
                  for (final item in featured)
                    if (item.type == type)
                      (
                        id: item.subjectId,
                        cover: item.cover,
                        title: item.title,
                        info: item.info,
                      ),
                ],
              ),
        ],
      );
    }
    final async = ref.watch(weeklyTypedOnAirProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (map) => Column(
        children: [
          for (final (type, title) in _rails)
            if ((map[type] ?? const <Subject>[]).isNotEmpty)
              _TypeRail(
                type: type,
                title: title,
                items: [
                  for (final item in map[type]!)
                    (
                      id: item.id,
                      cover: item.images.large.isEmpty
                          ? item.images.common
                          : item.images.large,
                      title: item.displayName,
                      info: '',
                    ),
                ],
              ),
        ],
      ),
    );
  }
}

class _TypeRail extends ConsumerWidget {
  final String type;
  final String title;
  final List<({int id, String cover, String title, String info})> items;

  const _TypeRail({
    required this.type,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  context.push('/channel?type=${Uri.encodeComponent(type)}'),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: context.ds.section)),
                  Icon(
                    Icons.navigate_next,
                    size: 20,
                    color: context.ds.textPrimary,
                  ),
                ],
              ),
            ),
          ),
          _CoverCard(item: first, typeLabel: title, large: true),
          if (rest.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppGap.x4),
              child: SizedBox(
                height: title == '音乐' ? 140 : 170,
                child: HorizontalMask(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: AppGap.pageH,
                    itemCount: rest.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppGap.x5),
                    itemBuilder: (context, index) =>
                        _CoverCard(item: rest[index], typeLabel: title),
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

class _CoverCard extends StatelessWidget {
  final ({int id, String cover, String title, String info}) item;
  final String typeLabel;
  final bool large;

  const _CoverCard({
    required this.item,
    required this.typeLabel,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMusic = typeLabel == '音乐';
    final info = item.info.isNotEmpty ? item.info : typeLabel;
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: AspectRatio(
        aspectRatio: isMusic ? 1 : 1 / 1.38,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Cover(
              url: item.cover,
              width: large ? double.infinity : 100,
              height: large ? double.infinity : (isMusic ? 100 : 138),
              radius: 0,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: large ? Alignment.topCenter : Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: large
                      ? const [
                          Color(0x00000000),
                          Color(0xA3000000),
                          Color(0xD6000000),
                        ]
                      : const [Color(0x00000000), Color(0xCC000000)],
                ),
              ),
            ),
            Positioned(
              left: large ? 12 : 6,
              right: large ? 12 : 6,
              bottom: large ? 12 : 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (large ? context.ds.caption : context.ds.tiny)
                        .copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (large) const SizedBox(height: 4),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: large
                        ? context.ds.title.copyWith(
                            color: Colors.white,
                            fontSize: 22,
                          )
                        : context.ds.tiny.copyWith(
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
    );
    final child = GestureDetector(
      onTap: () => context.push('/subject/${item.id}'),
      onLongPress: () => showCollectionSheet(context, item.id),
      child: large ? card : SizedBox(width: 100, child: card),
    );
    if (!large) return child;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppGap.x7),
      child: child,
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

/// 剪贴板识别弹窗 (原项目 Link 入口): 粘贴 bgm.tv 链接 → 打开对应页面
Future<void> showClipboardModal(BuildContext context) {
  return showBgmSheet<void>(
    context: context,
    builder: (_) => const ClipboardSheet(),
  );
}

/// 自定义菜单对话框 (原项目 Open 入口)
Future<void> showDiscoveryMenuDialog(
  BuildContext context,
  List<DiscoveryMenuItem> menus,
) {
  return showBgmSheet(
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
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('自定义菜单', style: context.ds.section),
          ),

          Flexible(
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              padding: AppGap.pageH,
              children: [
                for (final menu in kDiscoveryMenus)
                  BgmFilterChip(
                    label: menu.name,
                    selected: _enabled.contains(menu.key),
                    onTap: () => setState(() {
                      if (_enabled.contains(menu.key)) {
                        _enabled.remove(menu.key);
                      } else {
                        _enabled.add(menu.key);
                      }
                    }),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    setState(
                      () =>
                          _enabled = kDiscoveryMenus.map((m) => m.key).toSet(),
                    );
                    await ref.read(settingsStoreProvider).resetDiscoveryMenu();
                  },
                  child: Text(
                    '重置',
                    style: context.ds.caption.copyWith(
                      color: context.ds.accent,
                    ),
                  ),
                ),

                const Spacer(),
                BgmButton(
                  '完成',
                  expand: false,
                  onPressed: () async {
                    await ref
                        .read(settingsStoreProvider)
                        .setDiscoveryMenu(_enabled.toList());
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
