import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';

import 'user_models.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';
import '../../core/auth/site_cookies.dart';
import '../../shared/models/user.dart';
import '../../design_system/design_system.dart';

import '../progress/progress_filter.dart';

/// 原版好友过滤: userName / userId 忽略大小写
List<Friend> filterFriends(List<Friend> friends, String filter) {
  final q = filter.trim().toUpperCase();
  if (q.isEmpty) return friends;
  return [
    for (final item in friends)
      if (item.userName.toUpperCase().contains(q) ||
          item.userId.toUpperCase().contains(q))
        item,
  ];
}

/// 好友列表 (bgm.tv/user/{uid}/friends, 主站 HTML)
final userFriendsProvider = FutureProvider.family<List<Friend>, String>((
  ref,
  userId,
) async {
  final client = ref.read(apiClientProvider);
  final html = await client.get(apiUserFriendsHtml(userId), host: kHost);
  return parseUserFriends(html as String);
});

/// 反向好友列表 (bgm.tv/user/{uid}/rev_friends, 原项目 type: 'rev')
final userRevFriendsProvider = FutureProvider.family<List<Friend>, String>((
  ref,
  userId,
) async {
  final client = ref.read(apiClientProvider);
  final html = await client.get(apiUserRevFriendsHtml(userId), host: kHost);
  return parseUserFriends(html as String);
});

void _showFriendsTip(BuildContext context) {
  showBgmDialog<void>(
    context: context,
    title: '好友',
    content: const Text('点击头像前往空间\n长按头像展开菜单'),
    actions: (ctx) => [
      BgmButton('知道了', expand: false, onPressed: () => Navigator.pop(ctx)),
    ],
  );
}

/// 原版好友 Header DATA
const kFriendsMoreItems = <(String, String)>[
  ('browser', '浏览器查看'),
  ('info', '补充说明'),
];

/// 原版好友标题: 我的好友 / 谁加我为好友 / TA的好友 / 谁加TA为好友
String friendsTitle({required bool rev, required bool isMe}) {
  if (isMe) return rev ? '谁加我为好友' : '我的好友';
  return rev ? '谁加TA为好友' : 'TA的好友';
}

/// 原版 DATA_FRIEND: 发短信 / 解除好友
const kFriendMenuItems = <(String, String)>[
  ('pm', '发短信'),
  ('disconnect', '解除好友'),
];

/// 原版 DATA_REV_FRIEND: 移除对我的关注
const kRevFriendMenuItems = <(String, String)>[('disconnectRev', '移除对我的关注')];

List<(String, String)> friendMenuItems({required bool rev}) =>
    rev ? kRevFriendMenuItems : kFriendMenuItems;

/// 原版好友时钟批量上限
const kFriendsActiveLimit = 400;

/// 原版 friendGroup 中文 key 顺序
const kFriendActiveGroups = <String>[
  '一小时内',
  '一天内',
  '三天内',
  '一周内',
  '一月内',
  '半年内',
  '一年内',
  '超过一年',
];

const kFriendGroupUnknown = '未知';

const kDefaultFriendGroupShows = <String, bool>{
  '一小时内': true,
  '一天内': true,
  '三天内': true,
  '一周内': true,
  '一月内': true,
  '半年内': false,
  '一年内': false,
  '超过一年': false,
  '未知': false,
};

String friendActiveBucket(int lastActive, int nowSec) {
  if (lastActive <= 0) return kFriendGroupUnknown;
  final diffSec = nowSec - lastActive;
  final days = diffSec / 86400;
  if (diffSec <= 3600) return '一小时内';
  if (days <= 1) return '一天内';
  if (days <= 3) return '三天内';
  if (days <= 7) return '一周内';
  if (days <= 30) return '一月内';
  if (days <= 182) return '半年内';
  if (days <= 365) return '一年内';
  return '超过一年';
}

Map<String, List<String>> groupFriendsByActive(
  List<Friend> friends,
  Map<String, int> active,
  int nowSec,
) {
  final temp = <String, List<(String, int)>>{
    for (final title in kFriendActiveGroups) title: [],
  };
  for (final item in friends) {
    final lastActive = active[item.userId];
    if (lastActive == null || lastActive <= 0) continue;
    temp[friendActiveBucket(lastActive, nowSec)]?.add((
      item.userId,
      lastActive,
    ));
  }
  return {
    for (final title in kFriendActiveGroups)
      title: () {
        final items = [...?temp[title]]..sort((a, b) => b.$2.compareTo(a.$2));
        return <String>[for (final item in items) item.$1];
      }(),
  };
}

List<String> friendsActiveRefreshIds(
  List<Friend> friends,
  Map<String, int> active, {
  required bool full,
  required int nowSec,
}) {
  if (full) {
    return [for (final item in friends.take(kFriendsActiveLimit)) item.userId];
  }
  const oneDay = 86400;
  const threeDays = 3 * oneDay;
  final ids = <String>[];
  for (final item in friends) {
    final lastActive = active[item.userId] ?? 0;
    if (lastActive <= 0) {
      ids.add(item.userId);
      continue;
    }
    final diff = nowSec - lastActive;
    if (diff > oneDay && diff <= threeDays + oneDay) ids.add(item.userId);
  }
  return ids;
}

int parseUserActiveCreatedAt(dynamic raw) {
  if (raw is! List || raw.isEmpty) return 0;
  final first = raw.first;
  if (first is! Map) return 0;
  final created = first['createdAt'] ?? first['created_at'];
  if (created is num) return created.toInt();
  if (created is String) return int.tryParse(created) ?? 0;
  return 0;
}

sealed class FriendListEntry {
  const FriendListEntry();
}

class FriendHeaderEntry extends FriendListEntry {
  final String title;
  const FriendHeaderEntry(this.title);
}

class FriendItemEntry extends FriendListEntry {
  final Friend friend;
  const FriendItemEntry(this.friend);
}

List<FriendListEntry> buildFriendList({
  required List<Friend> friends,
  required String filter,
  Map<String, List<String>>? groups,
  Map<String, bool> shows = kDefaultFriendGroupShows,
}) {
  final filtered = filterFriends(friends, filter);
  if (groups == null) {
    return [for (final item in filtered) FriendItemEntry(item)];
  }
  final map = {for (final item in filtered) item.userId: item};
  final used = <String>{};
  final result = <FriendListEntry>[];
  final searching = filter.trim().isNotEmpty;

  void pushByIds(List<String> ids, bool showItem) {
    for (final id in ids) {
      if (used.contains(id)) continue;
      final item = map[id];
      if (item == null) continue;
      if (showItem) result.add(FriendItemEntry(item));
      used.add(id);
    }
  }

  for (final title in kFriendActiveGroups) {
    final ids = groups[title] ?? const [];
    if (ids.isEmpty) continue;
    result.add(FriendHeaderEntry(title));
    pushByIds(ids, searching || (shows[title] ?? false));
  }
  final unknown = [
    for (final item in filtered)
      if (!used.contains(item.userId)) item.userId,
  ];
  if (unknown.isNotEmpty) {
    result.add(const FriendHeaderEntry(kFriendGroupUnknown));
    pushByIds(unknown, searching || (shows[kFriendGroupUnknown] ?? false));
  }
  return result;
}

/// 好友 (独立页 / 我的好友, 好友/反向好友 tab)
class FriendsScreen extends ConsumerStatefulWidget {
  final String userId;
  final bool rev;

  const FriendsScreen({super.key, required this.userId, this.rev = false});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.rev ? 1 : 0,
  );
  final _friendKey = GlobalKey<_FriendsListState>();
  final _revKey = GlobalKey<_FriendsListState>();

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final isMe = me != null && userPathId(me) == widget.userId;
    return Scaffold(
      appBar: BgmAppBar(
        title: friendsTitle(rev: widget.rev, isMe: isMe),

        actions: [
          BgmHeaderAction(
            tooltip: '好友活跃度',
            icon: Icon(
              Icons.access_time,
              size: 20,
              color: context.ds.textPrimary,
            ),
            onPressed: () {
              final list =
                  (_tab.index == 1 ? _revKey : _friendKey).currentState;
              unawaited(list?.fetchFriendsActive(context));
            },
          ),
          BgmHeaderMore(
            items: kFriendsMoreItems,
            onSelected: (value) {
              if (value == 'browser') {
                openExternalUrl(
                  widget.rev
                      ? apiUserRevFriendsHtml(widget.userId)
                      : apiUserFriendsHtml(widget.userId),
                );
                return;
              }
              if (value == 'info') _showFriendsTip(context);
            },
          ),
        ],

        bottom: BgmControlledTabStrip(
          controller: _tab,
          tabs: const [Text('好友'), Text('反向好友')],
        ),
      ),

      body: TabBarView(
        controller: _tab,
        children: [
          FriendsList(key: _friendKey, userId: widget.userId),
          FriendsList(key: _revKey, userId: widget.userId, rev: true),
        ],
      ),
    );
  }
}

/// 我的好友 (当前登录用户)
class MyFriendsScreen extends ConsumerWidget {
  final bool rev;

  const MyFriendsScreen({super.key, this.rev = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    if (me == null) {
      return const Scaffold(body: Center(child: Text('请先登录')));
    }
    return FriendsScreen(userId: userPathId(me), rev: rev);
  }
}

class FriendsList extends ConsumerStatefulWidget {
  final String userId;
  final bool rev;

  const FriendsList({super.key, required this.userId, this.rev = false});

  @override
  ConsumerState<FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends ConsumerState<FriendsList> {
  final _filterCtrl = TextEditingController();
  String _filter = '';
  bool _fetching = false;
  bool _didFullActive = false;
  String _percent = '';
  Map<String, int> _active = const {};
  Map<String, List<String>>? _groups;
  Map<String, bool> _shows = Map<String, bool>.from(kDefaultFriendGroupShows);

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<void> fetchFriendsActive(BuildContext context) async {
    if (_fetching) {
      showBgmToast(context, '正在获取中，请稍等');
      return;
    }
    final friends =
        (widget.rev
                ? ref.read(userRevFriendsProvider(widget.userId))
                : ref.read(userFriendsProvider(widget.userId)))
            .valueOrNull ??
        const <Friend>[];
    if (friends.isEmpty) {
      showBgmToast(context, '暂无好友');
      return;
    }
    final ok = await showBgmConfirm(
      context,
      title: '提示',
      message: _didFullActive
          ? '刷新未知和三天内好友的活跃时间，确定？'
          : '批量获取所有好友最近一次的时间胶囊创建时间（单次最大400个），确定？',
    );
    if (!ok || !context.mounted) return;
    await _runFriendsActive(friends, full: !_didFullActive);
  }

  Future<void> _runFriendsActive(
    List<Friend> friends, {
    required bool full,
  }) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final ids = friendsActiveRefreshIds(
      friends,
      _active,
      full: full,
      nowSec: nowSec,
    );
    if (ids.isEmpty) {
      setState(() {
        _groups = groupFriendsByActive(friends, _active, nowSec);
        _didFullActive = true;
      });
      return;
    }
    setState(() {
      _fetching = true;
      _percent = '';
    });
    final updates = Map<String, int>.from(_active);
    final client = ref.read(apiClientProvider);
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i];
      final prev = updates[id] ?? 0;
      if (prev > 0 && nowSec - prev <= 3600) {
        if (mounted) {
          setState(() {
            _percent = '${((i + 1) * 100 / ids.length).floor()}%';
          });
        }
        continue;
      }
      try {
        final raw = await client.get(apiP1UsersTimeline(id));
        updates[id] = parseUserActiveCreatedAt(raw);
      } catch (_) {
        updates[id] = 0;
      }
      if (!mounted) return;
      setState(() {
        _percent = '${((i + 1) * 100 / ids.length).floor()}%';
      });
    }
    if (!mounted) return;
    setState(() {
      _fetching = false;
      _percent = '';
      _active = updates;
      _groups = groupFriendsByActive(friends, updates, nowSec);
      _didFullActive = true;
    });
  }

  void _toggleGroup(String title) {
    if (!_shows.containsKey(title)) return;
    setState(() {
      _shows = {..._shows, title: !(_shows[title] ?? false)};
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId;
    final rev = widget.rev;
    final async = ref.watch(
      rev ? userRevFriendsProvider(userId) : userFriendsProvider(userId),
    );
    final me = ref.watch(currentUserProvider);
    final isMe = me != null && userPathId(me) == userId;
    return async.when(
      loading: () => const Loading(),
      error: (_, _) => BgmRetry(
        onRetry: () => ref.invalidate(
          rev ? userRevFriendsProvider(userId) : userFriendsProvider(userId),
        ),
      ),
      data: (friends) {
        final entries = buildFriendList(
          friends: friends,
          filter: _filter,
          groups: _groups,
          shows: _shows,
        );
        return Column(
          children: [
            ProgressFilterBar(
              controller: _filterCtrl,
              length: friends.length,
              fetching: _fetching,
              percent: _percent,
              onChanged: (v) => setState(() => _filter = v),
            ),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        friends.isEmpty ? (rev ? '暂无反向好友' : '暂无好友') : '没有匹配的好友',
                      ),
                    )
                  : _groups == null
                  ? _FriendsGrid(
                      friends: [
                        for (final e in entries)
                          if (e is FriendItemEntry) e.friend,
                      ],
                      filter: _filter,
                      isMe: isMe,
                      onLongPress: (friend) =>
                          unawaited(_onFriendLongPress(context, ref, friend)),
                    )
                  : CustomScrollView(
                      slivers: [
                        for (final chunk in _friendSlivers(entries))
                          if (chunk.header != null)
                            SliverToBoxAdapter(
                              child: _FriendSectionHeader(
                                title: chunk.header!,
                                count: chunk.header == kFriendGroupUnknown
                                    ? '点击右上按钮获取活跃度以进行分组'
                                    : '${_groups?[chunk.header!]?.length ?? 0}',
                                expanded:
                                    _filter.trim().isNotEmpty ||
                                    (_shows[chunk.header!] ?? false),
                                onTap: () => _toggleGroup(chunk.header!),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              sliver: SliverGrid(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      childAspectRatio: 0.78,
                                    ),
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  i,
                                ) {
                                  final friend = chunk.friends[i];
                                  return _FriendTile(
                                    friend: friend,
                                    filter: _filter,
                                    isMe: isMe,
                                    onLongPress: () => unawaited(
                                      _onFriendLongPress(context, ref, friend),
                                    ),
                                  );
                                }, childCount: chunk.friends.length),
                              ),
                            ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onFriendLongPress(
    BuildContext context,
    WidgetRef ref,
    Friend friend,
  ) async {
    final action = await showBgmSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in friendMenuItems(rev: widget.rev))
              BgmActionRow(
                title: item.$2,
                onTap: () => Navigator.of(ctx).pop(item.$1),
              ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    await _handleFriendMenu(context, ref, friend, action);
  }

  Future<void> _handleFriendMenu(
    BuildContext context,
    WidgetRef ref,
    Friend friend,
    String action,
  ) async {
    if (action == 'pm') {
      final numId = await _friendNumId(ref, friend);
      if (numId == 0) {
        if (context.mounted) showBgmToast(context, '获取好友数字 ID 失败');
        return;
      }
      if (context.mounted) await context.push('/pm/chat/$numId');
      return;
    }

    final name = friend.userName;
    final ok = await showBgmConfirm(
      context,
      title: action == 'disconnectRev' ? '移除关注' : '解除好友',
      message: action == 'disconnectRev'
          ? '确认移除 $name 对你的关注?'
          : '确认从朋友列表中去掉 $name?',
    );
    if (!ok || !context.mounted) return;

    final gh = await _friendFormhash(ref);
    if (gh.isEmpty) {
      if (context.mounted) showBgmToast(context, '请先登录');
      return;
    }
    final numId = await _friendNumId(ref, friend);
    if (numId == 0) {
      if (context.mounted) showBgmToast(context, '获取好友数字 ID 失败');
      return;
    }
    try {
      final client = ref.read(apiClientProvider);
      await client.get(
        action == 'disconnectRev'
            ? apiDisconnectRev('$numId', gh)
            : apiDisconnect('$numId', gh),
      );
      ref.invalidate(
        widget.rev
            ? userRevFriendsProvider(widget.userId)
            : userFriendsProvider(widget.userId),
      );
      if (context.mounted) {
        showBgmToast(context, action == 'disconnectRev' ? '已移除对你的关注' : '已解除好友');
      }
    } catch (e) {
      if (context.mounted) {
        showBgmToast(context, apiErrorMessage(e));
      }
    }
  }
}

class _FriendSliverChunk {
  final String? header;
  final List<Friend> friends;
  const _FriendSliverChunk({this.header, this.friends = const []});
}

List<_FriendSliverChunk> _friendSlivers(List<FriendListEntry> entries) {
  final chunks = <_FriendSliverChunk>[];
  var friends = <Friend>[];
  void flush() {
    if (friends.isEmpty) return;
    chunks.add(_FriendSliverChunk(friends: friends));
    friends = [];
  }

  for (final entry in entries) {
    if (entry is FriendHeaderEntry) {
      flush();
      chunks.add(_FriendSliverChunk(header: entry.title));
    } else if (entry is FriendItemEntry) {
      friends.add(entry.friend);
    }
  }
  flush();
  return chunks;
}

class _FriendsGrid extends StatelessWidget {
  final List<Friend> friends;
  final String filter;
  final bool isMe;
  final ValueChanged<Friend> onLongPress;

  const _FriendsGrid({
    required this.friends,
    required this.filter,
    required this.isMe,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        return _FriendTile(
          friend: friend,
          filter: filter,
          isMe: isMe,
          onLongPress: () => onLongPress(friend),
        );
      },
    );
  }
}

class _FriendTile extends StatelessWidget {
  final Friend friend;
  final String filter;
  final bool isMe;
  final VoidCallback onLongPress;

  const _FriendTile({
    required this.friend,
    required this.filter,
    required this.isMe,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/user/${friend.userId}'),
      onLongPress: isMe ? onLongPress : null,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Avatar(url: friend.avatar, size: 52, name: friend.userName),
          const SizedBox(height: 6),
          _FriendHighlight(
            text: friend.userName,
            filter: filter,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          _FriendHighlight(
            text: friend.userId,
            filter: filter,
            style: TextStyle(
              fontSize: 9,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendSectionHeader extends StatelessWidget {
  final String title;
  final String count;
  final bool expanded;
  final VoidCallback onTap;

  const _FriendSectionHeader({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        child: Row(
          children: [
            Text(title, style: context.ds.section),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                count,
                style: context.ds.caption,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
              size: 18,
              color: context.ds.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendHighlight extends StatelessWidget {
  final String text;
  final String filter;
  final TextStyle style;

  const _FriendHighlight({
    required this.text,
    required this.filter,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final q = filter.trim();
    if (q.isEmpty || text.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      );
    }
    final lower = text.toLowerCase();
    final needle = q.toLowerCase();
    final i = lower.indexOf(needle);
    if (i < 0) {
      return Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      );
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, i)),
          TextSpan(
            text: text.substring(i, i + q.length),
            style: style.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: text.substring(i + q.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }
}

Future<int> _friendNumId(WidgetRef ref, Friend friend) async {
  if (RegExp(r'^\d+$').hasMatch(friend.userId)) {
    return int.parse(friend.userId);
  }
  try {
    final data = await ref
        .read(apiClientProvider)
        .get(apiUserInfo(friend.userId));
    return User.fromJson(data as Map<String, dynamic>).id;
  } catch (_) {
    return 0;
  }
}

Future<String> _friendFormhash(WidgetRef ref) async {
  try {
    return await ref.read(formhashProvider.future);
  } catch (_) {
    return '';
  }
}
