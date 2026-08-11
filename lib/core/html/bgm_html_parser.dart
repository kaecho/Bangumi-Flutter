/// bgm.tv 页面 HTML 解析 (移植自原项目 utils/html + stores/rakuen/common.ts)
///
/// 原项目对超展开/帖子/小组等页面使用 cheerio 解析 HTML (而非 JSON API),
/// 因为旧版 JSON API 在后端负载均衡下不稳定。此处用 `html` 包等价移植。
///
/// 选择器已对照 2026-08 线上页面验证:
/// - 列表页: /rakuen/{scope}/topiclist?type={type} → li.item_list
/// - 楼层: #comment_list > div.row_reply (+ div.sub_reply_bg)
library;

import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';

/// HTML 反转义
String htmlDecode(String str) {
  return str
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#x27;', "'")
      .replaceAll('&ldquo;', '“')
      .replaceAll('&rdquo;', '”');
}

/// 去除 cloudflare 插入的 DOM
String removeCF(String html) {
  return html
      .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '')
      .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '');
}

/// 提取 start 与 end 之间的片段 (等价原项目 htmlMatch, 不含 end)
String htmlMatch(String html, String start, String end) {
  final s = html.indexOf(start);
  if (s < 0) return '';
  final e = html.indexOf(end, s + start.length);
  if (e < 0) return html.substring(s);
  return html.substring(s, e);
}

/// 解析为 DOM 文档
Document parseDom(String html) => parser.parse(html);

/// 节点清理后的纯文本 (Element 或 Document)
String cText(Object? el) {
  if (el == null) return '';
  final raw = el is Element ? el.text : (el as Document).text;
  final text = raw?.trim() ?? '';
  return htmlDecode(text.replaceAll(RegExp(r'\s+'), ' '));
}

/// 节点 attribute 值
String cData(Element? el, String attr) => el?.attributes[attr] ?? '';

/// 匹配 attr 中的内容
String matchAttr(Element? el, String attr, RegExp regex) {
  final v = cData(el, attr);
  final m = regex.firstMatch(v);
  return m?.group(1) ?? '';
}

/// 从 style 中匹配头像地址
/// eg: background-image:url('//lain.bgm.tv/pic/user/l/xxx.jpg?r=1&hd=1')
String matchAvatar(Element? el) {
  return matchAttr(
    el,
    'style',
    RegExp(r"background-image:\s*url\('?([^'\)]+)'?\)"),
  );
}

/// 中文相对时间 ("3天15时前") 转 epoch 毫秒 (等价原项目 relativeToEpoch)
int? relativeToEpoch(String time, int loaded) {
  if (!time.contains('前')) return null;
  var relativePart = time.trim();
  final suffixIdx = relativePart.indexOf(' · ');
  if (suffixIdx > 0) relativePart = relativePart.substring(0, suffixIdx);

  const units = [
    ('年', 60 * 60 * 24 * 365),
    ('月', 60 * 60 * 24 * 30),
    ('周', 60 * 60 * 24 * 7),
    ('天', 86400),
    ('时', 3600),
    ('分', 60),
    ('秒', 1),
  ];
  var offset = 0;
  for (final (unit, seconds) in units) {
    final m = RegExp('(\\d+)$unit').firstMatch(relativePart);
    if (m != null) offset += int.parse(m.group(1)!) * seconds;
  }
  return offset > 0 ? loaded - offset * 1000 : null;
}

/// 英文相对时间 ("...1h 2m ago") 转 epoch 毫秒 (等价原项目 relativeEnToEpoch)
int? relativeEnToEpoch(String time, int loaded) {
  final clean = time.replaceFirst(RegExp(r'^\.\.\.'), '').trim();
  if (!clean.contains('ago')) return null;
  final relative = clean.replaceFirst(RegExp(r'\s*ago$'), '').trim();
  var offset = 0;

  final y = RegExp(r'(\d+)\s*y(?!\w)').firstMatch(relative);
  if (y != null) offset += int.parse(y.group(1)!) * 60 * 60 * 24 * 365;
  final mo = RegExp(r'(\d+)\s*mo(?!\w)').firstMatch(relative);
  if (mo != null) offset += int.parse(mo.group(1)!) * 60 * 60 * 24 * 30;
  final w = RegExp(r'(\d+)\s*w(?!\w)').firstMatch(relative);
  if (w != null) offset += int.parse(w.group(1)!) * 60 * 60 * 24 * 7;
  final d = RegExp(r'(\d+)\s*d(?!\w)').firstMatch(relative);
  if (d != null) offset += int.parse(d.group(1)!) * 86400;
  final h = RegExp(r'(\d+)\s*h(?!\w)').firstMatch(relative);
  if (h != null) offset += int.parse(h.group(1)!) * 3600;
  final m = RegExp(r'(\d+)\s*m(?!\w)').firstMatch(relative);
  if (m != null) offset += int.parse(m.group(1)!) * 60;
  final s = RegExp(r'(\d+)\s*s(?!\w)').firstMatch(relative);
  if (s != null) offset += int.parse(s.group(1)!);

  return offset > 0 ? loaded - offset * 1000 : null;
}

/// 兼容两种格式的相对时间
int? relativeTimeToEpoch(String time, int loaded) {
  return relativeEnToEpoch(time, loaded) ?? relativeToEpoch(time, loaded);
}

/// 超展开列表项 (等价原项目 RakuenItem)
class RakuenItem {
  final String title;
  final String avatar;
  final String userId;
  final String userName;
  final String href;
  final String replies;
  final String group;
  final String groupHref;
  final String time;

  const RakuenItem({
    this.title = '',
    this.avatar = '',
    this.userId = '',
    this.userName = '',
    this.href = '',
    this.replies = '',
    this.group = '',
    this.groupHref = '',
    this.time = '',
  });

  /// 帖子 id, 如 group/468570
  /// href 形如 /rakuen/topic/group/468570 或 /group/topic/468570
  String get topicId {
    var h = href;
    h = h.replaceFirst(RegExp(r'^/rakuen/topic/'), '');
    h = h.replaceFirst(RegExp(r'^/group/topic/'), 'group/');
    h = h.replaceFirst(RegExp(r'^/subject/topic/'), 'subject/');
    h = h.replaceFirst(RegExp(r'^/character/topic/'), 'crt/');
    h = h.replaceFirst(RegExp(r'^/person/topic/'), 'prsn/');
    h = h.replaceFirst(RegExp(r'^/ep/'), 'ep/');
    h = h.replaceFirst(RegExp(r'^/'), '');
    return h;
  }

  int? get replyCount {
    final m = RegExp(r'\((\+?)(\d+)\)').firstMatch(replies.trim());
    if (m != null) return int.tryParse(m.group(2)!);
    return int.tryParse(replies.trim());
  }
}

/// 解析超展开列表页 (等价原项目 cheerioRakuen)
/// 页面: https://bgm.tv/rakuen/{scope}/topiclist?type={type}
List<RakuenItem> parseRakuenList(String html) {
  final fragment = htmlMatch(html, '<div id="eden_tpc_list', '</body');
  if (fragment.isEmpty) return const [];
  final doc = parseDom(removeCF(fragment));
  final result = <RakuenItem>[];

  for (final row in doc.querySelectorAll('li.item_list')) {
    final avatarNeue = row.querySelector('span.avatarNeue');
    final inner = row.querySelector('div.inner');
    final title = inner?.querySelector('a.title');
    final rowInner = inner?.querySelector('span.row');
    final group = rowInner?.querySelector('a');
    final avatarLink = row.querySelector('a.avatar');

    result.add(RakuenItem(
      title: htmlDecode(cText(title ?? row)),
      avatar: matchAvatar(avatarNeue),
      userId: cData(avatarNeue, 'data-user'),
      userName: htmlDecode(cData(avatarLink, 'title')),
      href: cData(title, 'href'),
      replies: cText(inner?.querySelector('small.grey') ?? row),
      group: htmlDecode(cText(group ?? row)),
      groupHref: cData(group, 'href'),
      time: cText(rowInner?.querySelector('small.time') ?? row),
    ));
  }
  return result;
}

/// 帖子楼层 (等价原项目 cheerioComments)
/// 页面: https://bgm.tv/group/topic/{id} 等
class RakuenFloor {
  final String id;
  final String time;
  final String floor;
  final String avatar;
  final String userId;
  final String userName;
  final String userSign;
  final String messageHtml;
  final List<RakuenFloor> subReplies;

  const RakuenFloor({
    this.id = '',
    this.time = '',
    this.floor = '',
    this.avatar = '',
    this.userId = '',
    this.userName = '',
    this.userSign = '',
    this.messageHtml = '',
    this.subReplies = const [],
  });
}

RakuenFloor _parseFloor(Element row) {
  final action = cText(row.querySelector('.action small') ?? row);
  final info = action.split(' - ');
  final name = row.querySelector('.inner .userInfo a.l') ?? row.querySelector('a.l');
  return RakuenFloor(
    id: cData(row, 'id').replaceFirst('post_', ''),
    time: info.length > 1 ? info[1] : '',
    floor: info.isNotEmpty ? info[0] : '',
    avatar: matchAvatar(row.querySelector('span.avatarNeue')),
    userId: matchAttr(name, 'href', RegExp(r'/user/(\d+)')),
    userName: htmlDecode(cText(name)),
    userSign: cText(row.querySelector('.inner .sign')),
    messageHtml: row.querySelector('.reply_content > .message')?.innerHtml ?? '',
    subReplies: [
      for (final sub in row.querySelectorAll('div.topic_sub_reply > div.sub_reply_bg'))
        _parseSubFloor(sub),
    ],
  );
}

/// 子楼层正文节点 (.cmt_sub_content)
RakuenFloor _parseSubFloor(Element row) {
  final action = cText(row.querySelector('.action small') ?? row);
  final info = action.split(' - ');
  final name = row.querySelector('.inner .userInfo a.l') ?? row.querySelector('a.l');
  return RakuenFloor(
    id: cData(row, 'id').replaceFirst('post_', ''),
    time: info.length > 1 ? info[1] : '',
    floor: info.isNotEmpty ? info[0] : '',
    avatar: matchAvatar(row.querySelector('span.avatarNeue')),
    userId: matchAttr(name, 'href', RegExp(r'/user/(\d+)')),
    userName: htmlDecode(cText(name)),
    userSign: cText(row.querySelector('.inner .sign')),
    messageHtml: row.querySelector('.cmt_sub_content')?.innerHtml ?? '',
  );
}

List<RakuenFloor> parseRakuenFloors(String html) {
  final fragment = htmlMatch(html, '<div id="comment_list"', '<div id="footer">');
  if (fragment.isEmpty) return const [];
  final doc = parseDom(removeCF(fragment));
  return [
    for (final row in doc.querySelectorAll('#comment_list > div.row_reply')) _parseFloor(row),
  ];
}

/// 解析分页: 当前页/总页数 (bgm.tv 分页 DOM)
({int page, int pageTotal}) cPagination(String html) {
  final fragment = htmlMatch(html, '<div id="comment_list"', '<div id="footer">');
  final doc = parseDom(removeCF(fragment.isEmpty ? html : fragment));
  final pageInfo = doc.querySelector('.page_inner');
  if (pageInfo == null) return (page: 1, pageTotal: 1);
  final text = cText(pageInfo);
  final m = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(text);
  if (m != null) {
    return (page: int.tryParse(m.group(1)!) ?? 1, pageTotal: int.tryParse(m.group(2)!) ?? 1);
  }
  return (page: 1, pageTotal: 1);
}

/// 小组/条目 帖子列表页解析 (已对照线上页面)
/// 页面: https://bgm.tv/group/{name}/forum 等 (table > tr.topic)
/// 列结构: td.subject a(标题+楼主) / td.posts(回复数) / td.lastpost small.time
List<RakuenItem> parseTopicList(String html) {
  final fragment = htmlMatch(html, '<div id="topic_list', '</body');
  if (fragment.isEmpty) return const [];
  final doc = parseDom(removeCF(fragment));
  final result = <RakuenItem>[];

  for (final row in doc.querySelectorAll('tr.topic')) {
    final title = row.querySelector('td.subject a');
    final user = row.querySelector('td.subject a.l');
    final replies = row.querySelector('td.posts');
    final time = row.querySelector('td.lastpost small.time');

    result.add(RakuenItem(
      title: htmlDecode(cText(title ?? row)),
      href: cData(title, 'href'),
      userName: htmlDecode(cText(user)),
      userId: matchAttr(user, 'href', RegExp(r'/user/(\d+)')),
      replies: cText(replies),
      time: cText(time),
    ));
  }
  return result;
}

/// 小组帖子列表行 (tr.topic) 的完整字段 (含 是否置顶/精华)
class GroupTopicRow {
  final String title;
  final String href;
  final String userName;
  final String userId;
  final String replies;
  final String time;
  final bool pin;

  const GroupTopicRow({
    this.title = '',
    this.href = '',
    this.userName = '',
    this.userId = '',
    this.replies = '',
    this.time = '',
    this.pin = false,
  });
}

/// 解析小组讨论区 (live tr.topic 结构, 兼容置顶行 tr.row_top)
List<GroupTopicRow> parseGroupForum(String html) {
  final fragment = htmlMatch(html, '<div id="topic_list', '</body');
  if (fragment.isEmpty) return const [];
  final doc = parseDom(removeCF(fragment));
  final result = <GroupTopicRow>[];

  for (final row in doc.querySelectorAll('tr.topic, tr.row_top')) {
    final title = row.querySelector('td.subject a');
    final user = row.querySelector('td.subject a.l');
    final replies = row.querySelector('td.posts');
    final time = row.querySelector('td.lastpost small.time');
    result.add(GroupTopicRow(
      title: htmlDecode(cText(title ?? row)),
      href: cData(title, 'href'),
      userName: htmlDecode(cText(user)),
      userId: matchAttr(user, 'href', RegExp(r'/user/(\d+)')),
      replies: cText(replies),
      time: cText(time),
      pin: row.className.contains('row_top'),
    ));
  }
  return result;
}

/// 解析小组会员列表
/// 页面: https://bgm.tv/group/{name}/members (#memberUserList li.user)
List<String> parseGroupMembers(String html) {
  final fragment = htmlMatch(html, '<div id="memberUserList', '</div>');
  if (fragment.isEmpty) return const [];
  final doc = parseDom(removeCF(fragment));
  return [
    for (final row in doc.querySelectorAll('li.user a.avatar'))
      htmlDecode(cData(row, 'title')),
  ];
}

/// 小组信息解析: 标题/成员数 (页面 https://bgm.tv/group/{name})
({String title, String content, int members}) parseGroupInfo(String html) {
  final doc = parseDom(removeCF(html));
  final title = doc.querySelector('#group_subject h1') ?? doc.querySelector('h1');
  final members = doc.querySelector('.member_list .title') ?? doc.querySelector('span.tip');
  final m = members != null ? RegExp(r'(\d+)').firstMatch(members.text) : null;
  return (
    title: htmlDecode(title?.text.trim() ?? ''),
    content: '',
    members: m != null ? int.tryParse(m.group(1)!) ?? 0 : 0,
  );
}

/// 帖子标题 + 主楼内容 (页面 https://bgm.tv/group/topic/{id})
/// 主楼: div.postTopic .topic_content; 标题 h1 (换行分隔 中文/日文名)
({String title, String user, String contentHtml}) parseTopicHeader(String html) {
  final doc = parseDom(removeCF(html));
  final title = doc.querySelector('h1') ?? doc.querySelector('#topic_subject');
  final user = doc.querySelector('.postTopic a.l') ?? doc.querySelector('a.avatar');
  final content = doc.querySelector('.postTopic .topic_content') ??
      doc.querySelector('#comment_list .message');
  return (
    title: htmlDecode((title?.text ?? '').replaceFirst(RegExp(r'\s*<br\s*/?>'), ' ').trim()),
    user: htmlDecode(user?.text.trim() ?? ''),
    contentHtml: content?.innerHtml ?? '',
  );
}

/// 生成抓取用的 URL (列表页: /rakuen/{scope}/topiclist?type={type})
String rakueHtmlUrl(String scope, String type) {
  final t = type.isEmpty ? '' : '?type=$type';
  return 'https://bgm.tv/rakuen/$scope/topiclist$t';
}

/// 主题页 URL (注意: /rakuen/topic/group/N 会 JS 跳转到 /group/topic/N)
String topicHtmlUrl(String topicId, {int page = 1}) {
  final type = topicId.split('/').first;
  final id = topicId.split('/').last;
  final path = switch (type) {
    'group' => '/group/topic/$id',
    'subject' => '/subject/topic/$id',
    'ep' => '/ep/$id',
    'prsn' => '/person/$id',
    'crt' => '/character/$id',
    _ => '/rakuen/topic/$topicId',
  };
  return 'https://bgm.tv$path${page > 1 ? '?page=$page' : ''}';
}

/// 小组话题页 URL (/group/{name}/forum)
String groupTopicsHtmlUrl(String group, {int page = 1}) {
  return 'https://bgm.tv/group/$group/forum${page > 1 ? '?page=$page' : ''}';
}

/// 解析 formhash (登录页隐藏字段, 点赞/加好友/编辑等操作必需)
/// 页面: https://bgm.tv/settings/privacy 等登录后页面
String parseFormhash(String html) {
  final doc = parseDom(removeCF(html));
  final input = doc.querySelector('input[name=formhash]');
  return input?.attributes['value'] ?? '';
}
