import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/site_cookies.dart';
import '../../core/html/bgm_html_parser.dart' as core;
import '../../core/utils/display.dart';
import '../../shared/models/user.dart';
import '../../shared/widgets/bgm_html.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';
import '../user/friends_screen.dart';
import 'html_parse.dart';
import 'rakuen_models.dart';
import 'rakuen_providers.dart';
import 'rakuen_settings.dart';
import 'widgets/fixed_textarea.dart';
import 'widgets/floor_view.dart';
import '../subject/subject_providers.dart';
import '../../design_system/design_system.dart';
import '../../shared/models/ep.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';

String _userPathId(User user) =>
    user.username.isEmpty ? '${user.id}' : user.username;

/// 原版帖子 Menu: 帖子 · id / 网页版查看 / 复制链接 / 复制分享 / 举报
List<(String, String)> topicMoreItems(String topicId) => [
  ('id:$topicId', '帖子 · $topicId'),
  ('spa', '网页版查看'),
  ('copy', '复制链接'),
  ('share', '复制分享'),
  ('report', '举报'),
];

String _topicSpaUrl(String topicId) =>
    'https://bangumi-app.5t5.top/iframe.html?id=screens-topic--topic'
    '&viewMode=story&topicId=${Uri.encodeQueryComponent(topicId)}';

/// 帖子详情 (超展开核心页面)
/// 路由: /rakuen/topic/:type/:id  (type: group|subject|ep|prsn|crt)
class TopicScreen extends ConsumerStatefulWidget {
  final String type;
  final String id;

  const TopicScreen({super.key, required this.type, required this.id});

  String get topicId => '$type/$id';

  @override
  ConsumerState<TopicScreen> createState() => _TopicScreenState();
}

enum _FloorFilter { all, follow, me, friends, likes }

class _TopicScreenState extends ConsumerState<TopicScreen> {
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();
  final _expandedSubs = <String>{};
  final _expandedHtml = <String>{};
  String? _visibleLongFloorId;
  _FloorFilter _filter = _FloorFilter.all;
  bool _reverse = false;
  bool _sending = false;
  ReplyTarget? _replyTarget;

  String get _topicId => widget.topicId;

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    var text = _replyController.text.trim();
    if (text.isEmpty) return;
    if (!ref.read(canActAsLoggedInProvider)) {
      await context.push('/login');
      return;
    }
    final data = ref.read(topicDetailProvider(_topicId)).valueOrNull;
    if (data != null && (data.close.isNotEmpty || data.tip.contains('半公开'))) {
      if (mounted) {
        showBgmToast(context, data.close.isNotEmpty ? data.close : data.tip);
      }
      return;
    }
    setState(() => _sending = true);
    try {
      var gh = data?.formhash ?? '';
      if (gh.isEmpty) {
        try {
          gh = await ref.read(formhashProvider.future);
        } catch (_) {}
      }
      if (gh.isEmpty) {
        if (mounted) {
          showBgmToast(context, '回帖需要站点 Cookie 登录');
        }
        return;
      }
      final target = _replyTarget;
      if (target != null && target.messageHtml.isNotEmpty) {
        text = quoteReplyContent(
          userName: target.userName,
          messageHtml: target.messageHtml,
          content: text,
        );
      }
      final parsed = target == null ? null : parseReplySub(target.replySub);
      final lastview = data?.lastview.isNotEmpty == true
          ? data!.lastview
          : '${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
      await ref
          .read(apiClientProvider)
          .post(
            htmlTopicReply(_topicId),
            host: kHost,
            form: true,
            data: {
              'content': text,
              'formhash': gh,
              'related_photo': 0,
              'lastview': lastview,
              'submit': 'submit',
              if (parsed != null) ...{
                'related': parsed.related,
                'sub_reply_uid': parsed.subReplyUid,
                'post_uid': parsed.postUid,
              },
            },
          );
      _replyController.clear();
      if (mounted) setState(() => _replyTarget = null);

      if (mounted) {
        showBgmToast(context, '回复成功');
      }
      ref.invalidate(topicDetailProvider(_topicId));
    } catch (e) {
      if (mounted) {
        showBgmToast(context, '回复失败: ${apiErrorMessage(e)}');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _jumpFloor(int direction) {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final settings = ref.read(rakuenSettingsProvider);
    final delta = pos.viewportDimension * 0.85 * direction;
    final target = (pos.pixels + delta).clamp(0.0, pos.maxScrollExtent);
    if (settings.sliderAnimated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }


  @override
  Widget build(BuildContext context) {
    final async = ref.watch(topicDetailProvider(_topicId));
    final settings = ref.watch(rakuenSettingsProvider);

    return Scaffold(
      appBar: BgmAppBar(
        title: async.valueOrNull?.title.isNotEmpty == true
            ? async.valueOrNull!.title
            : '帖子',
        actions: [
          if (async.valueOrNull != null)
            BgmHeaderAction(
              tooltip:
                  ref
                      .watch(topicFavorProvider)
                      .any((e) => e.topicId == _topicId)
                  ? '取消收藏'
                  : '收藏主题',
              icon: Icon(
                ref.watch(topicFavorProvider).any((e) => e.topicId == _topicId)
                    ? Icons.star
                    : Icons.star_border,
                size: 20,
              ),
              onPressed: () {
                final data = async.valueOrNull;
                if (data == null) return;
                unawaited(
                  ref
                      .read(topicFavorProvider.notifier)
                      .toggle(
                        HistoryItem(
                          topicId: _topicId,
                          title: data.title,
                          group: data.group,
                          userName: data.userName,
                          replies: data.floors.length,
                          time: DateTime.now().millisecondsSinceEpoch,
                        ),
                      ),
                );
              },
            ),
          BgmHeaderMore(
            items: topicMoreItems(_topicId),
            onSelected: (v) {
              final url = htmlTopicPage(_topicId);
              final title = async.valueOrNull?.title ?? '帖子';
              if (v.startsWith('id:')) {
                openExternalUrl(url);
                return;
              }
              if (v == 'spa') {
                openExternalUrl(_topicSpaUrl(_topicId));
                return;
              }
              if (v == 'copy') {
                Clipboard.setData(ClipboardData(text: url));
                showBgmToast(context, '已复制链接');
                return;
              }
              if (v == 'share') {
                Clipboard.setData(
                  ClipboardData(text: '【链接】$title | Bangumi番组计划\n$url'),
                );
                showBgmToast(context, '已复制分享文案');
                return;
              }
              if (v == 'report') {
                openExternalUrl('$kHost/group/forum');
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: async.when(
              loading: () => const Loading(height: double.infinity),
              error: (e, _) => BgmRetry(
                onRetry: () => ref.invalidate(topicDetailProvider(_topicId)),
              ),
              data: (data) => _TopicBody(
                data: data,
                topicId: _topicId,
                settings: settings,
                filter: _filter,
                reverse: _reverse,
                expandedSubs: _expandedSubs,
                expandedHtml: _expandedHtml,
                scrollController: _scrollController,
                onFilter: (v) => setState(() => _filter = v),
                onReverse: () => setState(() => _reverse = !_reverse),
                onExpandFloor: (id) => setState(() {
                  if (!_expandedSubs.remove(id)) _expandedSubs.add(id);
                  _visibleLongFloorId = _expandedSubs.contains(id) ? id : null;
                }),
                onHtmlToggle: (id) => setState(() {
                  if (!_expandedHtml.remove(id)) {
                    _expandedHtml.add(id);
                    _visibleLongFloorId = id;
                  } else if (_visibleLongFloorId == id) {
                    _visibleLongFloorId = _expandedHtml.isEmpty
                        ? null
                        : _expandedHtml.last;
                  }
                }),
                onReply: (target) {
                  setState(() => _replyTarget = target);
                  final prefix = '@${target.userName} ';
                  if (!_replyController.text.startsWith(prefix)) {
                    _replyController.text = prefix + _replyController.text;
                    _replyController.selection = TextSelection.collapsed(
                      offset: _replyController.text.length,
                    );
                  }
                },
                onLoadMore: () =>
                    ref.read(topicDetailProvider(_topicId).notifier).loadMore(),
              ),
            ),
          ),
          if (settings.scrollDirection == 'left' ||
              settings.scrollDirection == 'right')
            Align(
              alignment: settings.scrollDirection == 'left'
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 80, bottom: 80),
                child: Material(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BgmHeaderAction(
                        tooltip: '上一楼',
                        onPressed: () => _jumpFloor(-1),
                        icon: const Icon(Icons.keyboard_arrow_up),
                      ),
                      BgmHeaderAction(
                        tooltip: '下一楼',
                        onPressed: () => _jumpFloor(1),
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (settings.showFixedToggleFloorBtn &&
              _visibleLongFloorId != null &&
              _expandedSubs.contains(_visibleLongFloorId))
            Positioned(
              right: 16,
              bottom: 16,
              child: BgmButton(
                '收起楼层',
                expand: false,
                onPressed: () => setState(() {
                  final id = _visibleLongFloorId;
                  if (id != null) _expandedSubs.remove(id);
                  _visibleLongFloorId = null;
                }),
              ),
            ),
        ],
      ),
      bottomNavigationBar: () {
        final page = async.valueOrNull;
        if (page != null && page.tip.contains('半公开')) {
          final href = page.groupHref;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                children: [
                  const Text('半公开小组只有成员才能发言, '),
                  GestureDetector(
                    onTap: () {
                      if (href.isEmpty) return;
                      if (href.contains('/group/')) {
                        final name = href
                            .replaceAll('/group/', '')
                            .split('/')
                            .first;
                        if (name.isNotEmpty) {
                          context.push('/rakuen/group/$name');
                          return;
                        }
                      }
                      openExternalUrl(
                        href.startsWith('http') ? href : '$kHost$href',
                      );
                    },
                    child: Text(
                      '点击加入',
                      style: TextStyle(color: context.ds.accent),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (page != null && page.close.isNotEmpty) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: '主题已被关闭'),
                    TextSpan(
                      text: ': ${page.close}',
                      style: context.ds.caption,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return FixedTextarea(
          controller: _replyController,
          sending: _sending,
          loggedIn: ref.watch(canActAsLoggedInProvider),
          target: _replyTarget,
          historyKey: 'topic_reply_$_topicId',
          onSend: _sendReply,
          onLogin: () => context.push('/login'),
          onClearTarget: () => setState(() => _replyTarget = null),
          leading: settings.scrollDirection == 'bottom'
              ? [
                  BgmHeaderAction(
                    tooltip: '上一楼',
                    onPressed: () => _jumpFloor(-1),
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  BgmHeaderAction(
                    tooltip: '下一楼',
                    onPressed: () => _jumpFloor(1),
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                ]
              : const [],
        );
      }(),
    );
  }
}

class _TopicBody extends ConsumerWidget {
  final TopicPageData data;
  final String topicId;
  final RakuenSettingsState settings;
  final _FloorFilter filter;
  final bool reverse;
  final Set<String> expandedSubs;
  final Set<String> expandedHtml;
  final ScrollController scrollController;
  final ValueChanged<_FloorFilter> onFilter;
  final VoidCallback onReverse;
  final ValueChanged<String> onExpandFloor;
  final ValueChanged<String> onHtmlToggle;
  final ValueChanged<ReplyTarget> onReply;
  final VoidCallback onLoadMore;

  const _TopicBody({
    required this.data,
    required this.topicId,
    required this.settings,
    required this.filter,
    required this.reverse,
    required this.expandedSubs,
    required this.expandedHtml,
    required this.scrollController,
    required this.onFilter,
    required this.onReverse,
    required this.onExpandFloor,
    required this.onHtmlToggle,
    required this.onReply,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider);
    final meId = me == null ? '' : (me.id == 0 ? me.username : '${me.id}');
    final followCount = data.floors
        .where(
          (f) =>
              settings.isTracked(f.userId) ||
              f.subReplies.any((s) => settings.isTracked(s.userId)),
        )
        .length;
    final meCount = me == null
        ? 0
        : data.floors
              .where(
                (f) =>
                    f.userId == meId ||
                    f.userId == me.username ||
                    f.subReplies.any(
                      (s) => s.userId == meId || s.userId == me.username,
                    ),
              )
              .length;

    final friendIds = me == null
        ? const <String>{}
        : {
            for (final f
                in ref
                        .watch(userFriendsProvider(_userPathId(me)))
                        .valueOrNull ??
                    const [])
              f.userId,
          };
    final friendCount = friendIds.isEmpty
        ? 0
        : data.floors
              .where(
                (f) =>
                    friendIds.contains(f.userId) ||
                    f.subReplies.any((s) => friendIds.contains(s.userId)),
              )
              .length;
    final likeCount = settings.likes
        ? data.floors.where((f) => f.likes > 0).length
        : 0;

    var floors = List<core.RakuenFloor>.from(data.floors);
    switch (filter) {
      case _FloorFilter.follow:
        floors = floors
            .where(
              (f) =>
                  settings.isTracked(f.userId) ||
                  f.subReplies.any((s) => settings.isTracked(s.userId)),
            )
            .toList();
      case _FloorFilter.me:
        if (me != null) {
          floors = floors
              .where(
                (f) =>
                    f.userId == meId ||
                    f.userId == me.username ||
                    f.subReplies.any(
                      (s) => s.userId == meId || s.userId == me.username,
                    ),
              )
              .toList();
        }
      case _FloorFilter.friends:
        floors = floors
            .where(
              (f) =>
                  friendIds.contains(f.userId) ||
                  f.subReplies.any((s) => friendIds.contains(s.userId)),
            )
            .toList();
      case _FloorFilter.likes:
        floors = floors.where((f) => f.likes > 0).toList();
      case _FloorFilter.all:
        break;
    }
    if (reverse) floors = floors.reversed.toList();

    final oldTopic = settings.markOldTopic && _isOld(data.time);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        // 标题 + 元信息 + 主楼
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.group.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _openGroup(context, data),
                          child: Row(
                            children: [
                              Cover(
                                url: data.groupThumb,
                                width: topicId.startsWith('ep/') ? 40 : 20,
                                height: topicId.startsWith('ep/') ? 40 : 20,
                                radius: 5,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  data.group,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.primary,
                                  ),
                                  maxLines: topicId.startsWith('ep/') ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (data.time.isNotEmpty)
                        Text(data.time, style: context.ds.caption),
                    ],
                  ),
                ),
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: data.userId.isEmpty
                    ? null
                    : () => context.push('/user/${data.userId}'),
                child: Row(
                  children: [
                    Avatar(
                      url: data.avatar,
                      size: 40,
                      name: data.userName,
                      userId: data.userId,
                    ),

                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayText(
                                    data.userName.isEmpty
                                        ? '匿名'
                                        : data.userName,
                                  ),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              UserAgeBadge(userId: data.userId),
                            ],
                          ),
                          Text(
                            data.userId.isEmpty ? '' : '@${data.userId}',
                            style: context.ds.tiny,
                          ),
                        ],
                      ),
                    ),

                    Text('${data.floors.length + 1} 楼', style: context.ds.meta),
                  ],
                ),
              ),

              if (oldTopic)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '坟贴提醒: 该主题已经很久没有新回复',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              if (data.contentHtml.isNotEmpty) ...[
                const SizedBox(height: 10),
                BgmHtml(
                  data: data.contentHtml,
                  showImages: settings.loadImages,
                ),
              ],
              _TopicEpNav(topicId: topicId, groupHref: data.groupHref),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: '吐槽 ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (data.floors.isNotEmpty)
                      TextSpan(
                        text: '${data.floors.fold<int>(0, (n, f) => n + 1 + f.subReplies.length)}',
                        style: context.ds.caption,
                      ),
                  ],
                ),
              ),
              const Spacer(),
              if (followCount > 0 || meCount > 0 || friendCount > 0 || likeCount > 0)
                Flexible(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    children: [
                      BgmFilterChip(
                        label: '全部',
                        selected: filter == _FloorFilter.all,
                        onTap: () => onFilter(_FloorFilter.all),
                      ),
                      if (followCount > 0)
                        BgmFilterChip(
                          label: '关注 $followCount',
                          selected: filter == _FloorFilter.follow,
                          onTap: () => onFilter(_FloorFilter.follow),
                        ),
                      if (meCount > 0)
                        BgmFilterChip(
                          label: '我 $meCount',
                          selected: filter == _FloorFilter.me,
                          onTap: () => onFilter(_FloorFilter.me),
                        ),
                      if (friendCount > 0)
                        BgmFilterChip(
                          label: '好友 $friendCount',
                          selected: filter == _FloorFilter.friends,
                          onTap: () => onFilter(_FloorFilter.friends),
                        ),
                      if (likeCount > 0)
                        BgmFilterChip(
                          label: '贴贴 $likeCount',
                          selected: filter == _FloorFilter.likes,
                          onTap: () => onFilter(_FloorFilter.likes),
                        ),
                    ],
                  ),
                ),
              BgmHeaderAction(
                tooltip: '吐槽倒序',
                icon: Icon(
                  reverse
                      ? Icons.vertical_align_bottom
                      : Icons.vertical_align_top,
                  size: 18,
                ),
                onPressed: onReverse,
              ),
            ],
          ),
        ),
        const BgmHairline(),
        if (floors.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(switch (filter) {
                _FloorFilter.follow => '还没有关注的回复',
                _FloorFilter.me => '你还没有回复',
                _FloorFilter.friends => '好友还没有回复',
                _FloorFilter.likes => '还没有贴贴',
                _FloorFilter.all => '还没有回复',
              }, style: TextStyle(color: theme.colorScheme.outline)),
            ),
          ),
        for (final (index, floor) in floors.indexed)
          FloorView(
            floor: floor,
            floorLabel: floor.floor.isNotEmpty ? floor.floor : '#${index + 2}',
            isAuthor: data.userId.isNotEmpty && floor.userId == data.userId,
            settings: settings,
            onReply: onReply,
            topicId: topicId,
            likeType: data.likeType,
            expanded: expandedSubs.contains(floor.id),
            onExpand: () => onExpandFloor(floor.id),
            htmlExpanded: expandedHtml.contains(floor.id),
            onHtmlToggle: () => onHtmlToggle(floor.id),
          ),

        if (data.pageTotal > 1)
          Center(child: BgmTextAction('加载更多楼层', onPressed: onLoadMore)),
      ],
    );
  }

  void _openGroup(BuildContext context, TopicPageData data) {
    final href = data.groupHref;
    if (href.contains('/subject/')) {
      final id = int.tryParse(href.split('/subject/').last.split('/').first);
      if (id != null && id > 0) {
        context.push('/subject/$id');
        return;
      }
    }
    if (href.contains('/character/')) {
      final id = int.tryParse(href.split('/character/').last.split('/').first);
      if (id != null && id > 0) {
        context.push('/mono/character/$id');
        return;
      }
    }
    if (href.contains('/person/')) {
      final id = int.tryParse(href.split('/person/').last.split('/').first);
      if (id != null && id > 0) {
        context.push('/mono/person/$id');
        return;
      }
    }
    final name = href.replaceAll('/group/', '').split('/').first;
    if (name.isNotEmpty) context.push('/rakuen/group/$name');
  }

  bool _isOld(String time) {
    if (time.isEmpty) return false;
    final year = int.tryParse(
      RegExp(r'(\d{4})').firstMatch(time)?.group(1) ?? '',
    );
    if (year == null) return false;
    return DateTime.now().year - year >= 2;
  }
}

/// 章节帖上一集 / 下一集 (对齐原版 topic/component/top/ep)
class _TopicEpNav extends ConsumerWidget {
  final String topicId;
  final String groupHref;

  const _TopicEpNav({required this.topicId, required this.groupHref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!topicId.startsWith('ep/') || !groupHref.contains('/subject/')) {
      return const SizedBox.shrink();
    }
    final subjectId = int.tryParse(
      groupHref.split('/subject/').last.split('/').first,
    );
    if (subjectId == null || subjectId <= 0) return const SizedBox.shrink();
    final list = ref.watch(epListProvider(subjectId)).valueOrNull;
    if (list == null) return const SizedBox.shrink();
    final currentId = int.tryParse(topicId.split('/').last) ?? 0;
    final eps = [...list.eps, ...list.type1];
    final index = eps.indexWhere(
      (e) => e.id == currentId || e.url.contains('/ep/$currentId'),
    );
    if (index < 0) return const SizedBox.shrink();
    final prev = index > 0 ? eps[index - 1] : null;
    final next = index + 1 < eps.length ? eps[index + 1] : null;
    if (prev == null && next == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: prev == null
                ? const SizedBox.shrink()
                : _EpNavButton(ep: prev, forward: false),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: next == null
                ? const SizedBox.shrink()
                : _EpNavButton(ep: next, forward: true),
          ),
        ],
      ),
    );
  }
}

class _EpNavButton extends StatelessWidget {
  final Ep ep;
  final bool forward;

  const _EpNavButton({required this.ep, required this.forward});

  @override
  Widget build(BuildContext context) {
    final kind = ep.type == 1 ? 'sp' : 'ep';
    return InkWell(
      onTap: () => context.pushReplacement('/rakuen/topic/ep/${ep.id}'),
      child: Column(
        crossAxisAlignment: forward
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: forward
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!forward) const Icon(Icons.navigate_before, size: 18),
              Text(
                '$kind${ep.sort}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (forward) const Icon(Icons.navigate_next, size: 18),
            ],
          ),
          Text(
            ep.displayName,
            style: context.ds.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: forward ? TextAlign.right : TextAlign.left,
          ),
        ],
      ),
    );
  }
}
