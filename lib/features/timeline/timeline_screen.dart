import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/site_cookies.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';
import '../../core/utils/format.dart';
import '../../design_system/design_system.dart';
import '../../shared/models/timeline.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';
import '../../shared/widgets/tab_title.dart';

import '../user/user_models.dart';

/// 时间线点赞 type (原项目 LIKE_TYPE_TIMELINE)
const int kLikeTypeTimeline = 40;

/// 时间线类型 (移植自原项目 MODEL_TIMELINE_TYPE)
const kTimelineTabs = [
  ('全部', 'all'),
  ('吐槽', 'say'),
  ('收藏', 'subject'),
  ('进度', 'progress'),
  ('日志', 'blog'),
  ('人物', 'mono'),
  ('小组', 'group'),
  ('维基', 'wiki'),
  ('目录', 'index'),
];

/// 范围 (移植自原项目 TIMELINE_SCOPE: 好友/全站/自己)
const kTimelineScopes = [('friend', '好友'), ('all', '全站'), ('me', '自己')];

/// 时间线查询 (scope + type)
class TimelineQuery {
  final String scope; // friend | all | me
  final String type; // all | say | subject | ...

  const TimelineQuery(this.scope, this.type);

  @override
  bool operator ==(Object other) =>
      other is TimelineQuery && other.scope == scope && other.type == type;

  @override
  int get hashCode => Object.hash(scope, type);
}

/// 时间线数据
class TimelineData {
  final List<TimelineItem> items;
  final int page;
  final bool hasMore;

  const TimelineData({
    this.items = const [],
    this.page = 1,
    this.hasMore = true,
  });
}

final timelineProvider =
    AsyncNotifierProvider.family<TimelineNotifier, TimelineData, TimelineQuery>(
      TimelineNotifier.new,
    );

class TimelineNotifier
    extends FamilyAsyncNotifier<TimelineData, TimelineQuery> {
  @override
  Future<TimelineData> build(TimelineQuery query) async {
    return _fetch(1, query);
  }

  Future<TimelineData> _fetch(int page, TimelineQuery query) async {
    final client = ref.read(apiClientProvider);
    if (query.scope == 'me') {
      final me = ref.read(currentUserProvider);
      var userId = me == null
          ? ''
          : (me.username.isEmpty ? '${me.id}' : me.username);
      if (userId.isEmpty) {
        try {
          final html = await client.fetchHtml('$kHost/notify');
          userId = parseLoggedInUsername(html);
        } catch (_) {}
      }
      if (userId.isEmpty) return const TimelineData(hasMore: false);
      final html = await client.get(
        apiUserTimelineHtml(userId, type: query.type, page: page),
        host: kHost,
      );
      final groups = parseUserTimeline(html as String);
      final items = [for (final g in groups) ...g.items];
      return TimelineData(
        items: items,
        page: page,
        hasMore: items.length >= 20,
      );
    }

    final html = await client.get(
      htmlTimeline(type: query.type, page: page),
      host: kHost,
      skipCookies: query.scope == 'all',
    );
    final groups = parseUserTimeline(html as String);
    final items = [for (final g in groups) ...g.items];
    return TimelineData(
      items: items,
      page: page,
      hasMore: query.scope == 'all'
          ? items.isNotEmpty && page < 2
          : items.length >= 20,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(current.page + 1, arg);
      state = AsyncData(
        TimelineData(
          items: [...current.items, ...next.items],
          page: next.page,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {}
  }
}

/// 时间线 Tab (Tab 2)
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: kTimelineTabs.length,
    vsync: this,
  );
  String _scope = 'friend';

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAct = ref.watch(canActAsLoggedInProvider);
    final scopeLabel = kTimelineScopes
        .firstWhere((e) => e.$1 == _scope, orElse: () => ('friend', '好友'))
        .$2;
    return Scaffold(
      appBar: AppBar(
        title: const TabLogoTitle('时间线'),
        actions: [
          if (canAct)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '新吐槽',
              onPressed: () => context.push('/timeline/say/new'),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Row(
            children: [
              PopupMenuButton<String>(
                tooltip: '范围',
                onSelected: (v) => setState(() => _scope = v),
                itemBuilder: (_) => [
                  for (final s in kTimelineScopes)
                    PopupMenuItem(value: s.$1, child: Text(s.$2)),
                ],
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(scopeLabel, style: context.ds.label),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [for (final t in kTimelineTabs) Tab(text: t.$1)],
                ),
              ),
            ],
          ),
        ),
      ),
      body: canAct
          ? TabBarView(
              controller: _tabController,
              children: [
                for (final t in kTimelineTabs)
                  _TimelineList(query: TimelineQuery(_scope, t.$2)),
              ],
            )
          : const _TimelineLoginGate(),
    );
  }

}

class _TimelineList extends ConsumerStatefulWidget {
  final TimelineQuery query;

  const _TimelineList({required this.query});

  @override
  ConsumerState<_TimelineList> createState() => _TimelineListState();
}

class _TimelineListState extends ConsumerState<_TimelineList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(timelineProvider(widget.query).notifier).loadMore();
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
    final async = ref.watch(timelineProvider(widget.query));
    return async.when(
      loading: () => const Loading(),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '加载失败',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(timelineProvider(widget.query)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (data) {
        final store = ref.watch(settingsStoreProvider);
        final items = [
          for (final item in data.items)
            if (_keepTimelineItem(store, item)) item,
        ];

        if (items.isEmpty) {
          return const Center(child: Text('暂无动态'));
        }
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final date = _timelineDayLabel(item.createdAt);
            final prev = index == 0
                ? ''
                : _timelineDayLabel(items[index - 1].createdAt);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (date.isNotEmpty && date != prev)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Text(date, style: context.ds.section),
                  ),
                _TimelineItemView(item: item, query: widget.query),
              ],
            );
          },
        );
      },
    );
  }
}

class _TimelineItemView extends ConsumerWidget {
  final TimelineItem item;
  final TimelineQuery query;

  const _TimelineItemView({required this.item, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = item.user;
    final store = ref.watch(settingsStoreProvider);

    return InkWell(
      onTap: () {
        if (item.type == 'say' && item.id > 0) {
          context.push('/timeline/say/${item.id}');
          return;
        }
        final sid = item.subject?.id;
        if (sid != null && sid > 0) {
          if (store.timelinePopable) {
            showModalBottomSheet<void>(
              context: context,
              builder: (ctx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Cover(
                            url: item.subject!.images.common,
                            width: 56,
                            height: 76,
                            radius: 4,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.subject!.displayName,
                                  style: context.ds.title,
                                ),
                                if (!store.hideScore &&
                                    (item.subject!.rating?.score ?? 0) > 0)
                                  Text(
                                    '${item.subject!.rating!.score} 分',
                                    style: context.ds.caption.copyWith(
                                      color: context.ds.star,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          context.push('/subject/$sid');
                        },
                        child: const Text('查看条目'),
                      ),
                    ],
                  ),
                ),
              ),
            );
            return;
          }
          context.push('/subject/$sid');
        } else if (user != null) {
          context.push('/user/${user.username}');
        }
      },

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user != null)
              Avatar(
                url: user.avatarUrl,
                size: 36,
                name: user.displayName,
                userId: user.username.isEmpty ? '${user.id}' : user.username,
              ),

            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (user != null) ...[
                        Text(
                          () {
                            final remark = ref
                                .watch(settingsStoreProvider)
                                .userRemarkOf(
                                  user.username.isEmpty
                                      ? '${user.id}'
                                      : user.username,
                                );
                            return remark.isEmpty
                                ? user.displayName
                                : '[$remark]';
                          }(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        UserAgeBadge(
                          userId: user.username.isEmpty
                              ? '${user.id}'
                              : user.username,
                        ),
                      ],

                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _statusText(item),
                          style: context.ds.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        friendlyTime(item.createdAt),
                        style: context.ds.tiny,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (item.subject != null)
                    Row(
                      children: [
                        Cover(
                          url: item.subject!.images.common,
                          width: 48,
                          height: 64,
                          radius: 4,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.subject!.displayName,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (!store.hideScore &&
                                  item.subject!.rating != null &&
                                  item.subject!.rating!.score > 0)
                                Text(
                                  '${item.subject!.rating!.score}分',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.ds.star,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  if (item.status?.text != null && item.status!.text.isNotEmpty)
                    Text(
                      item.status!.text,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  if (item.content.isNotEmpty)
                    Text(
                      stripHtml(item.content),
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Row(
                    children: [
                      if (item.id > 0 && item.type == 'say')
                        TextButton.icon(
                          onPressed: () =>
                              context.push('/timeline/say/${item.id}'),
                          icon: const Icon(Icons.chat_bubble_outline, size: 16),
                          label: const Text('回复'),
                        ),
                      if (item.id > 0)
                        TextButton.icon(
                          onPressed: () => _like(context, ref),
                          icon: const Icon(Icons.thumb_up_outlined, size: 16),
                          label: const Text('贴贴'),
                        ),
                      if (item.clearHref.isNotEmpty)
                        IconButton(
                          tooltip: '删除',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _delete(context, ref),
                        )
                      else if (user != null)
                        PopupMenuButton<int>(
                          tooltip: '不看 TA',
                          icon: const Icon(Icons.more_horiz, size: 18),
                          onSelected: (days) {
                            final id = user.username.isEmpty
                                ? '${user.id}'
                                : user.username;
                            ref
                                .read(settingsStoreProvider)
                                .hideTimelineUser(id, days);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 1, child: Text('1天不看TA')),
                            PopupMenuItem(value: 3, child: Text('3天不看TA')),
                            PopupMenuItem(value: 7, child: Text('7天不看TA')),
                          ],
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
  }

  Future<void> _like(BuildContext context, WidgetRef ref) async {
    if (!ref.read(canActAsLoggedInProvider)) {
      if (context.mounted) await context.push('/login');
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
        ).showSnackBar(const SnackBar(content: Text('点赞需要站点 Cookie 登录')));
      }
      return;
    }
    try {
      final type = item.type == 'say' ? 50 : kLikeTypeTimeline;
      await ref
          .read(apiClientProvider)
          .post(
            apiLike(type, item.id, value: '赞', gh: gh),
            host: kHost,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已贴贴')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('点赞失败')));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除时间线'),
        content: const Text('确定删除这条动态?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final client = ref.read(apiClientProvider);
      var href = item.clearHref;
      if (href.startsWith('/')) href = '$kHost$href';
      if (!href.contains('ajax=1')) {
        href = href.contains('?') ? '$href&ajax=1' : '$href?ajax=1';
      }
      await client.post(href, host: kHost);
      ref.invalidate(timelineProvider(query));

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已删除')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  String _statusText(TimelineItem item) {
    final s = item.status;
    if (s == null || s.text.isEmpty) {
      return switch (item.type) {
        'say' => '发表了吐槽',
        'blog' => '发表了日志',
        'mono' => '更新了人物',
        'group' => '更新了小组',
        'wiki' => '更新了维基',
        'index' => '更新了目录',
        _ => '更新了动态',
      };
    }
    return s.text;
  }
}

String _timelineDayLabel(String createdAt) {
  if (createdAt.isEmpty) return '';
  final dt = DateTime.tryParse(createdAt.replaceFirst(' ', 'T'));
  if (dt == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (now.year == dt.year) return '${dt.month}月${dt.day}日';
  return '${dt.year}年${dt.month}月${dt.day}日';
}

bool _keepTimelineItem(SettingsStore store, TimelineItem item) {
  final user = item.user;
  if (user != null) {
    final id = user.username.isEmpty ? '${user.id}' : user.username;
    if (store.isTimelineUserHidden(id)) return false;
    if (store.filterDefault && isDefaultAvatar(user.avatarUrl)) return false;
  }
  if (store.filter18x) {
    final subject = item.subject;
    if (subject != null &&
        isSensitiveSubject(
          nsfw: subject.nsfw,
          name: subject.name,
          nameCn: subject.nameCn,
        )) {
      return false;
    }
  }
  return true;
}

class _TimelineLoginGate extends ConsumerWidget {
  const _TimelineLoginGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 48, color: context.ds.textHint),
          const SizedBox(height: 12),
          const Text('登录后查看时间线'),
          const SizedBox(height: 8),
          const Text(
            'OAuth 或站点 Cookie 均可',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('登录'),
          ),
          TextButton(
            onPressed: () => context.push('/settings/cookies'),
            child: const Text('站点 Cookie 登录'),
          ),
        ],
      ),
    );
  }
}

