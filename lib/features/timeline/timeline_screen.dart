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
import '../../shared/models/timeline.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';
import '../../shared/widgets/tab_title.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/likes_grid.dart';

import '../../shared/widgets/mesume.dart';

import '../user/user_models.dart';


/// 时间线类型 (移植自原项目 MODEL_TIMELINE_TYPE)
const kTimelineTabs = [
  ('全部', 'all'),
  ('吐槽', 'say'),
  ('收藏', 'subject'),
  ('进度', 'progress'),
  ('日志', 'blog'),
  ('人物', 'mono'),
  ('好友', 'relation'),
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

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  int _type = 0;
  String _scope = 'friend';

  @override
  Widget build(BuildContext context) {
    final canAct = ref.watch(canActAsLoggedInProvider);
    return Scaffold(
      appBar: LogoHeader(
        trailing: BgmHeaderAction(
          icon: const Icon(Icons.add),
          tooltip: '新吐槽',
          onPressed: () {
            if (!canAct) {
              showBgmToast(context, '请先登录');
              return;
            }
            context.push('/timeline/say/new');
          },
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 42,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 9, 8, 9),
                  child: BgmSelect<String>(
                    value: _scope,
                    items: kTimelineScopes,
                    onChanged: (v) => setState(() => _scope = v),
                  ),
                ),
                Expanded(
                  child: BgmTabStrip(
                    scrollable: true,
                    index: _type,
                    onSelect: (i) => setState(() => _type = i),
                    tabs: [for (final t in kTimelineTabs) Text(t.$1)],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _TimelineList(
              query: TimelineQuery(_scope, kTimelineTabs[_type].$2),
            ),
          ),
        ],
      ),
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
    final canAct = ref.watch(canActAsLoggedInProvider);
    if (!canAct &&
        (widget.query.scope == 'friend' || widget.query.scope == 'me')) {
      return const _TimelineLoginGate();
    }
    final async = ref.watch(timelineProvider(widget.query));
    return async.when(
      loading: () => const Loading(),
      error: (e, _) => BgmRetry(
        onRetry: () => ref.invalidate(timelineProvider(widget.query)),
      ),
      data: (data) {
        final store = ref.watch(settingsStoreProvider);
        final items = [
          for (final item in data.items)
            if (_keepTimelineItem(store, item)) item,
        ];

        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(timelineProvider(widget.query)),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 80), _TimelineEmpty()],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(timelineProvider(widget.query)),
          child: ListView.builder(
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
          ),
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
    final user = item.user;
    final store = ref.watch(settingsStoreProvider);
    final hideAvatar = query.scope == 'me';
    final userId = user == null
        ? ''
        : (user.username.isEmpty ? '${user.id}' : user.username);
    final remark = user == null ? '' : store.userRemarkOf(userId);
    final name = user == null
        ? ''
        : (remark.isEmpty ? user.displayName : '[$remark]');

    return InkWell(
      onTap: () => _open(context, store),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hideAvatar && user != null)
              Avatar(
                url: user.avatarUrl,
                size: 36,
                name: user.displayName,
                userId: userId,
              )
            else
              const SizedBox(width: 36),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              if (item.content.isEmpty) ...[
                                if (name.isNotEmpty)
                                  TextSpan(
                                    text: name,
                                    style: context.ds.bodyStrong.copyWith(
                                      fontSize: 13,
                                    ),
                                  ),
                                if (user != null)
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: UserAgeBadge(userId: userId),
                                  ),
                                if (name.isNotEmpty) const TextSpan(text: ' '),
                                TextSpan(
                                  text: _statusText(item),
                                  style: context.ds.caption,
                                ),
                              ] else
                                TextSpan(
                                  text: stripHtml(item.content),
                                  style: context.ds.body,
                                ),
                            ],
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.subject != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            item.subject!.displayName,
                            style: context.ds.bodyStrong.copyWith(fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!store.hideScore &&
                              (item.subject!.rating?.score ?? 0) > 0)
                            Text(
                              '${item.subject!.rating!.score}分',
                              style: context.ds.tiny.copyWith(
                                color: context.ds.star,
                              ),
                            ),
                        ],

                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (item.id > 0 && item.type == 'say') ...[
                              GestureDetector(
                                onTap: () =>
                                    context.push('/timeline/say/${item.id}'),
                                child: Text(
                                  '回复',
                                  style: context.ds.caption.copyWith(
                                    color: context.ds.accent,
                                  ),
                                ),
                              ),
                              Text(' · ', style: context.ds.caption),
                            ],
                            if (item.id > 0) ...[
                              GestureDetector(
                                onTap: () => showLikesGrid(
                                  context: context,
                                  ref: ref,
                                  likeType: item.likeType == 0
                                      ? (item.type == 'say'
                                            ? kLikeTypeSay
                                            : kLikeTypeTimeline)
                                      : item.likeType,
                                  mainId: item.id,
                                  relatedId: item.relatedId > 0
                                      ? item.relatedId
                                      : item.id,
                                ),
                                child: Text(
                                  '贴贴',
                                  style: context.ds.caption.copyWith(
                                    color: context.ds.accent,
                                  ),
                                ),
                              ),
                              Text(' · ', style: context.ds.caption),
                            ],
                            Expanded(
                              child: Text(
                                friendlyTime(item.createdAt),
                                style: context.ds.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (item.subject != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Cover(
                        url: item.subject!.images.common,
                        width: 48,
                        height: 64,
                        radius: 4,
                      ),
                    ),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: item.clearHref.isNotEmpty
                        ? GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _delete(context, ref),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: context.ds.textSecondary,
                            ),
                          )
                        : user == null
                        ? null
                        : PopupMenuButton<int>(
                            tooltip: '不看 TA',
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            icon: Icon(
                              Icons.more_horiz,
                              size: 18,
                              color: context.ds.textSecondary,
                            ),

                            onSelected: (days) {
                              ref
                                  .read(settingsStoreProvider)
                                  .hideTimelineUser(userId, days);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 1, child: Text('1天不看TA')),
                              PopupMenuItem(value: 3, child: Text('3天不看TA')),
                              PopupMenuItem(value: 7, child: Text('7天不看TA')),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, SettingsStore store) {
    if (item.type == 'say' && item.id > 0) {
      context.push('/timeline/say/${item.id}');
      return;
    }
    final sid = item.subject?.id;
    if (sid != null && sid > 0) {
      if (store.timelinePopable) {
        showBgmSheet<void>(
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
                  BgmButton(
                    '查看条目',
                    expand: false,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.push('/subject/$sid');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
        return;
      }
      context.push('/subject/$sid');
    } else if (item.user != null) {
      context.push('/user/${item.user!.username}');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showBgmConfirm(
      context,
      title: '删除时间线',
      message: '确定删除这条动态?',
      confirmLabel: '删除',
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
        showBgmToast(context, '已删除');
      }
    } catch (e) {
      if (context.mounted) {
        showBgmToast(context, '删除失败: $e');
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

class _TimelineEmpty extends StatelessWidget {
  const _TimelineEmpty();

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
            speech ? randomMesumeSpeech() : '暂无动态',
            style: context.ds.caption.copyWith(fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TimelineLoginGate extends StatelessWidget {
  const _TimelineLoginGate();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: BgmButton(
        '重新登录',
        expand: false,
        onPressed: () => context.push('/login'),
      ),
    );
  }
}
