/// bgm.tv 主站 HTML 解析 (package:html 版, 对应原项目 cheerio 解析器)
///
/// 原项目部分屏幕 (排行榜/日志/小组/标签/维基/频道/新番/年鉴等) 通过抓取
/// bgm.tv 主站 HTML 页面获得数据 (旧版 JSON API 已下线, 返回 404)。这里
/// 复用 lib/core/html/bgm_html_parser.dart 的解析基础设施。
library;

import 'package:html/parser.dart' as parser;

import '../../../core/html/bgm_html_parser.dart';
import '../../../shared/models/group.dart';
import '../../../shared/models/subject.dart';
import '../../../shared/models/user.dart';

/// 绝对化图片地址 (//lain.bgm.tv/... → https://lain.bgm.tv/...)
String _abs(String url) {
  if (url.isEmpty) return '';
  if (url.startsWith('//')) return 'https:$url';
  return url;
}

/// 条目类型值 → 类型名 (1=book 2=anime 4=game 6=real)
String _typeName(int type) => switch (type) {
      1 => 'book',
      4 => 'game',
      6 => 'real',
      _ => 'anime',
    };

/// 浏览器 / 排行榜 / 标签条目页共用的条目列表解析
///
/// 页面: /{type}/browser?sort=..&page=.. 与 /{type}/tag/{tag}?page=..
/// 结构: `<li id="item_N" class="item odd clearit"> ... </li>`
List<Subject> parseSubjectList(String html) {
  final doc = parser.parse(html);
  final container = doc.querySelector('#browserItemList') ?? doc;
  final items = <Subject>[];
  for (final li in container.querySelectorAll('li.item')) {
    final idMatch = RegExp(r'item_(\d+)').firstMatch(li.id);
    final id = int.tryParse(idMatch?.group(1) ?? '') ?? 0;
    if (id == 0) continue;

    final titleA = li.querySelector('h3 a.l');
    final jpEl = li.querySelector('h3 small.grey');
    final img = li.querySelector('img');
    final rankEl = li.querySelector('span.rank');
    final info = li.querySelector('p.info');
    final scoreEl = li.querySelector('small.fade');
    final totalEl = li.querySelector('.rateInfo .tip_j');
    final typeEl = li.querySelector('span.subject_type_\\d');

    final infoText = cText(info);
    final epsMatch = RegExp(r'(\d+)话').firstMatch(infoText);
    final dateMatch = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(infoText);
    final totalText = cText(totalEl).replaceAll(RegExp(r'[()人评分]'), '');

    items.add(Subject(
      id: id,
      type: typeEl == null ? 'anime' : _typeName(typeEl.className.contains('subject_type_1') ? 1 : (typeEl.className.contains('subject_type_4') ? 4 : (typeEl.className.contains('subject_type_6') ? 6 : 2))),
      name: jpEl == null ? cText(titleA) : htmlDecode(jpEl.text.trim()),
      nameCn: cText(titleA),
      images: SubjectImages(medium: img == null ? '' : _abs(img.attributes['src'] ?? '')),
      eps: int.tryParse(epsMatch?.group(1) ?? '') ?? 0,
      airDate: dateMatch == null
          ? ''
          : '${dateMatch.group(1)}-${dateMatch.group(2)}-${dateMatch.group(3)}',
      rank: int.tryParse(cText(rankEl).replaceAll(RegExp(r'[^\d]'), '')) ?? 0,
      rating: Rating(
        score: double.tryParse(cText(scoreEl)) ?? 0,
        total: int.tryParse(totalText) ?? 0,
      ),
    ));
  }
  return items;
}

/// 小组列表解析
///
/// 页面: https://bgm.tv/group
/// 结构: `<li><a href="/group/name" title="..."><span class="pictureFrameGroup">...
///   <img src="//lain...icon..."></span>...名称</a><br /><small class="feed">N 位成员</small></li>`
List<Group> parseGroupList(String html) {
  final doc = parser.parse(html);
  final groups = <Group>[];
  for (final li in doc.querySelectorAll('ul.groupsLarge > li')) {
    final a = li.querySelector('a[href^="/group/"]');
    if (a == null) continue;
    final img = a.querySelector('img');
    final feed = li.querySelector('small.feed');
    final name = (a.attributes['href'] ?? '').replaceFirst('/group/', '');
    final membersText = cText(feed).replaceAll(RegExp(r'[^\d]'), '');
    groups.add(Group(
      name: name,
      title: htmlDecode(a.attributes['title'] ?? ''),
      icon: img == null ? '' : _abs(img.attributes['src'] ?? ''),
      members: int.tryParse(membersText) ?? 0,
    ));
  }
  return groups;
}

/// 日志列表行 (全站日志 / 频道日志)
class BlogListRow {
  final int id;
  final String title;
  final String cover;
  final String time;
  final String content;
  final int userId;
  final String username;
  final int replies;

  const BlogListRow({
    this.id = 0,
    this.title = '',
    this.cover = '',
    this.time = '',
    this.content = '',
    this.userId = 0,
    this.username = '',
    this.replies = 0,
  });
}

/// 日志列表解析
///
/// 页面: https://bgm.tv/blog/{page}.html
/// 结构: `<div class="item clearit" data-item-user="N"> <p class="cover">...</p>
///   <div class="entry"> <h2 class="title"><a href="/blog/N" class="l">标题</a></h2>
///   <div class="content">...</div> <div class="time"> <a href="/user/N" class="l">用户名</a>
///   · 时间 · <a href="/blog/N" class="l">N 回复</a> </div>`
List<BlogListRow> parseBlogList(String html) {
  final fragment = htmlMatch(html, '<div id="entry_list', '<div id="columnB"');
  final doc = parser.parse(fragment.isEmpty ? html : fragment);
  final list = doc.querySelector('#entry_list');
  if (list == null) return const [];

  final rows = <BlogListRow>[];
  for (final item in list.querySelectorAll('div.item')) {
    final titleA = item.querySelector('h2.title a');
    if (titleA == null) continue;
    final idMatch = RegExp(r'/blog/(\d+)').firstMatch(titleA.attributes['href'] ?? '');
    final id = int.tryParse(idMatch?.group(1) ?? '') ?? 0;
    if (id == 0) continue;

    final img = item.querySelector('a.avatar img');
    final contentA = item.querySelector('.content a') ?? item.querySelector('.content');
    final timeEl = item.querySelector('.time');
    final timeText = timeEl == null ? '' : htmlDecode(timeEl.text.replaceAll(RegExp(r'\s+'), ' ').trim());
    final userMatch = RegExp(r'<a href="/user/([^"]+)" class="l">([^<]+)</a>').firstMatch(timeEl?.innerHtml ?? '');
    final repliesMatch = RegExp(r'([\d,]+)\s*回复').firstMatch(timeText);
    final timeMatch = RegExp(r'·\s*([\d-]+ [\d:]+)\s*·').firstMatch(timeText);

    rows.add(BlogListRow(
      id: id,
      title: cText(titleA),
      cover: img == null ? '' : _abs(img.attributes['src'] ?? ''),
      time: timeMatch?.group(1) ?? timeText.split('·').first.trim(),
      content: contentA == null ? '' : htmlDecode(contentA.text.replaceAll(RegExp(r'\s+'), ' ').trim()),
      userId: int.tryParse(userMatch?.group(1) ?? '') ?? 0,
      username: userMatch?.group(2) ?? '',
      replies: int.tryParse((repliesMatch?.group(1) ?? '').replaceAll(',', '')) ?? 0,
    ));
  }
  return rows;
}

/// 目录列表行 (索引 /index/browser)
class CatalogRow {
  final int id;
  final String title;
  final String desc;
  final int total;
  final int userId;
  final String username;
  final String avatar;
  final String updatedAt;

  const CatalogRow({
    this.id = 0,
    this.title = '',
    this.desc = '',
    this.total = 0,
    this.userId = 0,
    this.username = '',
    this.avatar = '',
    this.updatedAt = '',
  });
}

/// 目录列表解析
///
/// 页面: https://bgm.tv/index/browser?page=..&orderby=..
/// 结构: `<li id="item_N" class="clearit tml_item index-item"> ... </li>`
List<CatalogRow> parseCatalogList(String html) {
  final doc = parser.parse(html);
  final rows = <CatalogRow>[];
  for (final li in doc.querySelectorAll('li.tml_item')) {
    final idMatch = RegExp(r'item_(\d+)').firstMatch(li.id);
    final id = int.tryParse(idMatch?.group(1) ?? '') ?? 0;
    if (id == 0) continue;

    final h3 = li.querySelector('a[href*="/index/"] h3');
    final avatarEl = li.querySelector('.avatar .avatarNeue');
    final timeTips = li.querySelectorAll('.time .tip_j');
    final desc = li.querySelector('.desc');

    var total = 0;
    for (final numEl in li.querySelectorAll('.num')) {
      total += int.tryParse(numEl.text.trim()) ?? 0;
    }

    rows.add(CatalogRow(
      id: id,
      title: h3 == null ? '' : htmlDecode(h3.text.trim()),
      desc: desc == null ? '' : htmlDecode(desc.text.trim()),
      total: total,
      username: cText(li.querySelector('.time a.l')),
      avatar: avatarEl == null ? '' : _abs(matchAvatar(avatarEl)),
      updatedAt: timeTips.length > 1 ? timeTips[1].text.trim() : '',
    ));
  }
  return rows;
}

/// 标签项
class TagItem {
  final String name;
  final int count;

  const TagItem({required this.name, this.count = 0});
}

/// 标签列表解析
///
/// 页面: https://bgm.tv/{type}/tag
/// 结构: `<div id="tagList"> <a href="/anime/tag/TV" class="l level1">TV</a><small class="grey">(1396928)</small> ...`
List<TagItem> parseTagList(String html) {
  final doc = parser.parse(html);
  final list = doc.querySelector('#tagList');
  if (list == null) return const [];

  final tags = <TagItem>[];
  for (final a in list.querySelectorAll('a.l')) {
    final name = htmlDecode(a.text.trim());
    if (name.isEmpty) continue;
    final next = a.nextElementSibling;
    final countText = next == null ? '' : cText(next).replaceAll(RegExp(r'[()]'), '');
    tags.add(TagItem(name: name, count: int.tryParse(countText.replaceAll(',', '')) ?? 0));
  }
  return tags;
}

/// 维基条目 (编辑动态)
class WikiEntry {
  final String href;
  final String name;
  final String username;
  final String time;

  const WikiEntry({this.href = '', this.name = '', this.username = '', this.time = ''});
}

/// 维基人页数据
class WikiData {
  final List<(String, int)> counts; // 全部条目/动画/书籍/.../编辑
  final List<WikiEntry> all;
  final List<WikiEntry> lock;

  const WikiData({this.counts = const [], this.all = const [], this.lock = const []});
}

/// 维基人解析
///
/// 页面: https://bgm.tv/wiki
/// 结构: `.wikiStats li` 计数; `#wiki_act-all li` / `#wiki_act-lock li` 编辑动态
WikiData parseWiki(String html) {
  final doc = parser.parse(html);

  final counts = <(String, int)>[];
  for (final li in doc.querySelectorAll('.wikiStats li')) {
    final label = li.querySelector('span');
    final num = li.querySelector('.num');
    if (label == null || num == null) continue;
    counts.add((
      htmlDecode(label.text.trim()),
      int.tryParse(num.text.trim().replaceAll(',', '')) ?? 0,
    ));
  }

  List<WikiEntry> parseList(String id) {
    final list = doc.querySelector('#$id');
    if (list == null) return const [];
    final entries = <WikiEntry>[];
    for (final li in list.querySelectorAll('li')) {
      final a = li.querySelector('a[target="_blank"].l');
      if (a == null) continue;
      final byUser = li.querySelector('small.grey a[href^="/user/"]');
      final time = li.querySelector('.rr');
      entries.add(WikiEntry(
        href: a.attributes['href'] ?? '',
        name: htmlDecode(a.text.trim()),
        username: byUser == null ? '' : htmlDecode(byUser.text.trim()),
        time: cText(time).split(' / ').first,
      ));
    }
    return entries;
  }

  return WikiData(counts: counts, all: parseList('wiki_act-all'), lock: parseList('wiki_act-lock'));
}

/// 频道条目 (注目动画)
class ChannelRankItem {
  final int id;
  final String name;
  final String cover;
  final String follow;

  const ChannelRankItem({this.id = 0, this.name = '', this.cover = '', this.follow = ''});
}

/// 频道讨论
class ChannelDiscussItem {
  final int id; // topic id
  final String title;
  final int replies;
  final String subjectName;
  final String username;
  final String time;

  const ChannelDiscussItem({
    this.id = 0,
    this.title = '',
    this.replies = 0,
    this.subjectName = '',
    this.username = '',
    this.time = '',
  });
}

/// 频道聚合页数据 (https://bgm.tv/{anime|book|real|game})
class ChannelData {
  final List<ChannelRankItem> rank;
  final List<ChannelDiscussItem> discuss;
  final List<BlogListRow> blogs;

  const ChannelData({this.rank = const [], this.discuss = const [], this.blogs = const []});
}

/// 频道聚合解析
ChannelData parseChannel(String html) {
  final doc = parser.parse(html);

  // 注目动画/图书/游戏: .featuredItems .mainItem
  final rank = <ChannelRankItem>[];
  for (final item in doc.querySelectorAll('.featuredItems .mainItem')) {
    final a = item.querySelector('> a');
    if (a == null) continue;
    final image = item.querySelector('.image');
    final grey = item.querySelector('.grey');
    rank.add(ChannelRankItem(
      id: int.tryParse((a.attributes['href'] ?? '').replaceFirst('/subject/', '')) ?? 0,
      name: htmlDecode(a.attributes['title'] ?? ''),
      cover: image == null ? '' : _abs(matchAttr(image, 'style', RegExp(r"url\(([^)]+)\)"))),
      follow: cText(grey),
    ));
  }

  // 讨论: table.topic_list tr
  final discuss = <ChannelDiscussItem>[];
  for (final row in doc.querySelectorAll('table.topic_list tr')) {
    final titleA = row.querySelector('td a.l');
    if (titleA == null) continue;
    final idMatch = RegExp(r'/subject/topic/(\d+)').firstMatch(titleA.attributes['href'] ?? '');
    final id = int.tryParse(idMatch?.group(1) ?? '') ?? 0;
    if (id == 0) continue;
    final replies = row.querySelector('td a.l + small.grey');
    final subjectA = row.querySelector('small.feed a');
    final right = row.querySelector('td[align="right"]');
    final userA = right?.querySelector('a');
    final time = right?.querySelector('small');
    discuss.add(ChannelDiscussItem(
      id: id,
      title: cText(titleA),
      replies: int.tryParse(cText(replies).replaceAll(RegExp(r'[()]'), '')) ?? 0,
      subjectName: cText(subjectA),
      username: cText(userA),
      time: cText(time),
    ));
  }

  // 日志: #entry_list .item
  final blogs = parseBlogList(html);

  return ChannelData(rank: rank, discuss: discuss, blogs: blogs);
}

/// 小组/频道讨论行 (Dollars 论坛页: /group/dollars/forum)
class TopicRow {
  final int id;
  final String title;
  final String username;
  final int replies;
  final String lastTime;

  const TopicRow({
    this.id = 0,
    this.title = '',
    this.username = '',
    this.replies = 0,
    this.lastTime = '',
  });
}

/// 讨论主题列表解析
///
/// 页面: https://bgm.tv/group/{name}/forum?page=..
/// 结构: `<tr class="topic even" data-item-user="N"> <td class="subject"><a href="/group/topic/N" ...>标题</a></td>
///   <td class="author"><a href="/user/N" class="l">用户</a></td> <td class="posts">N</td>
///   <td class="lastpost"><small class="time">...</small></td> </tr>`
List<TopicRow> parseTopicRows(String html) {
  final doc = parser.parse(html);
  final rows = <TopicRow>[];
  for (final tr in doc.querySelectorAll('tr.topic')) {
    final titleA = tr.querySelector('td.subject a.l');
    if (titleA == null) continue;
    final idMatch = RegExp(r'/group/topic/(\d+)').firstMatch(titleA.attributes['href'] ?? '');
    final id = int.tryParse(idMatch?.group(1) ?? '') ?? 0;
    if (id == 0) continue;
    final userA = tr.querySelector('td.author a.l');
    final posts = tr.querySelector('td.posts');
    final last = tr.querySelector('td.lastpost small.time');
    rows.add(TopicRow(
      id: id,
      title: cText(titleA),
      username: cText(userA),
      replies: int.tryParse(cText(posts).replaceAll(',', '')) ?? 0,
      lastTime: cText(last),
    ));
  }
  return rows;
}

/// 年鉴排行块
class AwardBlock {
  final String title;
  final String subtitle;
  final List<AwardItem> items;

  const AwardBlock({this.title = '', this.subtitle = '', this.items = const []});
}

class AwardItem {
  final String href;
  final String name;
  final String count;
  final String subName;
  final String cover;

  const AwardItem({
    this.href = '',
    this.name = '',
    this.count = '',
    this.subName = '',
    this.cover = '',
  });
}

/// 年鉴 (https://bgm.tv/award/{year}) 解析
///
/// 结构: `<div class="topicRank clearit"> <h3 class="chl"> <p data-text="年度章节">年度章节</p>
///   <span>TOP EPISODE</span> </h3> <ul> <li> <a href="/ep/N"><span class="cover"><img src="..." /></span></a>
///   <div class="inner"> <p> <a href="/ep/N">标题</a> <small>+1595</small> </p>
///   <a href="/subject/N"><small class="grey">条目名</small></a> </div> </li> ... </ul> </div>`
List<AwardBlock> parseAward(String html) {
  final doc = parser.parse(html);
  final blocks = <AwardBlock>[];
  for (final block in doc.querySelectorAll('div.topicRank')) {
    final title = block.querySelector('h3.chl p') ?? block.querySelector('h3 p');
    final subtitle = block.querySelector('h3.chl span') ?? block.querySelector('h3 span');
    if (title == null) continue;

    final items = <AwardItem>[];
    for (final li in block.querySelectorAll('ul > li')) {
      final a = li.querySelector('div.inner p a') ?? li.querySelector('a[href^="/"]');
      if (a == null) continue;
      final img = li.querySelector('img');
      final count = li.querySelector('div.inner p small');
      final sub = li.querySelector('div.inner a small.grey');
      final name = a.text.trim();
      if (name.isEmpty && count == null) continue;
      items.add(AwardItem(
        href: a.attributes['href'] ?? '',
        name: htmlDecode(name),
        count: count == null ? '' : htmlDecode(count.text.trim()),
        subName: sub == null ? '' : htmlDecode(sub.text.trim()),
        cover: img == null ? '' : _abs(img.attributes['src'] ?? ''),
      ));
    }

    blocks.add(AwardBlock(
      title: htmlDecode(title.text.trim()),
      subtitle: subtitle == null ? '' : htmlDecode(subtitle.text.trim()),
      items: items,
    ));
  }
  return blocks;
}

/// 将用户收藏 (v0) 转换为 Subject (照片墙/词云等复用)
Subject subjectFromCollectionItem(Map<String, dynamic> json) {
  final subject = json['subject'] as Map<String, dynamic>? ?? const {};
  return Subject(
    id: (json['subject_id'] as num?)?.toInt() ?? (subject['id'] as num?)?.toInt() ?? 0,
    name: subject['name'] as String? ?? '',
    nameCn: subject['name_cn'] as String? ?? '',
    images: SubjectImages(
      large: subject['images']?['large'] as String? ?? '',
      medium: subject['images']?['medium'] as String? ?? '',
      small: subject['images']?['small'] as String? ?? '',
    ),
    rank: (subject['rank'] as num?)?.toInt() ?? 0,
    rating: Rating(
      score: (subject['score'] as num?)?.toDouble() ?? 0,
      total: (subject['total'] as num?)?.toInt() ?? 0,
    ),
    tags: (subject['tags'] as List?)
            ?.map((e) => Tag.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

/// v0 用户收藏项 (系列/猜你喜欢复用)
class V0CollectionItem {
  final int subjectId;
  final int type; // 1=想看 2=看过 3=在看 4=搁置 5=抛弃
  final int epStatus;
  final String updatedAt;
  final Subject subject;

  const V0CollectionItem({
    this.subjectId = 0,
    this.type = 0,
    this.epStatus = 0,
    this.updatedAt = '',
    required this.subject,
  });

  factory V0CollectionItem.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'] as Map<String, dynamic>? ?? const {};
    return V0CollectionItem(
      subjectId: (json['subject_id'] as num?)?.toInt() ?? (subject['id'] as num?)?.toInt() ?? 0,
      type: (json['type'] as num?)?.toInt() ?? 0,
      epStatus: (json['ep_status'] as num?)?.toInt() ?? 0,
      updatedAt: json['updated_at'] as String? ?? '',
      subject: subjectFromCollectionItem(json),
    );
  }
}

/// 解析 v0 用户收藏分页响应 { total, limit, offset, data }
List<V0CollectionItem> parseV0Collections(Object? data) {
  if (data is! Map<String, dynamic>) return const [];
  final list = data['data'] as List? ?? const [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(V0CollectionItem.fromJson)
      .toList();
}
