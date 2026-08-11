/// bgm.tv 页面 HTML 解析 (移植自原项目 utils/html + stores/rakuen/common.ts)
///
/// 原项目对超展开/帖子/小组等页面使用 cheerio 解析 HTML (而非 JSON API),
/// 因为旧版 JSON API 在后端负载均衡下不稳定。此处用 `html` 包等价移植。
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

/// 提取 start 与 end 之间的片段 (等价原项目 htmlMatch)
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

/// 查找第一个匹配 selector 的节点
Element? cFind(Element el, String selector) => el.querySelector(selector);

/// 节点 attribute 值
String cData(Element? el, String attr) => el?.attributes[attr] ?? '';

/// 元素或文档的查询 (html 包: Element 与 Document 均实现此接口)
String textOf(Object? el) {
  if (el == null) return '';
  if (el is Element) return cText(el);
  if (el is Document) return cText(el);
  return '';
}

String? querySelectorOf(Object? el, String selector) {
  if (el == null) return null;
  if (el is Element) return el.querySelector(selector)?.outerHtml;
  if (el is Document) return el.querySelector(selector)?.outerHtml;
  return null;
}

/// 匹配 attr 中的内容
String matchAttr(Element? el, String attr, RegExp regex) {
  final v = cData(el, attr);
  final m = regex.firstMatch(v);
  return m?.group(1) ?? '';
}

/// 相对中文时间 → epoch 毫秒 (刚刚/N分钟前/N小时前/N天前/M月D日/YYYY-M-D)
int? relativeEnToEpoch(String time, int loaded) {
  final t = time.trim();
  if (t.isEmpty) return null;
  final now = DateTime.fromMillisecondsSinceEpoch(loaded);

  if (t == '刚刚') return loaded;
  var m = RegExp(r'^(\d+)分钟前$').firstMatch(t);
  if (m != null) return loaded - int.parse(m.group(1)!) * 60 * 1000;
  m = RegExp(r'^(\d+)小时前$').firstMatch(t);
  if (m != null) return loaded - int.parse(m.group(1)!) * 3600 * 1000;
  m = RegExp(r'^(\d+)天前$').firstMatch(t);
  if (m != null) return loaded - int.parse(m.group(1)!) * 86400 * 1000;
  m = RegExp(r'^(\d+)月(\d+)日$').firstMatch(t);
  if (m != null) {
    final dt = DateTime(now.year, int.parse(m.group(1)!), int.parse(m.group(2)!));
    return dt.millisecondsSinceEpoch;
  }
  m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(t);
  if (m != null) {
    final dt = DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
    return dt.millisecondsSinceEpoch;
  }
  return null;
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

  /// href 形如 /group/xxx 或 /subject/xxx /ep/xxx /person/xxx /character/xxx
  String get topicId {
    final h = href.replaceFirst('/', '');
    return h;
  }

  int? get replyCount => int.tryParse(replies.trim());
}

/// 解析超展开列表页 (等价原项目 cheerioRakuen)
/// 页面: https://bgm.tv/rakuen/{scope}?type={type}
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

    result.add(RakuenItem(
      title: htmlDecode(cText(title ?? row)),
      avatar: matchAttr(avatarNeue, 'style', RegExp(r"background-image:\s*url\('?([^'\)]+)'?\)")),
      userId: cData(avatarNeue, 'data-user'),
      userName: htmlDecode(cData(row.querySelector('a.avatar'), 'title')),
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
/// 页面: https://bgm.tv/rakuen/topic/{topicId}
class RakuenFloor {
  final String id;
  final String time;
  final String floor;
  final String avatar;
  final String userId;
  final String userName;
  final String userSign;
  final String messageHtml;

  const RakuenFloor({
    this.id = '',
    this.time = '',
    this.floor = '',
    this.avatar = '',
    this.userId = '',
    this.userName = '',
    this.userSign = '',
    this.messageHtml = '',
  });
}

List<RakuenFloor> parseRakuenFloors(String html) {
  final fragment = htmlMatch(html, '<div id="comment_list"', '<div id="footer">');
  if (fragment.isEmpty) return const [];
  final doc = parseDom(removeCF(fragment));
  final result = <RakuenFloor>[];

  for (final row in doc.querySelectorAll('.commentList .row_replyclearit')) {
    final info = cText(row.querySelector('div.action small') ?? row).split(' - ');
    final name = row.querySelector('a.l');
    result.add(RakuenFloor(
      id: cData(row, 'id').replaceFirst('post_', ''),
      time: info.length > 1 ? info[1] : '',
      floor: info.isNotEmpty ? info[0] : '',
      avatar: matchAttr(
          row.querySelector('span.avatarNeue'), 'style', RegExp(r"background-image:\s*url\('?([^'\)]+)'?\)")),
      userId: matchAttr(name, 'href', RegExp(r'/user/(\d+)')),
      userName: cText(name ?? row),
      userSign: cText(row.querySelector('span.sign') ?? row),
      messageHtml: row.querySelector('.reply_content > .message')?.innerHtml ?? '',
    ));
  }
  return result;
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

/// 小组/条目/章节 帖子列表页解析
/// 页面: https://bgm.tv/group/{name}/topics?page=N 等
List<RakuenItem> parseTopicList(String html) {
  final fragment = htmlMatch(html, '<div id="topic_list', '</body');
  if (fragment.isEmpty) return const [];
  final doc = parseDom(removeCF(fragment));
  final result = <RakuenItem>[];

  for (final row in doc.querySelectorAll('ul.topicList li')) {
    final title = row.querySelector('a.topic');
    final user = row.querySelector('a.l');
    final replies = row.querySelector('small.grey');
    final time = row.querySelector('small.time');

    result.add(RakuenItem(
      title: htmlDecode(cText(title ?? row)),
      href: cData(title, 'href'),
      userName: htmlDecode(cText(user ?? row)),
      userId: matchAttr(user, 'href', RegExp(r'/user/(\d+)')),
      replies: cText(replies ?? row),
      time: cText(time ?? row),
    ));
  }
  return result;
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

/// 帖子标题 + 主楼内容 (页面 https://bgm.tv/rakuen/topic/{topicId})
({String title, String user, String contentHtml}) parseTopicHeader(String html) {
  final doc = parseDom(removeCF(html));
  final title = doc.querySelector('h1') ?? doc.querySelector('#topic_subject');
  final user = doc.querySelector('.post_subject a.l') ?? doc.querySelector('a.avatar');
  final content = doc.querySelector('#comment_list .message') ??
      doc.querySelector('.reply_content .message');
  return (
    title: htmlDecode(title?.text.trim() ?? ''),
    user: htmlDecode(user?.text.trim() ?? ''),
    contentHtml: content?.innerHtml ?? '',
  );
}

/// 生成抓取用的 URL
String rakueHtmlUrl(String scope, String type) {
  final t = type.isEmpty ? '' : '?type=$type';
  return 'https://bgm.tv/rakuen/$scope$t';
}

/// 主题页 URL
String topicHtmlUrl(String topicId, {int page = 1}) {
  return 'https://bgm.tv/rakuen/topic/$topicId${page > 1 ? '?page=$page' : ''}';
}

/// 小组话题页 URL
String groupTopicsHtmlUrl(String group, {int page = 1}) {
  return 'https://bgm.tv/group/$group/topics${page > 1 ? '?page=$page' : ''}';
}
