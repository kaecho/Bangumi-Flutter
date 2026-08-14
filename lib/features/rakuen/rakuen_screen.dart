import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/html/bgm_html_parser.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';
import '../../shared/widgets/tab_title.dart';

import 'rakuen_models.dart';
import 'rakuen_providers.dart';
import 'rakuen_settings.dart';

/// 超展开板块 (移植自原项目 MODEL_RAKUEN_SCOPE)
const kRakuenScopes = [
  ('全局聚合', 'topiclist'),
  ('新番乐园', 'new_bangumi'),
  ('etokei 绘时计', 'tokei'),
  ('经典动画', 'classical_bangumi'),
  ('天窗联盟', 'doujin'),
  ('1/8位面', 'pvc'),
];

/// 全局聚合类型 (MODEL_RAKUEN_TYPE)
const kRakuenTypes = [
  ('全部', ''),
  ('小组', 'group'),
  ('条目', 'subject'),
  ('热门', 'hot'),
  ('章节', 'ep'),
  ('人物', 'mono'),
];

/// 小组二级 (MODEL_RAKUEN_TYPE_GROUP)
const kRakuenGroupFilters = [
  ('全部', 'group'),
  ('已加入', 'my_group'),
  ('我发表', 'my_group&filter=topic'),
  ('我回复', 'my_group&filter=reply'),
];

/// 人物二级 (MODEL_RAKUEN_TYPE_MONO)
const kRakuenMonoFilters = [
  ('全部', 'mono'),
  ('虚拟', 'mono&filter=character'),
  ('现实', 'mono&filter=person'),
];

/// 帖子列表数据
class RakuenData {
  final List<RakuenTopicItem> topics;
  final int page;
  final bool hasMore;

  const RakuenData({
    this.topics = const [],
    this.page = 1,
    this.hasMore = true,
  });
}

class RakuenTopicItem {
  final String title;
  final String userName;
  final String userId;
  final String topicId;
  final String group;
  final String groupHref;
  final int replies;
  final String time;
  final String avatar;

  const RakuenTopicItem({
    this.title = '',
    this.userName = '',
    this.userId = '',
    this.topicId = '',
    this.group = '',
    this.groupHref = '',
    this.replies = 0,
    this.time = '',
    this.avatar = '',
  });
}

final rakuenProvider =
    AsyncNotifierProvider.family<RakuenNotifier, RakuenData, String>(
      RakuenNotifier.new,
    );

class RakuenNotifier extends FamilyAsyncNotifier<RakuenData, String> {
  @override
  Future<RakuenData> build(String key) async {
    return _fetch(1, key);
  }

  Future<RakuenData> _fetch(int page, String key) async {
    // key 格式: '{type}|{scope}', 与原项目 fetchRakuen(scope, type) 一致
    final type = key.split('|').first;
    final scope = key.split('|').last;
    final client = ref.read(apiClientProvider);
    final html = await client.fetchHtml(rakueHtmlUrl(scope, type));
    final items = parseRakuenList(html);
    return RakuenData(
      topics: [
        for (final item in items)
          RakuenTopicItem(
            title: item.title,
            userName: item.userName,
            userId: item.userId,
            topicId: item.topicId,
            group: item.group,
            groupHref: item.groupHref,
            replies: item.replyCount ?? 0,
            time: item.time,
            avatar: item.avatar,
          ),
      ],
      page: page,
      hasMore: items.length >= 30,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(current.page + 1, arg);
      state = AsyncData(
        RakuenData(
          topics: [...current.topics, ...next.topics],
          page: next.page,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {}
  }
}

/// 超展开 Tab (Tab 4)
class RakuenScreen extends ConsumerStatefulWidget {
  const RakuenScreen({super.key});

  @override
  ConsumerState<RakuenScreen> createState() => _RakuenScreenState();
}

class _RakuenScreenState extends ConsumerState<RakuenScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _typeTab = TabController(
    length: kRakuenTypes.length,
    vsync: this,
  );
  int _scopeIndex = 0;
  int _subIndex = 0;

  @override
  void initState() {
    super.initState();
    _typeTab.addListener(() {
      if (_typeTab.indexIsChanging) return;
      setState(() => _subIndex = 0);
    });
  }

  @override
  void dispose() {
    _typeTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = kRakuenScopes[_scopeIndex];
    final type = kRakuenTypes[_typeTab.index];
    final subFilters = switch (type.$2) {
      'group' => kRakuenGroupFilters,
      'mono' => kRakuenMonoFilters,
      _ => const <(String, String)>[],
    };
    if (_subIndex >= subFilters.length) _subIndex = 0;
    final typeKey = subFilters.isEmpty ? type.$2 : subFilters[_subIndex].$2;
    final key = '$typeKey|${scope.$2}';
    final extraFilter = subFilters.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const TabLogoTitle('超展开'),
        leading: IconButton(
          icon: const Icon(Icons.filter_none, size: 18),
          tooltip: '我的小组',
          onPressed: () => context.push('/rakuen/mine'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.inbox_outlined),
            tooltip: '帖子聚合',
            onPressed: () => context.push('/rakuen/history'),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (v) async {
              if (v == 'search') {
                await context.push('/rakuen/search');
                return;
              }
              if (v == 'setting') {
                await context.push('/rakuen/setting');
                return;
              }
              if (v == 'new') {
                await context.push(
                  '/web/${Uri.encodeComponent(htmlNewTopic())}',
                );
                return;
              }
              if (v == 'prefetch') {
                final data = ref.read(rakuenProvider(key)).valueOrNull;
                final ids = <String>[
                  for (final t in data?.topics ?? const <RakuenTopicItem>[])
                    t.topicId,
                ];
                if (ids.isEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('当前没有帖子')));
                  return;
                }
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('预读取未读帖子'),
                    content: Text(
                      '当前未读最多预读前 $kRakuenPrefetchCount 个, 建议在 Wi-Fi 下进行',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
                if (confirm != true || !context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('预读中...')));
                final n = await prefetchUnreadTopics(ref, ids);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(n == 0 ? '当前没有未读帖子' : '已预读 $n 个帖子')),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'search', child: Text('小组搜索')),
              PopupMenuItem(value: 'setting', child: Text('超展开设置')),
              PopupMenuItem(value: 'prefetch', child: Text('预读取未读帖子')),
              PopupMenuItem(value: 'new', child: Text('添加新讨论')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(extraFilter ? 124 : 88),
          child: Column(
            children: [
              TabBar(
                controller: _typeTab,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final t in kRakuenTypes) Tab(text: t.$1)],
              ),
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: kRakuenScopes.length,
                  itemBuilder: (context, index) {
                    final s = kRakuenScopes[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(s.$1, style: const TextStyle(fontSize: 12)),
                        selected: index == _scopeIndex,
                        onSelected: (_) => setState(() {
                          _scopeIndex = index;
                          _subIndex = 0;
                        }),
                      ),
                    );
                  },
                ),
              ),
              if (extraFilter)
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: subFilters.length,
                    itemBuilder: (context, index) {
                      final t = subFilters[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(
                            t.$1,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: index == _subIndex,
                          onSelected: (_) => setState(() => _subIndex = index),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      body: typeKey.startsWith('hot') && !ref.watch(isLoggedInProvider)
          ? const _RakuenLoginGate()
          : _RakuenTopicList(listKey: key),
    );
  }
}

class _RakuenTopicList extends ConsumerStatefulWidget {
  final String listKey;

  const _RakuenTopicList({required this.listKey});

  @override
  ConsumerState<_RakuenTopicList> createState() => _RakuenTopicListState();
}

class _RakuenTopicListState extends ConsumerState<_RakuenTopicList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(rakuenProvider(widget.listKey).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rakuenProvider(widget.listKey));
    return async.when(
      loading: () => const Loading(),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('加载失败'),
            TextButton(
              onPressed: () => ref.invalidate(rakuenProvider(widget.listKey)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (data) {
        final store = ref.watch(settingsStoreProvider);
        final topics = [
          for (final topic in data.topics)
            if (_keepRakuenTopic(store, topic)) topic,
        ];
        if (topics.isEmpty) {
          return const Center(child: Text('暂无帖子'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(rakuenProvider(widget.listKey)),
          child: ListView.separated(
            controller: _scrollController,
            itemCount: topics.length,
            separatorBuilder: (_, _) => const Divider(indent: 56),
            itemBuilder: (context, index) {
              return _TopicRow(topic: topics[index]);
            },
          ),
        );
      },
    );
  }
}

class _TopicRow extends ConsumerWidget {
  final RakuenTopicItem topic;

  const _TopicRow({required this.topic});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final history = ref.watch(
      historyProvider.select((list) {
        for (final h in list) {
          if (h.topicId == topic.topicId) return h;
        }
        return null;
      }),
    );
    final seen = history != null;
    final lastReplies = history?.replies ?? 0;
    final replyAdd = seen && topic.replies > lastReplies
        ? topic.replies - lastReplies
        : 0;
    final favored = ref.watch(
      topicFavorProvider.select(
        (list) => list.any((h) => h.topicId == topic.topicId),
      ),
    );
    final markOld = ref.watch(
      rakuenSettingsProvider.select((s) => s.markOldTopic),
    );
    final epoch = relativeToEpoch(
      topic.time,
      DateTime.now().millisecondsSinceEpoch,
    );
    final isOld =
        markOld &&
        epoch != null &&
        DateTime.now().millisecondsSinceEpoch - epoch > 90 * 86400 * 1000;
    final isBlog = topic.topicId.startsWith('blog/');
    final groupId = int.tryParse(topic.topicId.replaceFirst('group/', ''));
    final isLegacyGroup =
        topic.topicId.startsWith('group/') &&
        groupId != null &&
        groupId < 440000;

    return InkWell(
      onTap: () => context.push('/rakuen/topic/${topic.topicId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: topic.userId.isEmpty
                  ? null
                  : () => context.push('/user/${topic.userId}'),
              child: Avatar(
                url: topic.avatar.startsWith('//')
                    ? 'https:${topic.avatar}'
                    : topic.avatar,
                size: 34,
                name: topic.userName,
                userId: topic.userId,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        if (favored)
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                        TextSpan(text: topic.title),
                        if (topic.replies > 0)
                          TextSpan(
                            text: ' +${topic.replies}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: seen
                                  ? theme.hintColor
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        if (replyAdd > 0)
                          TextSpan(
                            text: ' +$replyAdd',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        if (isBlog)
                          TextSpan(
                            text: '  日志',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: theme.hintColor,
                            ),
                          ),
                        if (isLegacyGroup)
                          TextSpan(
                            text: '  旧帖',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: theme.hintColor,
                            ),
                          ),
                        if (isOld)
                          TextSpan(
                            text: ' 坟',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: theme.hintColor,
                            ),
                          ),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: visualFontSize(topic.title, const [
                        (20, 13),
                        (0, 14),
                      ]),
                      fontWeight: seen ? FontWeight.w400 : FontWeight.w600,
                      color: seen ? theme.hintColor : null,
                    ),

                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (topic.group.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            topic.group,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                topic.userName,
                                style: context.ds.meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            UserAgeBadge(userId: topic.userId),
                          ],
                        ),
                      ),
                      Text(topic.time, style: context.ds.tiny),
                    ],
                  ),
                ],
              ),
            ),
            if (topic.replies > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: Text(
                  '${topic.replies}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: seen ? FontWeight.w400 : FontWeight.w700,
                    color: seen ? theme.hintColor : theme.colorScheme.primary,
                  ),
                ),
              ),
            PopupMenuButton<String>(
              tooltip: '更多',
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (v) => _onMenu(context, ref, v),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'favor',
                  child: Text(favored ? '取消收藏' : '收藏主题'),
                ),
                if (topic.groupHref.isNotEmpty)
                  const PopupMenuItem(value: 'group', child: Text('进入小组')),
                if (topic.topicId.startsWith('subject/'))
                  const PopupMenuItem(value: 'subject', child: Text('进入条目')),
                if (topic.topicId.startsWith('prsn/') ||
                    topic.topicId.startsWith('crt/'))
                  const PopupMenuItem(value: 'mono', child: Text('进入人物')),
                if (topic.groupHref.isNotEmpty)
                  const PopupMenuItem(value: 'blockGroup', child: Text('屏蔽小组')),
                if (topic.userId.isNotEmpty)
                  const PopupMenuItem(value: 'blockUser', child: Text('屏蔽用户')),
                if (topic.userId.isNotEmpty)
                  const PopupMenuItem(value: 'disconnect', child: Text('绝交')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onMenu(BuildContext context, WidgetRef ref, String value) {
    switch (value) {
      case 'favor':
        unawaited(
          ref
              .read(topicFavorProvider.notifier)
              .toggle(
                HistoryItem(
                  topicId: topic.topicId,
                  title: topic.title,
                  group: topic.group,
                  userName: topic.userName,
                  replies: topic.replies,
                  time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                ),
              ),
        );
      case 'group':
        final name = topic.groupHref.replaceAll('/group/', '');
        if (name.isNotEmpty) context.push('/rakuen/group/$name');
      case 'subject':
        final id = topic.topicId.split('/').last;
        if (id.isNotEmpty) context.push('/subject/$id');
      case 'mono':
        final parts = topic.topicId.split('/');
        if (parts.length == 2) {
          final kind = parts.first == 'crt' ? 'character' : 'person';
          context.push('/mono/$kind/${parts.last}');
        }
      case 'blockGroup':
        final name = topic.groupHref.replaceAll('/group/', '');
        if (name.isNotEmpty) {
          unawaited(
            ref.read(rakuenSettingsProvider.notifier).addBlockGroup(name),
          );
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('已屏蔽小组 $name')));
        }
      case 'blockUser':
        if (topic.userId.isNotEmpty) {
          unawaited(
            ref
                .read(rakuenSettingsProvider.notifier)
                .addBlockUser(topic.userId),
          );
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已屏蔽该用户')));
        }
      case 'disconnect':
        if (topic.userId.isNotEmpty) {
          context.push('/user/${topic.userId}');
        }
    }
  }
}

bool _keepRakuenTopic(SettingsStore store, RakuenTopicItem topic) {
  if (store.filterDefault && isDefaultAvatar(topic.avatar)) return false;
  if (store.filter18x && isSensitiveText('${topic.title} ${topic.group}')) {
    return false;
  }
  return true;
}

class _RakuenLoginGate extends StatelessWidget {
  const _RakuenLoginGate();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 48, color: context.ds.textHint),
          const SizedBox(height: 12),
          const Text('热门需要登录后查看'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }
}
