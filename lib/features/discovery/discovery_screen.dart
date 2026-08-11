import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/utils/format.dart';
import '../../shared/models/subject.dart';
import '../../shared/models/timeline.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';

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
  DiscoveryMenuItem(key: 'Rank', name: '排行榜', icon: Icons.leaderboard_outlined, route: '/rank'),
  DiscoveryMenuItem(key: 'Anime', name: '找条目', icon: Icons.live_tv_outlined, route: '/anime'),
  DiscoveryMenuItem(key: 'Calendar', name: '每日放送', icon: Icons.calendar_month_outlined, route: '/calendar'),
  DiscoveryMenuItem(key: 'Browser', name: '索引', icon: Icons.data_usage_outlined, route: '/browser'),
  DiscoveryMenuItem(key: 'Catalog', name: '目录', icon: Icons.folder_open_outlined, route: '/catalog'),
  DiscoveryMenuItem(key: 'Staff', name: '新番', icon: Icons.play_circle_outline, route: '/staff'),
  DiscoveryMenuItem(key: 'Tags', name: '标签', icon: Icons.bookmark_outline, route: '/tags'),
  DiscoveryMenuItem(key: 'Dollars', name: 'Dollars', icon: Icons.attach_money, text: 'D', route: '/dollars', login: true),
  DiscoveryMenuItem(key: 'DiscoveryBlog', name: '日志', icon: Icons.edit_outlined, route: '/blogs'),
  DiscoveryMenuItem(key: 'Search', name: '搜索', icon: Icons.search, route: '/search'),
  DiscoveryMenuItem(key: 'Like', name: '猜你喜欢', icon: Icons.favorite_outline, route: '/like'),
  DiscoveryMenuItem(key: 'Anitama', name: '资讯', icon: Icons.article_outlined, route: '/anitama'),
  DiscoveryMenuItem(key: 'Series', name: '关联系列', icon: Icons.workspaces_outline, route: '/series', login: true),
  DiscoveryMenuItem(key: 'DiscoveryUsers', name: '社区项目', icon: Icons.whatshot_outlined, route: '/users'),
  DiscoveryMenuItem(key: 'Tinygrail', name: '小圣杯', icon: Icons.emoji_events_outlined, route: '/tinygrail'),
  DiscoveryMenuItem(key: 'Milestone', name: '照片墙', icon: Icons.photo_library_outlined, route: '/milestone'),
  DiscoveryMenuItem(key: 'WordCloud', name: '我的词云', icon: Icons.cloud_outlined, route: '/wordcloud', login: true),
  DiscoveryMenuItem(key: 'UserTimeline', name: '时间线', icon: Icons.timeline_outlined, route: '/user-timeline', login: true),
  DiscoveryMenuItem(key: 'Wiki', name: '维基人', icon: Icons.people_alt_outlined, route: '/wiki'),
  DiscoveryMenuItem(key: 'Yearbook', name: '年鉴', icon: Icons.auto_stories_outlined, route: '/yearbook'),
  DiscoveryMenuItem(key: 'BilibiliSync', name: 'bilibili 同步', icon: Icons.sync_outlined, route: '/sync/bilibili'),
  DiscoveryMenuItem(key: 'DoubanSync', name: '豆瓣同步', icon: Icons.sync_outlined, route: '/sync/douban'),
  DiscoveryMenuItem(key: 'Backup', name: '本地备份', icon: Icons.inbox_outlined, route: '/settings/backup', login: true),
  DiscoveryMenuItem(key: 'Smb', name: '本地管理', icon: Icons.folder_outlined, route: '/settings/smb'),
  DiscoveryMenuItem(key: 'Character', name: '我的人物', icon: Icons.person_outline, route: '/my-mono', login: true),
  DiscoveryMenuItem(key: 'Catalogs', name: '我的目录', icon: Icons.folder_special_outlined, route: '/my-catalogs', login: true),
  DiscoveryMenuItem(key: 'Blogs', name: '我的日志', icon: Icons.edit_note_outlined, route: '/my-blogs', login: true),
  DiscoveryMenuItem(key: 'Friends', name: '我的好友', icon: Icons.group_outlined, route: '/my-friends', login: true),
  DiscoveryMenuItem(key: 'Link', name: '剪贴板', icon: Icons.link_outlined, route: '/link'),
];

/// 自定义菜单 (设置中开启的菜单 key; 未设置 = 全部显示)
List<DiscoveryMenuItem> getDiscoveryMenus(WidgetRef ref) {
  final custom = ref.watch(settingsStoreProvider).discoveryMenu;
  if (custom == null || custom.isEmpty) return kDiscoveryMenus;
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
  final client = ref.watch(apiClientProvider);
  final data = await client.get(apiCalendar());
  final days = (data as List).map((e) => CalendarDay.fromJson(e as Map<String, dynamic>)).toList();
  final today = DateTime.now().weekday % 7; // weekday: 1=Mon..7=Sun; bgm: 0=Sun..6=Sat
  final day = days.firstWhere((d) => d.weekday == today, orElse: () => days.first);
  return day.items;
});

/// 发现页 (Tab 1)
class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menus = getDiscoveryMenus(ref);

    return Scaffold(
      appBar: AppBar(
        title: const Text('发现'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '自定义菜单',
            onPressed: () => showDiscoveryMenuDialog(context, menus),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(todayOnAirProvider),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // 菜单宫格
            GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                for (final menu in menus)
                  _MenuCell(
                    menu: menu,
                    onTap: () {
                      if (menu.login && !ref.read(isLoggedInProvider)) {
                        context.push('/login');
                        return;
                      }
                      if (menu.route != null) context.push(menu.route!);
                    },
                  ),
              ],
            ),
            const Divider(),
            // 今日放送
            const _TodaySection(),
            const SizedBox(height: 12),
            // 每日放送入口
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('每日放送'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/calendar'),
            ),
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
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: menu.text != null
                ? Center(
                    child: Text(
                      menu.text!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  )
                : Icon(menu.icon, size: 22, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 5),
          Text(
            menu.name,
            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
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
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Row(
            children: [
              Text(
                '今日放送 (${kWeekdayCn[DateTime.now().weekday % 7]})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/calendar'),
                child: const Text('全部', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        today.when(
          data: (subjects) => SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: subjects.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final s = subjects[index];
                return _TodayCard(subject: s);
              },
            ),
          ),
          loading: () => const SizedBox(
            height: 170,
            child: Center(child: Loading()),
          ),
          error: (_, _) => const SizedBox(height: 100),
        ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  final Subject subject;

  const _TodayCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/subject/${subject.id}'),
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Cover(url: subject.images.common, width: 100, height: 130, radius: 6),
            const SizedBox(height: 4),
            Text(
              subject.displayName,
              style: const TextStyle(fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (subject.rating != null && subject.rating!.score > 0)
              Row(
                children: [
                  const Icon(Icons.star, size: 11, color: Colors.orange),
                  Text(
                    subject.rating!.score.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 10, color: Colors.orange),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 自定义菜单对话框 (原项目 Open 入口)
Future<void> showDiscoveryMenuDialog(BuildContext context, List<DiscoveryMenuItem> menus) {
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
            child: Text('自定义菜单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          Flexible(
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final menu in kDiscoveryMenus)
                  FilterChip(
                    label: Text(menu.name, style: const TextStyle(fontSize: 12)),
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
                    setState(() => _enabled = kDiscoveryMenus.map((m) => m.key).toSet());
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
