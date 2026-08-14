/// 超展开域 HTML 抓取与解析
///
/// 通用工具与已核对的选择器复用 lib/core/html/bgm_html_parser.dart;
/// 本模块补充小组论坛 (table tr.topic)、小组成员、日志页、帖子主楼等
/// 线上页面结构解析, 以及 URL 生成。
library;

import 'package:html/dom.dart';

import '../../core/html/bgm_html_parser.dart' as core;

/// 帖子页 URL (core 已映射 canonical 路径: /group/topic/N /subject/topic/N ...)
String topicPageUrl(String topicId, {int page = 1}) =>
    core.topicHtmlUrl(topicId, page: page);

/// 小组论坛 URL
String groupForumPageUrl(String group, {int page = 1}) =>
    core.groupTopicsHtmlUrl(group, page: page);

/// 小组首页 URL
String groupHomePageUrl(String group) => 'https://bgm.tv/group/$group';

/// 小组成员 URL
String groupMembersPageUrl(String group) =>
    'https://bgm.tv/group/$group/members';

/// 日志页 URL
String blogPageUrl(int blogId) => 'https://bgm.tv/blog/$blogId';

/// 超展开板块列表 URL (支持分页)
String rakuenBoardPageUrl(String scope, {String type = '', int page = 1}) {
  var url = core.rakueHtmlUrl(scope, type);
  if (page > 1) url = '$url${url.contains('?') ? '&' : '?'}page=$page';
  return url;
}

/// href → topicId ('group/350677' / 'blog/123')
String topicIdFromHref(String href) {
  var h = href;
  h = h.replaceFirst(RegExp(r'^/rakuen/topic/'), '');
  h = h.replaceFirst(RegExp(r'^/group/topic/'), 'group/');
  h = h.replaceFirst(RegExp(r'^/subject/topic/'), 'subject/');
  h = h.replaceFirst(RegExp(r'^/character/topic/'), 'crt/');
  h = h.replaceFirst(RegExp(r'^/person/topic/'), 'prsn/');
  h = h.replaceFirst(RegExp(r'^/ep/'), 'ep/');
  h = h.replaceFirst(RegExp(r'^/blog/'), 'blog/');
  return h.replaceFirst(RegExp(r'^/'), '');
}

/// 帖子详情页解析结果
class TopicPageData {
  final String title;
  final String group;
  final String groupHref;
  final String groupThumb;
  final String userName;
  final String userId;
  final String avatar;
  final String time;
  final String contentHtml;
  final List<core.RakuenFloor> floors;
  final int pageTotal;

  const TopicPageData({
    this.title = '',
    this.group = '',
    this.groupHref = '',
    this.groupThumb = '',
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
  final List<core.RakuenFloor> floors;

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

class GroupInfoData {
  final String title;
  final String icon;
  final int members;
  final String joinUrl;
  final String byeUrl;

  const GroupInfoData({
    this.title = '',
    this.icon = '',
    this.members = 0,
    this.joinUrl = '',
    this.byeUrl = '',
  });

  bool get joined => byeUrl.isNotEmpty;
}

/// 小组成员
class GroupMember {
  final String userId;
  final String userName;
  final String avatar;

  const GroupMember({this.userId = '', this.userName = '', this.avatar = ''});
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

  int get replyCount =>
      int.tryParse(replies.replaceAll(RegExp(r'[()+\s]'), '')) ?? 0;
}

String _bgUrl(String url) => url.startsWith('//') ? 'https:$url' : url;

String? _bgImage(Element? el) {
  if (el == null) return null;
  final avatar = core.matchAvatar(el);
  if (avatar.isNotEmpty) return _bgUrl(avatar);
  final src = el.attributes['src'] ?? '';
  return src.isEmpty ? null : _bgUrl(src);
}

/// 提取 h1 标题 (帖子页标题在 <br> 之后, 前面是小组面包屑)
String _h1Title(Element? h1) {
  if (h1 == null) return '';
  final html = h1.innerHtml;
  final parts = html.split(RegExp(r'<br\s*/?>'));
  if (parts.length > 1) {
    // 取 <br> 后的片段并去除残留标签 (html 包对裸文本片段解析不可靠)
    final raw = parts.last.replaceAll(RegExp(r'<[^>]+>'), '').trim();
    return core.htmlDecode(raw);
  }
  return core.htmlDecode(h1.text.trim());
}

/// 解析楼层 (主楼层 + 子回复)
/// 页面: 帖子/日志页 #comment_list > div.row_reply
List<core.RakuenFloor> parseTopicFloors(String html) {
  final doc = core.parseDom(core.removeCF(html));
  final result = <core.RakuenFloor>[];

  final list = doc.querySelector('#comment_list');
  if (list == null) return result;

  for (final child in list.children) {
    if (child.localName != 'div' ||
        !child.className.split(' ').contains('row_reply')) {
      continue;
    }
    result.add(_parseFloor(child));
  }
  return result;
}

core.RakuenFloor _parseFloor(Element row) {
  final reInfo = row.querySelector('.post_actions.re_info .action small');
  final info = reInfo != null
      ? reInfo.text.trim().split(' - ')
      : const <String>[];
  final userLink =
      row.querySelector('.inner .userInfo strong a.l') ??
      row.querySelector('.inner strong a.l') ??
      row.querySelector('a.l');
  final message = row.querySelector('.inner .reply_content > .message');
  final sign =
      row.querySelector('.inner .sign.tip_j') ??
      row.querySelector('span.sign.tip_j');

  final subReplies = <core.RakuenFloor>[];
  for (final sub in row.querySelectorAll(
    '.topic_sub_reply > div.sub_reply_bg',
  )) {
    final subInfo = sub.querySelector('.post_actions.re_info .action small');
    final parts = subInfo != null
        ? subInfo.text.trim().split(' - ')
        : const <String>[];
    final subUser =
        sub.querySelector('.inner strong.userName a.l') ??
        sub.querySelector('.inner strong a.l') ??
        sub.querySelector('a.l');
    subReplies.add(
      core.RakuenFloor(
        id: (sub.attributes['id'] ?? '').replaceFirst('post_', ''),
        floor: parts.isNotEmpty ? parts[0].trim() : '',
        time: parts.length > 1 ? parts[1].trim() : '',
        avatar: _bgImage(sub.querySelector('span.avatarNeue')) ?? '',
        userId: core.matchAttr(subUser, 'href', RegExp(r'/user/(\d+)')),
        userName: core.htmlDecode(core.cText(subUser ?? sub)),
        userSign: core.htmlDecode(
          core.cText(sub.querySelector('.sign.tip_j') ?? sub),
        ),
        messageHtml: sub.querySelector('.cmt_sub_content')?.innerHtml ?? '',
        likes:
            int.tryParse(
              RegExp(r'(\d+)')
                      .firstMatch(
                        core.cText(
                          sub.querySelector('.likes_grid') ??
                              sub.querySelector('.ico_like'),
                        ),
                      )
                      ?.group(1) ??
                  '',
            ) ??
            0,
      ),
    );
  }

  return core.RakuenFloor(
    id: (row.attributes['id'] ?? '').replaceFirst('post_', ''),
    floor: info.isNotEmpty ? info[0].trim() : '',
    time: info.length > 1 ? info[1].trim() : '',
    avatar: _bgImage(row.querySelector('span.avatarNeue')) ?? '',
    userId: core.matchAttr(userLink, 'href', RegExp(r'/user/(\d+)')),
    userName: core.htmlDecode(core.cText(userLink ?? row)),
    userSign: core.htmlDecode(core.cText(sign ?? row)),
    messageHtml: message?.innerHtml ?? '',
    likes:
        int.tryParse(
          RegExp(r'(\d+)')
                  .firstMatch(
                    core.cText(
                      row.querySelector('.likes_grid') ??
                          row.querySelector('.ico_like'),
                    ),
                  )
                  ?.group(1) ??
              '',
        ) ??
        0,
    subReplies: subReplies,
  );
}

/// 解析帖子页 (主楼 + 楼层)
/// 兼容 group/subject/ep 帖子页 (div.postTopic) 与 prsn/crt 页面 (仅楼层)
TopicPageData parseTopicPage(String html) {
  final doc = core.parseDom(core.removeCF(html));

  final postTopic = doc.querySelector('div.postTopic');
  final h1 = doc.querySelector('#pageHeader h1') ?? doc.querySelector('h1');
  final group = doc.querySelector('#pageHeader a.avatar');

  String groupName = '';
  String groupHref = '';
  String groupThumb = '';
  if (group != null) {
    groupName = core.htmlDecode(group.text.trim());
    groupHref = group.attributes['href'] ?? '';
    groupThumb = _bgImage(group.querySelector('img.avatar')) ?? '';
  }
  if (groupThumb.isEmpty) {
    groupThumb =
        _bgImage(doc.querySelector('#pageHeader a.avatar img.avatar')) ?? '';
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
    final userLink =
        postTopic.querySelector('.inner strong a.l') ??
        postTopic.querySelector('a.l');
    final reInfo = postTopic.querySelector(
      '.post_actions.re_info .action small',
    );
    final t = reInfo != null
        ? reInfo.text.trim().split(' - ')
        : const <String>[];
    userName = core.htmlDecode(core.cText(userLink ?? postTopic));
    userId = core.matchAttr(userLink, 'href', RegExp(r'/user/(\d+)'));
    avatar = _bgImage(postTopic.querySelector('span.avatarNeue')) ?? '';
    time = t.length > 1 ? t[1].trim() : '';
    contentHtml = postTopic.querySelector('.topic_content')?.innerHtml ?? '';
  } else if (h1 != null) {
    // prsn/crt 页面: 主楼为空, 标题取页面 h1
    title = _h1Title(h1);
  }

  return TopicPageData(
    title: title,
    group: groupName,
    groupHref: groupHref,
    groupThumb: groupThumb,
    userName: userName,
    userId: userId,
    avatar: avatar,
    time: time,
    contentHtml: contentHtml,
    floors: parseTopicFloors(html),
    pageTotal: _pageTotalFrom(html),
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
  final userLink =
      doc.querySelector('#viewEntry .author a.l') ??
      doc.querySelector('.post_subject a.l') ??
      doc.querySelector('a.avatar');
  final timeEl =
      doc.querySelector('.header .time') ?? doc.querySelector('.tools .time');

  String time = '';
  if (timeEl != null) {
    time = timeEl.text.trim().split('·').first.trim();
  }

  return BlogPageData(
    title: title,
    userName: core.htmlDecode(core.cText(userLink ?? doc)),
    userId: core.matchAttr(userLink, 'href', RegExp(r'/user/(\d+)')),
    avatar: _bgImage(doc.querySelector('#viewEntry .author img')) ?? '',
    time: time,
    contentHtml: content,
    floors: parseTopicFloors(html),
  );
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
    result.add(
      RakuenTopicItem(
        topicId: topicIdFromHref(core.cData(title, 'href')),
        title: core.htmlDecode(
          core.cData(title, 'title').isNotEmpty
              ? core.cData(title, 'title')
              : core.cText(title ?? row),
        ),
        userName: core.htmlDecode(core.cText(author ?? row)),
        userId: core.matchAttr(author, 'href', RegExp(r'/user/(\d+)')),
        replies: posts?.text.trim() ?? '',
        time: last?.text.trim() ?? '',
      ),
    );
  }
  return result;
}

/// 解析小组首页信息
GroupInfoData parseGroupHome(String html) {
  final doc = core.parseDom(core.removeCF(html));
  final h1 = doc.querySelector('h1');
  final title = h1 != null ? core.htmlDecode(h1.text.trim()) : '';
  final iconEl =
      doc.querySelector('.header .avatar img') ??
      doc.querySelector('#pageHeader a.avatar img') ??
      doc.querySelector('a.avatar img');
  final icon = _bgImage(iconEl) ?? '';
  var members = 0;
  for (final m in RegExp(r'(\d[\d,]*)').allMatches(html)) {
    final v = int.tryParse(m.group(1)!.replaceAll(',', ''));
    if (v != null && v > members && v < 100000000) members = v;
  }
  final joinHref =
      doc.querySelector('#groupJoinAction a.chiiBtn')?.attributes['href'] ?? '';
  var joinUrl = '';
  var byeUrl = '';
  if (joinHref.contains('/join?')) {
    joinUrl = joinHref;
  } else if (joinHref.contains('/bye?')) {
    byeUrl = joinHref;
  }
  return GroupInfoData(
    title: title,
    icon: icon,
    members: members,
    joinUrl: joinUrl,
    byeUrl: byeUrl,
  );
}

/// 解析小组成员列表
/// 页面: https://bgm.tv/group/{name}/members
List<GroupMember> parseGroupMembers(String html) {
  final doc = core.parseDom(core.removeCF(html));
  final result = <GroupMember>[];
  for (final li in doc.querySelectorAll('#memberUserList li.user')) {
    final link = li.querySelector('a');
    result.add(
      GroupMember(
        userId: core.matchAttr(link, 'href', RegExp(r'/user/(\d+)')),
        userName: core.htmlDecode(
          core.cText(li.querySelector('strong a') ?? link ?? li),
        ),
        avatar: _bgImage(li.querySelector('img')) ?? '',
      ),
    );
  }
  return result;
}
