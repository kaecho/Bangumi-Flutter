import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/html/bgm_html_parser.dart';
import '../../core/utils/display.dart';
import '../../core/utils/format.dart';

import '../../shared/models/timeline.dart';
import '../../shared/models/group.dart';
import '../discovery/group_screen.dart';
import '../discovery/widgets/paged.dart';

import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'html_parse.dart';
import 'rakuen_providers.dart';
import 'widgets/login_gate.dart';
import 'widgets/topic_row.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';

import '../../design_system/design_system.dart';

/// 原版 Extra SegmentedControl: 我的 / 全部
const kMineGroupTypes = <(String, String)>[('mine', '我的'), ('all', '全部')];

/// 我的 (我的主题/日志/动态)
/// 路由: /rakuen/mine
class MineScreen extends ConsumerStatefulWidget {
  const MineScreen({super.key});

  @override
  ConsumerState<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends ConsumerState<MineScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _groupType = 'mine';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = ref.watch(isLoggedInProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: BgmAppBar(
        title: '小组',
        actions: [
          if (_tabController.index == 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: BgmSegmented<String>(
                values: kMineGroupTypes,
                selected: _groupType,
                onSelect: (v) => setState(() => _groupType = v),
              ),
            ),
          BgmHeaderMore.browser(() => openExternalUrl(htmlGroupMine())),
        ],

        bottom: isLogin
            ? BgmControlledTabStrip(
                controller: _tabController,
                tabs: const [
                  Text('我的小组'),
                  Text('我的主题'),
                  Text('我的日志'),
                  Text('我的动态'),
                ],
              )
            : null,
      ),

      body: !isLogin
          ? const RakuenLoginGate(message: '登录后查看我的小组、主题、日志和动态')
          : TabBarView(
              controller: _tabController,
              children: [
                _MineGroups(type: _groupType),
                _MineTopics(uid: '${user?.id ?? 0}'),
                _MineBlogs(uid: '${user?.id ?? 0}'),
                _MineTimeline(uid: '${user?.id ?? 0}'),
              ],
            ),
    );
  }
}

/// 我的小组 (移植自原项目 rakuen/mine: 抓 /group/mine 主站 HTML)
final mineGroupsProvider = FutureProvider<List<MyGroup>>((ref) async {
  final client = ref.read(apiClientProvider);
  final html = await client.fetchHtml('$kHost/group/mine');
  return parseMyGroups(html);
});

class MyGroup {
  final String id;
  final String cover;
  final String name;
  final String num;

  const MyGroup({
    required this.id,
    required this.cover,
    required this.name,
    this.num = '',
  });
}

List<MyGroup> filterMineGroups(List<MyGroup> groups, String filter) {
  final q = filter.trim().toLowerCase();
  if (q.isEmpty) return groups;
  return [
    for (final item in groups)
      if (item.name.toLowerCase().contains(q) ||
          item.id.toLowerCase().contains(q))
        item,
  ];
}

/// 解析 /group/mine: ul.browserMedium > li.user (id/cover/name/成员数)
List<MyGroup> parseMyGroups(String html) {
  final fragment = htmlMatch(
    html,
    '<div id="columnUserSingle',
    '<div id="footer"',
  );
  if (fragment.isEmpty) return const [];
  final doc = parseDom(removeCF(fragment));
  return [
    for (final li in doc.querySelectorAll('ul.browserMedium > li.user'))
      MyGroup(
        id: matchAttr(
          li.querySelector('a.avatar'),
          'href',
          RegExp(r'/group/([^/?#]+)'),
        ),
        cover:
            li
                .querySelector('img.avatar')
                ?.attributes['src']
                ?.split('?')
                .first ??
            '',
        name: htmlDecode(cText(li.querySelector('a.avatar'))),
        num: htmlDecode(
          cText(li.querySelector('small.feed')),
        ).replaceAll(' 位成员', ''),
      ),
  ];
}

class _MineGroups extends ConsumerWidget {
  final String type;

  const _MineGroups({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (type == 'all') {
      return PagedGridView<Group, int>(
        provider: groupListProvider,
        arg: 0,
        crossAxisCount: 2,
        childAspectRatio: 1.7,
        emptyText: '暂无小组',
        itemBuilder: (context, group, index) {
          final title = group.title.isEmpty ? group.name : group.title;
          return InkWell(
            onTap: () => context.push('/rakuen/group/${group.name}'),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Cover(url: group.icon, width: 44, height: 44, radius: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (group.members > 0)
                          Text('${group.members} 位成员', style: context.ds.tiny),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
    final async = ref.watch(mineGroupsProvider);
    return async.when(
      loading: () => const Loading(),
      error: (_, _) =>
          BgmRetry(onRetry: () => ref.invalidate(mineGroupsProvider)),
      data: (groups) {
        if (groups.isEmpty) return const Center(child: Text('还没有加入小组'));
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.8,
          ),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final g = groups[index];
            return InkWell(
              onTap: () => context.push('/rakuen/group/${g.id}'),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Cover(
                    url: g.cover.replaceFirst('//', 'https://'),
                    width: 64,
                    height: 64,
                    radius: 8,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    g.name,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (g.num.isNotEmpty)
                    Text('${g.num} 位成员', style: context.ds.tiny),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MineTopics extends ConsumerWidget {
  final String uid;

  const _MineTopics({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mineTopicsProvider(uid));
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (e, _) =>
          BgmRetry(onRetry: () => ref.invalidate(mineTopicsProvider(uid))),
      data: (topics) {
        if (topics.isEmpty) return const Center(child: Text('还没有发布主题'));
        return ListView.separated(
          itemCount: topics.length,
          separatorBuilder: (_, _) => const BgmHairline(indent: 56),
          itemBuilder: (context, index) {
            final topic = topics[index];
            return RakuenTopicRow(
              topic: RakuenTopicItem(
                topicId: topic.topicId,
                title: topic.title,
                group: topic.group?.title.isNotEmpty == true
                    ? topic.group!.title
                    : (topic.group?.name ?? ''),
                userName: topic.user?.displayName ?? '',
                replies: '${topic.replies}',
                time: topic.displayTime,
              ),
            );
          },
        );
      },
    );
  }
}

class _MineBlogs extends ConsumerWidget {
  final String uid;

  const _MineBlogs({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mineBlogsProvider(uid));
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (e, _) =>
          BgmRetry(onRetry: () => ref.invalidate(mineBlogsProvider(uid))),
      data: (blogs) {
        if (blogs.isEmpty) return const Center(child: Text('还没有发布日志'));
        return ListView.separated(
          itemCount: blogs.length,
          separatorBuilder: (_, _) => const BgmHairline(indent: 16),
          itemBuilder: (context, index) {
            final blog = blogs[index];
            return InkWell(
              onTap: () => context.push('/rakuen/blog/${blog.id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            blog.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${blog.replies} 回复',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.ds.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                friendlyTime(blog.createdAt),
                                style: context.ds.tiny,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MineTimeline extends ConsumerWidget {
  final String uid;

  const _MineTimeline({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mineTimelineProvider(uid));
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (e, _) =>
          BgmRetry(onRetry: () => ref.invalidate(mineTimelineProvider(uid))),
      data: (items) {
        if (items.isEmpty) return const Center(child: Text('暂无动态'));
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const BgmHairline(indent: 56),
          itemBuilder: (context, index) => _TimelineRow(item: items[index]),
        );
      },
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final TimelineItem item;

  const _TimelineRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(
            url: item.user?.avatarUrl ?? '',
            size: 34,
            name: item.user?.displayName,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.content.isEmpty
                      ? _timelineTypeText(item.type)
                      : item.content,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${_timelineTypeText(item.type)} · ${friendlyTime(item.createdAt)}',
                  style: context.ds.tiny,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timelineTypeText(String type) => switch (type) {
    'say' => '吐槽',
    'blog' => '日志',
    'topic' => '帖子',
    'collect' => '收藏',
    'progress' => '进度',
    'relation' => '好友',
    'wiki' => '维基',
    'index' => '目录',
    _ => type,
  };
}
