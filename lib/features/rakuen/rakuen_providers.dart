import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/html/bgm_html_parser.dart' as core;
import '../../core/storage/cache.dart';
import '../../shared/models/group.dart';
import '../../shared/models/timeline.dart';
import '../../shared/models/topic.dart';
import 'html_parse.dart';
import 'rakuen_models.dart';

/// 帖子详情 (HTML 抓取为主, JSON 兜底)
final topicDetailProvider =
    AsyncNotifierProvider.family<TopicDetailNotifier, TopicPageData, String>(
      TopicDetailNotifier.new,
    );

class TopicDetailNotifier extends FamilyAsyncNotifier<TopicPageData, String> {
  int _page = 1;

  @override
  Future<TopicPageData> build(String topicId) async {
    _page = 1;
    final data = await _fetch(topicId, 1);
    _recordHistory(data);
    return data;
  }

  Future<TopicPageData> _fetch(String topicId, int page) async {
    final client = ref.read(apiClientProvider);
    final html = await client.fetchHtml(topicPageUrl(topicId, page: page));
    final parsed = parseTopicPage(html);
    if (parsed.isEmpty) {
      // JSON 兜底: /topic/{topicId}
      try {
        final json =
            await client.get(apiTopic(topicId)) as Map<String, dynamic>;
        return _fromTopicJson(json);
      } catch (_) {
        return parsed;
      }
    }
    return parsed;
  }

  /// 加载下一页楼层
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || _page >= current.pageTotal) return;
    try {
      final next = await _fetch(arg, _page + 1);
      _page += 1;
      state = AsyncData(
        TopicPageData(
          title: current.title,
          group: current.group,
          groupHref: current.groupHref,
          groupThumb: current.groupThumb,
          userName: current.userName,
          userId: current.userId,
          avatar: current.avatar,
          time: current.time,
          contentHtml: current.contentHtml,
          floors: [...current.floors, ...next.floors],
          pageTotal: current.pageTotal,
          formhash: current.formhash.isNotEmpty
              ? current.formhash
              : next.formhash,
          lastview: current.lastview.isNotEmpty
              ? current.lastview
              : next.lastview,
          likeType: current.likeType,
          tip: current.tip,
          close: current.close,
        ),
      );

    } catch (_) {}
  }

  TopicPageData _fromTopicJson(Map<String, dynamic> json) {
    final topic = json['topic'] as Map<String, dynamic>? ?? const {};
    final comments = json['comments'] as List? ?? const [];
    final user = topic['user'] as Map<String, dynamic>? ?? const {};
    final group = topic['group'] as Map<String, dynamic>? ?? const {};
    return TopicPageData(
      title: topic['title'] as String? ?? '',
      group: (group['title'] as String? ?? group['name'] as String? ?? '')
          .toString(),
      groupHref: (group['name'] as String? ?? '').toString(),
      userName:
          (user['nickname'] as String? ?? user['username'] as String? ?? '')
              .toString(),
      userId: (user['id'] as num?)?.toInt().toString() ?? '',
      avatar: _userAvatar(user),
      time: topic['created_at'] as String? ?? '',
      contentHtml: topic['content'] as String? ?? '',
      floors: comments
          .whereType<Map>()
          .map((e) => _floorFromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pageTotal: 1,
    );
  }

  void _recordHistory(TopicPageData data) {
    if (data.isEmpty || data.title.isEmpty) return;
    ref
        .read(historyProvider.notifier)
        .add(
          HistoryItem(
            topicId: arg,
            title: data.title,
            group: data.group,
            userName: data.userName,
            replies: data.floors.length,
            time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );
  }
}

/// 日志详情
final blogDetailProvider =
    AsyncNotifierProvider.family<BlogDetailNotifier, BlogPageData, int>(
      BlogDetailNotifier.new,
    );

class BlogDetailNotifier extends FamilyAsyncNotifier<BlogPageData, int> {
  @override
  Future<BlogPageData> build(int blogId) async {
    final client = ref.read(apiClientProvider);
    try {
      final html = await client.fetchHtml(blogPageUrl(blogId));
      final parsed = parseBlogPage(html);
      if (parsed.title.isNotEmpty || parsed.floors.isNotEmpty) return parsed;
    } catch (_) {}
    // JSON 兜底
    try {
      final json = await client.get(apiBlog('$blogId')) as Map<String, dynamic>;
      final blog = json['blog'] as Map<String, dynamic>? ?? const {};
      final comments = json['comments'] as List? ?? const [];
      final user = blog['user'] as Map<String, dynamic>? ?? const {};
      final avatar = user['avatar'] as Map<String, dynamic>? ?? const {};
      return BlogPageData(
        title: blog['title'] as String? ?? '',
        userName:
            (user['nickname'] as String? ?? user['username'] as String? ?? '')
                .toString(),
        userId: (user['id'] as num?)?.toInt().toString() ?? '',
        avatar:
            (avatar['large'] as String? ?? avatar['medium'] as String? ?? '')
                .toString(),
        time: blog['created_at'] as String? ?? '',
        contentHtml: blog['content'] as String? ?? '',
        floors: comments
            .whereType<Map>()
            .map((e) => _floorFromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    } catch (_) {
      return const BlogPageData();
    }
  }
}

core.RakuenFloor _floorFromJson(Map<String, dynamic> json) {
  final user = json['user'] as Map<String, dynamic>? ?? const {};
  final subs = (json['sub_replies'] as List? ?? const [])
      .whereType<Map>()
      .map((e) => _floorFromJson(Map<String, dynamic>.from(e)))
      .toList();
  final avatar = user['avatar'] as Map<String, dynamic>? ?? const {};
  return core.RakuenFloor(
    id: (json['id'] as num?)?.toInt().toString() ?? '',
    time: json['created_at'] as String? ?? '',
    avatar: (avatar['large'] as String? ?? avatar['medium'] as String? ?? '')
        .toString(),
    userId: (user['id'] as num?)?.toInt().toString() ?? '',
    userName: (user['nickname'] as String? ?? user['username'] as String? ?? '')
        .toString(),
    messageHtml: json['content'] as String? ?? '',
    subReplies: subs,
  );
}

/// 小组信息
final groupInfoProvider = FutureProvider.family<GroupInfoData, String>((
  ref,
  name,
) async {
  final client = ref.read(apiClientProvider);
  try {
    final html = await client.fetchHtml(groupHomePageUrl(name));
    final info = parseGroupHome(html);
    if (info.title.isNotEmpty) return info;
  } catch (_) {}
  // JSON 兜底
  try {
    final json = await client.get(apiGroup(name)) as Map<String, dynamic>;
    final group = json['group'] as Map<String, dynamic>? ?? json;
    return GroupInfoData(
      title: (group['title'] as String? ?? group['name'] as String? ?? '')
          .toString(),
      icon: (group['icon'] as String? ?? '').toString(),
      members: (group['members'] as num?)?.toInt() ?? 0,
    );
  } catch (_) {
    return const GroupInfoData();
  }
});

/// 小组讨论列表
final groupForumProvider =
    AsyncNotifierProvider.family<
      GroupForumNotifier,
      RakuenListData<RakuenTopicItem>,
      String
    >(GroupForumNotifier.new);

class GroupForumNotifier
    extends FamilyAsyncNotifier<RakuenListData<RakuenTopicItem>, String> {
  int _maxPage = 1;

  @override
  Future<RakuenListData<RakuenTopicItem>> build(String name) async {
    _maxPage = 1;
    return _fetch(name, 1);
  }

  Future<RakuenListData<RakuenTopicItem>> _fetch(String name, int page) async {
    final client = ref.read(apiClientProvider);
    final html = await client.fetchHtml(groupForumPageUrl(name, page: page));
    final items = parseGroupForum(html);
    final maxPage = _maxPageOf(html);
    if (maxPage > _maxPage) _maxPage = maxPage;
    return RakuenListData(items: items, page: page, hasMore: page < _maxPage);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(arg, current.page + 1);
      state = AsyncData(
        RakuenListData(
          items: [...current.items, ...next.items],
          page: next.page,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {}
  }

  int _maxPageOf(String html) {
    var max = 1;
    for (final m in RegExp(r'[?&]page=(\d+)').allMatches(html)) {
      final v = int.tryParse(m.group(1) ?? '') ?? 0;
      if (v > max) max = v;
    }
    return max;
  }
}

/// 帖子聚合 - 我回复的 (移植自原项目 rakuen/history 的 reply tab)
/// 数据源: 主站 /group/my_reply (HTML), 与普通小组论坛页不同 - 无 /forum 后缀
final myReplyProvider =
    AsyncNotifierProvider.family<
      MyReplyNotifier,
      RakuenListData<RakuenTopicItem>,
      int
    >(MyReplyNotifier.new);

class MyReplyNotifier
    extends FamilyAsyncNotifier<RakuenListData<RakuenTopicItem>, int> {
  int _maxPage = 1;

  @override
  Future<RakuenListData<RakuenTopicItem>> build(int page) async {
    _maxPage = 1;
    return _fetch(page);
  }

  Future<RakuenListData<RakuenTopicItem>> _fetch(int page) async {
    final client = ref.read(apiClientProvider);
    final html = await client.fetchHtml(
      'https://bgm.tv/group/my_reply?page=$page',
    );
    final items = core
        .parseGroupForum(html)
        .where((r) => r.href.isNotEmpty)
        .map((e) {
          // 将行内 href 规约为 topicId (group/N)
          final m = RegExp(
            r'/(group|subject|ep|person|character|blog)/topic/(\d+)',
          ).firstMatch(e.href);
          final topicId = m != null ? '${m.group(1)}/${m.group(2)}' : e.href;
          return RakuenTopicItem(
            title: e.title,
            userName: e.userName,
            userId: e.userId,
            topicId: topicId,
            group: '',
            groupHref: '',
            replies: e.replies,
            time: e.time,
          );
        })
        .toList();
    final maxPage = _maxPageOf(html);
    if (maxPage > _maxPage) _maxPage = maxPage;
    return RakuenListData(items: items, page: page, hasMore: page < _maxPage);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(current.page + 1);
      state = AsyncData(
        RakuenListData(
          items: [...current.items, ...next.items],
          page: next.page,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {}
  }

  int _maxPageOf(String html) {
    var max = 1;
    for (final m in RegExp(r'[?&]page=(\d+)').allMatches(html)) {
      final v = int.tryParse(m.group(1) ?? '') ?? 0;
      if (v > max) max = v;
    }
    return max;
  }
}

/// 小组成员
final groupMembersProvider = FutureProvider.family<List<GroupMember>, String>((
  ref,
  name,
) async {
  final client = ref.read(apiClientProvider);
  try {
    final html = await client.fetchHtml(groupMembersPageUrl(name));
    final members = parseGroupMembers(html);
    if (members.isNotEmpty) return members;
  } catch (_) {}
  // JSON 兜底
  try {
    final json = await client.get(apiGroupMembers(name));
    final list = _jsonList(json, const ['members']);
    return list.map((e) {
      final user = e is Map
          ? Map<String, dynamic>.from(e)
          : const <String, dynamic>{};
      final avatar = user['avatar'] as Map<String, dynamic>? ?? const {};
      return GroupMember(
        userId: (user['id'] as num?)?.toInt().toString() ?? '',
        userName:
            (user['nickname'] as String? ?? user['username'] as String? ?? '')
                .toString(),
        avatar:
            (avatar['large'] as String? ?? avatar['medium'] as String? ?? '')
                .toString(),
      );
    }).toList();
  } catch (_) {
    return const [];
  }
});

/// 超展开板块帖子列表 (scope: new_bangumi / classical_bangumi / ...)
final boardTopicsProvider =
    AsyncNotifierProvider.family<
      BoardTopicsNotifier,
      RakuenListData<RakuenTopicItem>,
      String
    >(BoardTopicsNotifier.new);

class BoardTopicsNotifier
    extends FamilyAsyncNotifier<RakuenListData<RakuenTopicItem>, String> {
  @override
  Future<RakuenListData<RakuenTopicItem>> build(String scope) async {
    return _fetch(scope, 1);
  }

  Future<RakuenListData<RakuenTopicItem>> _fetch(String scope, int page) async {
    final client = ref.read(apiClientProvider);
    final html = await client.fetchHtml(rakuenBoardPageUrl(scope, page: page));
    final items = core
        .parseRakuenList(html)
        .map(
          (e) => RakuenTopicItem(
            topicId: topicIdFromHref(e.href),
            title: e.title,
            group: e.group,
            groupHref: e.groupHref,
            userName: e.userName,
            userId: e.userId,
            avatar: e.avatar,
            replies: e.replies,
            time: e.time,
          ),
        )
        .toList();
    return RakuenListData(
      items: items,
      page: page,
      hasMore: items.length >= 30,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(arg, current.page + 1);
      state = AsyncData(
        RakuenListData(
          items: [...current.items, ...next.items],
          page: next.page,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {}
  }
}

/// 电波提醒列表 (JSON /notify)
final notifyProvider =
    AsyncNotifierProvider.family<NotifyNotifier, NotifyListData, int>(
      NotifyNotifier.new,
    );

class NotifyNotifier extends FamilyAsyncNotifier<NotifyListData, int> {
  @override
  Future<NotifyListData> build(int page) async {
    return _fetch(page);
  }

  Future<NotifyListData> _fetch(int page) async {
    final client = ref.read(apiClientProvider);
    final json = await client.get(apiNotify(), query: {'page': page});
    final list = _jsonList(json, const ['list']);
    return NotifyListData(
      items: list
          .map((e) => Notify.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      page: page,
      hasMore: list.length >= 30,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(current.page + 1);
      state = AsyncData(
        NotifyListData(
          items: [...current.items, ...next.items],
          page: next.page,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {}
  }
}

/// 未读提醒数
final notifyCountProvider = FutureProvider<int>((ref) async {
  try {
    final client = ref.read(apiClientProvider);
    final json = await client.get(apiNotifyCount());
    if (json is Map) {
      return (json['count'] as num?)?.toInt() ?? 0;
    }
    return (json as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
});

/// 预读未读帖子 (原项目 PREFETCH_COUNT=20)
const kRakuenPrefetchCount = 20;

Future<int> prefetchUnreadTopics(
  WidgetRef ref,
  Iterable<String> topicIds,
) async {
  final history = ref.read(historyProvider);
  final unread = [
    for (final id in topicIds)
      if (id.isNotEmpty && !history.any((h) => h.topicId == id)) id,
  ].take(kRakuenPrefetchCount).toList();
  var ok = 0;
  for (final id in unread) {
    try {
      await ref.read(topicDetailProvider(id).future);
      ok++;
    } catch (_) {}
  }
  return ok;
}

/// 浏览历史 (hive box 'rakuen', key 'history')
final historyProvider = NotifierProvider<HistoryNotifier, List<HistoryItem>>(
  HistoryNotifier.new,
);

class HistoryNotifier extends Notifier<List<HistoryItem>> {
  static const _boxName = 'rakuen';
  static const _key = 'history';
  static const _maxItems = 100;

  @override
  List<HistoryItem> build() {
    final raw = Cache.instance.get(
      _boxName,
      _key,
      maxAge: const Duration(days: 3650),
    );
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => HistoryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<void> add(HistoryItem item) async {
    if (item.topicId.isEmpty) return;
    final next = [
      item,
      ...state.where((e) => e.topicId != item.topicId),
    ].take(_maxItems).toList();
    state = next;
    await Cache.instance.put(
      _boxName,
      _key,
      next.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> remove(HistoryItem item) async {
    final next = state.where((e) => e.topicId != item.topicId).toList();
    state = next;
    await Cache.instance.put(
      _boxName,
      _key,
      next.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> clear() async {
    state = const [];
    await Cache.instance.put(_boxName, _key, <dynamic>[]);
  }
}

/// 帖子收藏 (hive box 'rakuen', key 'favor')
final topicFavorProvider =
    NotifierProvider<TopicFavorNotifier, List<HistoryItem>>(
      TopicFavorNotifier.new,
    );

class TopicFavorNotifier extends Notifier<List<HistoryItem>> {
  static const _boxName = 'rakuen';
  static const _key = 'favor';

  @override
  List<HistoryItem> build() {
    final raw = Cache.instance.get(
      _boxName,
      _key,
      maxAge: const Duration(days: 3650),
    );
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => HistoryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  bool contains(String topicId) => state.any((e) => e.topicId == topicId);

  Future<void> toggle(HistoryItem item) async {
    if (item.topicId.isEmpty) return;
    final next = contains(item.topicId)
        ? state.where((e) => e.topicId != item.topicId).toList()
        : [item, ...state];
    state = next;
    await Cache.instance.put(
      _boxName,
      _key,
      next.map((e) => e.toJson()).toList(),
    );
  }
}

/// 帖子聚合 - 热门 (超展开 type=hot)
final hotTopicsProvider = FutureProvider<List<RakuenTopicItem>>((ref) async {
  final client = ref.read(apiClientProvider);
  final html = await client.fetchHtml(core.rakueHtmlUrl('topiclist', 'hot'));
  return core
      .parseRakuenList(html)
      .map(
        (e) => RakuenTopicItem(
          topicId: e.topicId,
          title: e.title,
          group: e.group,
          groupHref: e.groupHref,
          userName: e.userName,
          userId: e.userId,
          replies: '${e.replyCount ?? 0}',
          time: e.time,
        ),
      )
      .toList();
});

/// 我的主题
final mineTopicsProvider = FutureProvider.family<List<Topic>, String>((
  ref,
  uid,
) async {
  final client = ref.read(apiClientProvider);
  final json = await client.get(apiUserTopics(uid));
  final list = _jsonList(json, const ['topics']);
  return list
      .map((e) => Topic.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

/// 我的日志
final mineBlogsProvider = FutureProvider.family<List<Blog>, String>((
  ref,
  uid,
) async {
  final client = ref.read(apiClientProvider);
  final json = await client.get(apiUserBlogs(uid));
  final list = _jsonList(json, const ['list']);
  return list
      .map((e) => Blog.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

/// 我的动态 (回复/吐槽等)
final mineTimelineProvider = FutureProvider.family<List<TimelineItem>, String>((
  ref,
  uid,
) async {
  final client = ref.read(apiClientProvider);
  final json = await client.get(apiUserTimeline(uid, 30));
  if (json is List) {
    return json
        .map((e) => TimelineItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
  return const [];
});

/// 我的 (组合)
final mineProvider = FutureProvider.family<MineData, String>((ref, uid) async {
  final topics = await ref.watch(mineTopicsProvider(uid).future);
  final blogs = await ref.watch(mineBlogsProvider(uid).future);
  final timeline = await ref.watch(mineTimelineProvider(uid).future);
  return MineData(topics: topics, blogs: blogs, timeline: timeline);
});

/// 超展开搜索 (JSON /search/topic/{kw})
final rakuenSearchProvider =
    AsyncNotifierProvider.family<
      SearchNotifier,
      RakuenListData<RakuenTopicItem>,
      String
    >(SearchNotifier.new);

class SearchNotifier
    extends FamilyAsyncNotifier<RakuenListData<RakuenTopicItem>, String> {
  @override
  Future<RakuenListData<RakuenTopicItem>> build(String keyword) async {
    return _fetch(keyword, 1);
  }

  Future<RakuenListData<RakuenTopicItem>> _fetch(
    String keyword,
    int page,
  ) async {
    final client = ref.read(apiClientProvider);
    final json = await client.get(apiSearchTopic(keyword, page: page));
    final list = _jsonList(json, const ['topics', 'list']);
    final items = <RakuenTopicItem>[];
    for (final raw in list) {
      final e = Map<String, dynamic>.from(raw as Map);
      final user = e['user'] as Map<String, dynamic>? ?? const {};
      final group = e['group'] as Map<String, dynamic>? ?? const {};
      final url = e['url'] as String? ?? '';
      items.add(
        RakuenTopicItem(
          topicId: topicIdFromHref(url),
          title: e['title'] as String? ?? '',
          group: (group['title'] as String? ?? group['name'] as String? ?? '')
              .toString(),
          userName:
              (user['nickname'] as String? ?? user['username'] as String? ?? '')
                  .toString(),
          userId: (user['id'] as num?)?.toInt().toString() ?? '',
          replies: (e['replies'] as num?)?.toInt().toString() ?? '',
          time: e['created_at'] as String? ?? '',
        ),
      );
    }
    return RakuenListData(
      items: items,
      page: page,
      hasMore: items.length >= 30,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(arg, current.page + 1);
      state = AsyncData(
        RakuenListData(
          items: [...current.items, ...next.items],
          page: next.page,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {}
  }
}

/// 条目长评 (JSON /subject/{id}/reviews)
final reviewsProvider =
    AsyncNotifierProvider.family<ReviewsNotifier, ReviewListData, int>(
      ReviewsNotifier.new,
    );

class ReviewsNotifier extends FamilyAsyncNotifier<ReviewListData, int> {
  @override
  Future<ReviewListData> build(int subjectId) async {
    return _fetch(subjectId, 1);
  }

  Future<ReviewListData> _fetch(int subjectId, int page) async {
    final client = ref.read(apiClientProvider);
    final json = await client.get(
      apiSubjectReviews(subjectId),
      query: {'page': page},
    );
    final list = _jsonList(json, const ['reviews']);
    return ReviewListData(
      reviews: list
          .map((e) => Review.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      page: page,
      hasMore: list.length >= 30,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(arg, current.page + 1);
      state = AsyncData(
        ReviewListData(
          reviews: [...current.reviews, ...next.reviews],
          page: next.page,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {}
  }
}

/// JSON 列表提取 (兼容 {key: [...]} 与裸数组)
List<dynamic> _jsonList(dynamic json, List<String> keys) {
  if (json is List) return json;
  if (json is Map) {
    for (final key in keys) {
      final v = json[key];
      if (v is List) return v;
    }
    if (json['list'] is List) return json['list'] as List;
  }
  return const [];
}

/// 用户头像 URL
String _userAvatar(Map<String, dynamic> user) {
  final avatar = user['avatar'] as Map<String, dynamic>? ?? const {};
  return (avatar['large'] as String? ?? avatar['medium'] as String? ?? '')
      .toString();
}
