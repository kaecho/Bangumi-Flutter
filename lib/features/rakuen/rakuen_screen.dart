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
import '../../shared/widgets/bgm_button.dart';

import 'rakuen_providers.dart';
import 'rakuen_settings.dart';
import '../../shared/widgets/mesume.dart';

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

/// 原版超展开 IconMore: 小组搜索 / 超展开设置 / 添加新讨论
const kRakuenMoreItems = <(String, String)>[
  ('search', '小组搜索'),
  ('setting', '超展开设置'),
  ('new', '添加新讨论'),
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

class _RakuenScreenState extends ConsumerState<RakuenScreen> {
  int _typeIndex = 0;
  int _subIndex = 0;

  Future<void> _prefetchUnread(BuildContext context, String key) async {
    final data = ref.read(rakuenProvider(key)).valueOrNull;
    final ids = <String>[
      for (final t in data?.topics ?? const <RakuenTopicItem>[]) t.topicId,
    ];
    if (ids.isEmpty) {
      showBgmToast(context, '当前没有帖子');
      return;
    }
    final confirm = await showBgmConfirm(
      context,
      title: '预读取未读帖子',
      message: '当前未读最多预读前 $kRakuenPrefetchCount 个, 建议在 Wi-Fi 下进行',
    );
    if (confirm != true || !context.mounted) return;
    showBgmToast(context, '预读中...');
    final n = await prefetchUnreadTopics(ref, ids);
    if (!context.mounted) return;
    showBgmToast(context, n == 0 ? '当前没有未读帖子' : '已预读 $n 个帖子');
  }

  @override
  Widget build(BuildContext context) {
    final type = kRakuenTypes[_typeIndex];
    final subFilters = switch (type.$2) {
      'group' => kRakuenGroupFilters,
      'mono' => kRakuenMonoFilters,
      _ => const <(String, String)>[],
    };
    if (_subIndex >= subFilters.length) _subIndex = 0;
    final typeKey = subFilters.isEmpty ? type.$2 : subFilters[_subIndex].$2;
    // 原版默认 RAKUEN_SCOPE=全局聚合; 板块不单独占一排芯片
    final key = '$typeKey|${kRakuenScopes.first.$2}';

    return Scaffold(
      appBar: LogoHeader(
        leading: BgmHeaderAction(
          icon: const Icon(Icons.filter_none, size: 18),
          tooltip: '我的小组',
          onPressed: () => context.push('/rakuen/mine'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BgmHeaderAction(
              icon: const Icon(Icons.inbox_outlined, size: 20),
              tooltip: '帖子聚合',
              onPressed: () => context.push('/rakuen/history'),
            ),
            BgmHeaderAction(
              icon: const Icon(Icons.download_outlined, size: 18),
              tooltip: '预读取未读帖子',
              onPressed: () => _prefetchUnread(context, key),
            ),
            BgmHeaderMore(
              items: kRakuenMoreItems,
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
                }
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          BgmTabStrip(
            scrollable: true,
            index: _typeIndex,
            onSelect: (i) => setState(() {
              _typeIndex = i;
              _subIndex = 0;
            }),
            tabs: [
              for (var i = 0; i < kRakuenTypes.length; i++)
                _RakuenTabLabel(
                  title: kRakuenTypes[i].$1,
                  focused: i == _typeIndex,
                  filters: switch (kRakuenTypes[i].$2) {
                    'group' => kRakuenGroupFilters,
                    'mono' => kRakuenMonoFilters,
                    _ => const <(String, String)>[],
                  },
                  subIndex: _subIndex,
                  onSelectSub: (j) => setState(() => _subIndex = j),
                ),
            ],
          ),
          Expanded(
            child: typeKey.startsWith('hot') && !ref.watch(isLoggedInProvider)
                ? const _RakuenLoginGate()
                : _RakuenTopicList(listKey: key),
          ),
        ],
      ),
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
      error: (e, _) => BgmRetry(
        onRetry: () => ref.invalidate(rakuenProvider(widget.listKey)),
      ),

      data: (data) {
        final store = ref.watch(settingsStoreProvider);
        final rakuen = ref.watch(rakuenSettingsProvider);
        final topics = [
          for (final topic in data.topics)
            if (_keepRakuenTopic(store, topic) &&
                _keepRakuenTopicSettings(rakuen, topic))
              topic,
        ];
        if (topics.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(rakuenProvider(widget.listKey)),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 80), _RakuenEmpty()],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(rakuenProvider(widget.listKey)),
          child: ListView.separated(
            controller: _scrollController,
            itemCount: topics.length,
            separatorBuilder: (_, _) => const BgmHairline(indent: 56),
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

    final isGroup = topic.topicId.startsWith('group/');
    final isSubject = topic.topicId.startsWith('subject/');
    final isEp = topic.topicId.startsWith('ep/');
    final isMono =
        topic.topicId.startsWith('prsn/') || topic.topicId.startsWith('crt/');
    final typeLabel = isGroup
        ? '小组'
        : (isSubject || isEp)
        ? '条目'
        : '人物';
    final showUser = !isMono && !isEp;
    final showGroup = !isMono && topic.group.isNotEmpty;
    final timeText = topic.time;
    final meta = [
      if (timeText.isNotEmpty) timeText,
      if (showGroup) topic.group,
      if (showUser && topic.userName.isNotEmpty) topic.userName,
    ].join(' / ');

    return InkWell(
      onTap: () => context.push('/rakuen/topic/${topic.topicId}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
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
              child: Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
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
                                  color: Color(0xFFFFC107),
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
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              meta,
                              style: context.ds.meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showUser && topic.userId.isNotEmpty)
                            UserAgeBadge(userId: topic.userId),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 36,
              height: 36,
              child: PopupMenuButton<String>(
                tooltip: '更多',
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: Icon(
                  Icons.more_horiz,
                  size: 18,
                  color: context.ds.textSecondary,
                ),
                onSelected: (v) => _onMenu(context, ref, v),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'enter', child: Text('进入$typeLabel')),
                  if (topic.group.isNotEmpty)
                    PopupMenuItem(
                      value: 'blockType',
                      child: Text('屏蔽$typeLabel'),
                    ),
                  if (isGroup || isSubject)
                    const PopupMenuItem(value: 'disconnect', child: Text('绝交')),
                  if (topic.userId.isNotEmpty)
                    const PopupMenuItem(
                      value: 'blockUser',
                      child: Text('屏蔽用户'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onMenu(BuildContext context, WidgetRef ref, String value) {
    switch (value) {
      case 'enter':
        if (topic.topicId.startsWith('group/')) {
          final name = topic.groupHref.replaceAll('/group/', '');
          if (name.isNotEmpty) context.push('/rakuen/group/$name');
        } else if (topic.topicId.startsWith('subject/') ||
            topic.topicId.startsWith('ep/')) {
          final href = topic.groupHref.isNotEmpty
              ? topic.groupHref
              : '/${topic.topicId}';
          final id = href.replaceAll(RegExp(r'.*/subject/'), '');
          if (id.isNotEmpty) context.push('/subject/$id');
        } else {
          final parts = topic.topicId.split('/');
          if (parts.length == 2) {
            final kind = parts.first == 'crt' ? 'character' : 'person';
            context.push('/mono/$kind/${parts.last}');
          }
        }
      case 'blockType':
        if (topic.group.isNotEmpty) {
          unawaited(
            ref
                .read(rakuenSettingsProvider.notifier)
                .addBlockGroup(topic.group),
          );
          showBgmToast(context, '已屏蔽 ${topic.group}');
        }
      case 'blockUser':
        if (topic.userId.isNotEmpty) {
          unawaited(
            ref
                .read(rakuenSettingsProvider.notifier)
                .addBlockUser(topic.userId),
          );
          showBgmToast(context, '已屏蔽 ${topic.userName}');
        }
      case 'disconnect':
        if (topic.userId.isNotEmpty) {
          unawaited(_disconnect(context, ref));
        }
    }
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final ok = await showBgmConfirm(
      context,
      title: '绝交',
      message: '与 ${topic.userName} 绝交（不再看到用户的所有话题、评论、日志、私信、提醒）?',
      confirmLabel: '绝交',
    );
    if (ok != true) return;
    try {
      final client = ref.read(apiClientProvider);
      final html = await client.fetchHtml(htmlNotify());
      final gh = parseFormhash(html);
      if (gh.isEmpty) return;
      await client.get(apiDisconnect(topic.userId, gh));

      if (context.mounted) {
        showBgmToast(context, '已添加绝交');
      }
    } catch (_) {
      if (context.mounted) {
        showBgmToast(context, '添加失败, 可能授权信息过期');
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

bool _keepRakuenTopicSettings(
  RakuenSettingsState settings,
  RakuenTopicItem topic,
) {
  if (settings.blockDefaultUser && isDefaultAvatar(topic.avatar)) return false;
  if (settings.isUserBlocked(topic.userId, topic.userName)) return false;
  if (settings.isGroupBlocked(topic.group)) return false;
  if (settings.matchesKeyword(topic.title)) return false;
  return true;
}

class _RakuenTabLabel extends StatelessWidget {
  final String title;
  final bool focused;
  final List<(String, String)> filters;
  final int subIndex;
  final ValueChanged<int> onSelectSub;

  const _RakuenTabLabel({
    required this.title,
    required this.focused,
    required this.filters,
    required this.subIndex,
    required this.onSelectSub,
  });

  @override
  Widget build(BuildContext context) {
    final style = context.ds.label.copyWith(
      fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
    );
    if (!focused || filters.isEmpty) {
      return Text(title, style: style);
    }
    final current = filters[subIndex.clamp(0, filters.length - 1)].$1;
    return PopupMenuButton<int>(
      tooltip: title,
      padding: EdgeInsets.zero,
      onSelected: onSelectSub,
      itemBuilder: (_) => [
        for (var i = 0; i < filters.length; i++)
          PopupMenuItem(value: i, child: Text(filters[i].$1)),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: style),
          const SizedBox(width: 2),
          Text(
            current,
            style: context.ds.tiny.copyWith(color: context.ds.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RakuenEmpty extends StatelessWidget {
  const _RakuenEmpty();

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
            speech ? randomMesumeSpeech() : '暂无帖子',
            style: context.ds.caption.copyWith(fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RakuenLoginGate extends StatelessWidget {
  const _RakuenLoginGate();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Mesume(size: 80),
          const SizedBox(height: 12),
          Text(
            '热门帖子需登录才能显示',
            style: context.ds.caption.copyWith(fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          BgmButton(
            '去登录',
            expand: false,
            onPressed: () => context.push('/login'),
          ),
        ],
      ),
    );
  }
}
