/// 超展开域 HTML 抓取与解析 (移植自原项目 stores/rakuen/common.ts + screens/rakuen/topic)
///
/// 说明: bgm.tv 页面结构与原项目解析器存在差异 (如 `ul.topicList` 实为
/// `table tr.topic`, 楼层为 `#comment_list > div.row_reply`), 此处按线上
/// HTML 结构实现; 通用工具函数复用 lib/core/html/bgm_html_parser.dart。
library;

import 'package:html/dom.dart';

import '../../core/html/bgm_html_parser.dart' as core;

/// 超展开板块帖子列表页 (frame 内嵌页, 与 tab 页 URL 不同)
String rakuenListHtmlUrl(String scope, {String type = '', int page = 1}) {
  final params = <String>[];
  if (type.isNotEmpty) params.add('type=$type');
  if (page > 1) params.add('page=$page');
  return 'https://bgm.tv/rakuen/$scope/topiclist${params.isEmpty ? '' : '?${params.join('&')}'}';
}

/// 帖子页入口 (页面内 JS 会跳转到 canonical 地址)
String topicHtmlUrl(String topicId) => 'https://bgm.tv/rakuen/topic/$topicId';

/// 小组页面
String groupHomeHtmlUrl(String group) => 'https://bgm.tv/group/$group';
String groupForumHtmlUrl(String group, {int page = 1}) =>
    'https://bgm.tv/group/$group/forum${page > 1 ? '?page=$page' : ''}';
String groupMembersHtmlUrl(String group) => 'https://bgm.tv/group/$group/members';

/// 日志页
String blogHtmlUrl(int blogId) => 'https://bgm.tv/blog/$blogId';

/// 从 /rakuen/topic/{topicId} 页面提取 canonical 跳转地址
String? canonicalTopicRedirect(String html) {
  final m = RegExp(r"rakuen_redirect_url\s*=\s*['\"]([^'\"]+)['\"]").firstMatch(html);
  return m?.group(1);
}

/// href → topicId ('group/350677' / 'blog/123')
String topicIdFromHref(String href) {
  const prefix = '/rakuen/topic/';
  if (href.startsWith(prefix)) return href.substring(prefix.length);
  final h = href.replaceFirst('/', '');
  return h;
}

/// 楼层
class TopicFloor {
  final String id;
  final String floor;
  final String time;
  final String avatar;
  final String userId;
  final String userName;
  final String userSign;
  final String messageHtml;
  final List<TopicFloor> subs;

  const TopicFloor({
    this.id = '',
    this.floor = '',
    this.time = '',
    this.avatar = '',
    this.userId = '',
    this.userName = '',
    this.userSign = '',
    this.messageHtml = '',
    this.subs = const [],
  });

  bool get isEmpty => messageHtml.isEmpty && userName.isEmpty;
}

/// 帖子详情页解析结果
class TopicPageData {
  final String title;
  final String group;
  final String groupHref;
  final String userName;
  final String userId;
  final String avatar;
  final String time;
  final String contentHtml;
  final List<TopicFloor> floors;
  final int pageTotal;

  const TopicPageData({
    this.title = '',
    this.group = '',
    this.groupHref = '',
    this.userName = '',
    this.userId = '',
    this.avatar = '',
    this.time = '',
    this.contentHtml = '',
    this.floors = const [],
    this.pageTotal = 1,
  });

  bool get isEmpty => title.isEmpty && floors.isEmpty;
}

/// 日志详情页解析结果
class BlogPageData {
  final String title;
  final String userName;
  final String userId;
  final String avatar;
  final String time;
  final String contentHtml;
  final List<TopicFloor> floors;

  const BlogPageData({
    this.title = '',
    this.userName = '',
    this.userId = '',
    this.avatar = '',
    this.time = '',
    this.contentHtml = '',
    this.floors = const [],
  });
}

/// 小组信息
class GroupInfoData {
  final String title;
  final int members;

  const GroupInfoData({this.title = '', this.members = 0});
}

/// 小组成员
class GroupMember {
  final String userId;
  final String userName;
  final String avatar;

  const GroupMember({this.userId = '', this.userName = '', this.avatar = ''});
}

String _bgUrl(String url) => url.startsWith('//') ? 'https:$url' : url;

String? _bgImage(Element? el) {
  if (el == null) return null;
  final style = el.attributes['style'] ?? '';
  final m = RegExp(r"background-image:\s*url\('?([^'\)]+)'?\)").firstMatch(style);
  final src = m?.group(1) ?? el.attributes['src'] ?? '';
  return src.isEmpty ? null : _bgUrl(src);
}

/// 提取 h1 标题 (帖子页标题在 <br> 之后, 前面是小组面包屑)
String _h1Title(Element? h1) {
  if (h1 == null) return '';
  final html = h1.innerHtml;
  final parts = html.split(RegExp(r'<br\s*/?>'));
  if (parts.length > 1) {
    return core.htmlDecode(core.cText(parseFragment(parts.last)));
  }
  return core.htmlDecode(h1.text.trim());
}

/// 解析帖子页 (主楼 + 楼层 + 子回复)
/// 兼容 group/subject/ep 帖子页 (div.postTopic) 与 prsn/crt 页面 (仅楼层)
TopicPageData parseTopicPage(String html) {
  final doc = core.parseDom(core.removeCF(html));

  // 主楼
  final postTopic = doc.querySelector('div.postTopic');
  final h1 = doc.querySelector('#pageHeader h1') ?? doc.querySelector('h1');
  final group = doc.querySelector('#pageHeader a.avatar');

  String groupName = '';
  String groupHref = '';
  if (group != null) {
    groupName = core.htmlDecode(group.text.trim());
    groupHref = group.attributes['href'] ?? '';
  }

  String title = _h1Title(h1);
  if (title.isEmpty) {
    final t = doc.querySelector('title');
    title = t != null ? core.htmlDecode(t.text.trim()) : '';
  }

  String userName = '';
  String userId = '';
  String avatar = '';
  String time = '';
  String contentHtml = '';

  if (postTopic != null) {
    final userLink = postTopic.querySelector('.inner strong a.l') ?? postTopic.querySelector('a.l');
    final reInfo = postTopic.querySelector('.post_actions.re_info .action small');
    final t = reInfo != null ? reInfo.text.trim().split(' - ') : const <String>[];
    userName = core.htmlDecode(core.cText(userLink ?? postTopic));
    userId = core.matchAttr(userLink, 'href', RegExp(r'/user/(\d+)'));
    avatar = _bgImage(postTopic.querySelector('span.avatarNeue')) ?? '';
    time = t.length > 1 ? t[1].trim() : '';
    contentHtml = postTopic.querySelector('.topic_content')?.innerHtml ?? '';
    // 小组面包屑缺省时用主楼作者
    if (groupName.isEmpty && postTopic.querySelector('.inner strong a.l') != null) {
      groupName = userName;
    }
  } else if (h1 != null) {
    // prsn/crt 页面: 主楼为空, 标题取页面 h1
    title = _h1Title(h1);
  }

  final floors = <TopicFloor>[];
  final list = doc.querySelector('#comment_list');
  if (list != null) {
    for (final row in list.children.where((e) => e is Element && e.localName == 'div' && e.className.contains('row_reply'))) {
      final rowEl = row as Element;
      floors.add(_parseMainFloor(rowEl));
    }
  }

  return TopicPageData(
    title: title,
    group: groupName,
    groupHref: groupHref,
    userName: userName,
    userId: userId,
    avatar: avatar,
    time: time,
    contentHtml: contentHtml,
    floors: floors,
    pageTotal: _pageTotalFrom(html),
  );
}

TopicFloor _parseMainFloor(Element row) {
  final id = row.attributes['id']?.replaceFirst('post_', '') ?? '';
  final reInfo = row.querySelector('.post_actions.re_info .action small');
  final info = reInfo != null ? reInfo.text.trim().split(' - ') : const <String>[];
  final userLink = row.querySelector('span.userInfo strong a.l') ??
      row.querySelector('.inner strong a.l') ??
      row.querySelector('a.l');
  final message = row.querySelector('.inner .reply_content > .message');
  final sign = row.querySelector('.inner span.sign.tip_j') ?? row.querySelector('span.sign.tip_j');

  final subs = <TopicFloor>[];
  for (final sub in row.querySelectorAll('.sub_reply_bg')) {
    final subId = sub.attributes['id']?.replaceFirst('post_', '') ?? '';
    final subInfo = sub.querySelector('.post_actions.re_info .action small');
    final parts = subInfo != null ? subInfo.text.trim().split(' - ') : const <String>[];
    final subUser = sub.querySelector('.inner strong.userName a.l') ??
        sub.querySelector('.inner strong a.l') ??
        sub.querySelector('a.l');
    subs.add(TopicFloor(
      id: subId,
      floor: parts.isNotEmpty ? parts[0].trim() : '',
      time: parts.length > 1 ? parts[1].trim() : '',
      avatar: _bgImage(sub.querySelector('span.avatarNeue')) ?? '',
      userId: core.matchAttr(subUser, 'href', RegExp(r'/user/(\d+)')),
      userName: core.htmlDecode(core.cText(subUser ?? sub)),
      userSign: core.htmlDecode(core.cText(sub.querySelector('.sign.tip_j') ?? sub)),
      messageHtml: sub.querySelector('.cmt_sub_content')?.innerHtml ?? '',
    ));
  }

  return TopicFloor(
    id: id,
    floor: info.isNotEmpty ? info[0].trim() : '',
    time: info.length > 1 ? info[1].trim() : '',
    avatar: _bgImage(row.querySelector('span.avatarNeue')) ?? '',
    userId: core.matchAttr(userLink, 'href', RegExp(r'/user/(\d+)')),
    userName: core.htmlDecode(core.cText(userLink ?? row)),
    userSign: core.htmlDecode(core.cText(sign ?? row)),
    messageHtml: message?.innerHtml ?? '',
    subs: subs,
  );
}

int _pageTotalFrom(String html) {
  var max = 1;
  for (final m in RegExp(r'[?&]page=(\d+)').allMatches(html)) {
    final v = int.tryParse(m.group(1) ?? '') ?? 0;
    if (v > max) max = v;
  }
  return max;
}

/// 解析日志页 (标题 + 正文 + 楼层)
BlogPageData parseBlogPage(String html) {
  final doc = core.parseDom(core.removeCF(html));
  final h1 = doc.querySelector('h1');
  final title = _h1Title(h1);
  final content = doc.querySelector('#entry_content')?.innerHtml ?? '';
  final userLink = doc.querySelector('#viewEntry .author a.l') ??
      doc.querySelector('.post_subject a.l') ??
      doc.querySelector('a.avatar');
  final timeEl = doc.querySelector('.header .time') ?? doc.querySelector('.tools .time');

  String time = '';
  if (timeEl != null) {
    time = timeEl.text.trim().split('·').first.trim();
  }

  final floors = <TopicFloor>[];
  final list = doc.querySelector('#comment_list');
  if (list != null) {
    for (final row in list.children.where((e) => e is Element && e.localName == 'div' && e.className.contains('row_reply'))) {
      floors.add(_parseMainFloor(row as Element));
    }
  }

  return BlogPageData(
    title: title,
    userName: core.htmlDecode(core.cText(userLink ?? doc)),
    userId: core.matchAttr(userLink, 'href', RegExp(r'/user/(\d+)')),
    avatar: _bgImage(doc.querySelector('#viewEntry .author img')) ?? '',
    time: time,
    contentHtml: content,
    floors: floors,
  );
}

/// 帖子列表行 (论坛/板块/搜索通用)
class RakuenTopicItem {
  final String topicId;
  final String title;
  final String group;
  final String groupHref;
  final String userName;
  final String userId;
  final String avatar;
  final String replies;
  final String time;

  const RakuenTopicItem({
    this.topicId = '',
    this.title = '',
    this.group = '',
    this.groupHref = '',
    this.userName = '',
    this.userId = '',
    this.avatar = '',
    this.replies = '',
    this.time = '',
  });

  int get replyCount => int.tryParse(replies.trim()) ?? 0;
}

/// 解析小组论坛 (table tr.topic)
/// 页面: https://bgm.tv/group/{name}/forum?page=N
List<RakuenTopicItem> parseGroupForum(String html) {
  final doc = core.parseDom(core.removeCF(html));
  final result = <RakuenTopicItem>[];

  for (final row in doc.querySelectorAll('tr.topic')) {
    final title = row.querySelector('td.subject a');
    final author = row.querySelector('td.author a');
    final posts = row.querySelector('td.posts');
    final last = row.querySelector('td.lastpost small.time');
    result.add(RakuenTopicItem(
      topicId: topicIdFromHref(core.cData(title, 'href')),
      title: core.htmlDecode(core.cData(title, 'title').isNotEmpty
          ? core.cData(title, 'title')
          : core.cText(title ?? row)),
      userName: core.htmlDecode(core.cText(author ?? row)),
      userId: core.matchAttr(author, 'href', RegExp(r'/user/(\d+)')),
      replies: core.cText(posts ?? row),
      time: core.cText(last ?? row),
    ));
  }
  return result;
}

/// 解析小组首页信息
GroupInfoData parseGroupHome(String html) {
  final doc = core.parseDom(core.removeCF(html));
  final h1 = doc.querySelector('h1');
  final title = h1 != null ? core.htmlDecode(h1.text.trim()) : '';
  var members = 0;
  for (final m in RegExp(r'(\d[\d,]*)').allMatches(html)) {
    final v = int.tryParse(m.group(1)!.replaceAll(',', ''));
    if (v != null && v > members && v < 100000000) members = v;
  }
  return GroupInfoData(title: title, members: members);
}

/// 解析小组成员列表
/// 页面: https://bgm.tv/group/{name}/members
List<GroupMember> parseGroupMembers(String html) {
  final doc = core.parseDom(core.removeCF(html));
  final result = <GroupMember>[];
  for (final li in doc.querySelectorAll('#memberUserList li.user')) {
    final link = li.querySelector('a');
    result.add(GroupMember(
      userId: core.matchAttr(link, 'href', RegExp(r'/user/(\d+)')),
      userName: core.htmlDecode(core.cText(li.querySelector('strong a') ?? link ?? li)),
      avatar: _bgImage(li.querySelector('img')),
    ));
  }
  return result;
}
