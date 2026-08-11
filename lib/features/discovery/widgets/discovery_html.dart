/// bgm.tv 主站 HTML 解析 (regex 版, 对应原项目 cheerio 解析器)
///
/// 原项目部分屏幕 (排行榜/日志/小组/标签/维基/频道/新番/年鉴等) 通过抓取
/// bgm.tv 主站 HTML 页面获得数据 (旧版 JSON API 已下线, 返回 404), 这里用
/// 正则解析这些页面的固定结构。页面结构改动时仅需修改本文件。
library;

import '../../../shared/models/group.dart';
import '../../../shared/models/subject.dart';
import '../../../shared/models/user.dart';

/// HTML 实体解码
String htmlDecode(String input) {
  return input
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .trim();
}

String _first(String? source, RegExp re) {
  if (source == null) return '';
  final m = re.firstMatch(source);
  if (m == null) return '';
  return htmlDecode(m.group(1) ?? m.group(0) ?? '');
}

/// 浏览器 / 排行榜 / 标签条目页共用的条目列表解析
///
/// 页面: /{type}/browser?sort=..&page=.. 与 /{type}/tag/{tag}?page=..
/// 结构: `<li id="item_N" class="item odd clearit"> ... </li>`
List<Subject> parseSubjectList(String html) {
  final items = <Subject>[];
  final itemRe = RegExp(r'<li id="item_(\d+)" class="item[^"]*"[^>]*>([\s\S]*?)</li>');
  for (final m in itemRe.allMatches(html)) {
    final id = int.tryParse(m.group(1) ?? '') ?? 0;
    if (id == 0) continue;
    final block = m.group(2)!;
    final cover = _first(block, RegExp(r'<img src="(//lain\.bgm\.tv/[^"]+)"'));
    final title = _first(block, RegExp(r'<a href="/subject/\d+" class="l">([^<]+)</a>'));
    final jp = _first(block, RegExp(r'<small class="grey">([^<]+)</small>'));
    final rank = _first(block, RegExp(r'<span class="rank"><small>Rank </small>(\d+)</span>'));
    final info = _first(block, RegExp(r'<p class="info tip">([\s\S]*?)</p>'));
    final eps = _first(info, RegExp(r'(\d+)话'));
    final date = _first(info, RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日'));
    final score = _first(block, RegExp(r'<small class="fade">([\d.]+)</small>'));
    final total = _first(block, RegExp(r'\((\d+)人评分\)'));
    final type = RegExp(r'<span class="ll subject_type_(\d)').firstMatch(block)?.group(1) ?? '2';

    final subject = Subject(
      id: id,
      type: switch (type) {
        '1' => 'book',
        '4' => 'game',
        '6' => 'real',
        _ => 'anime',
      },
      name: jp.isEmpty ? title : jp,
      nameCn: title,
      images: SubjectImages(medium: cover.isEmpty ? '' : 'https:$cover'),
      eps: int.tryParse(eps) ?? 0,
      airDate: date.replaceAll('年', '-').replaceAll('月', '-').replaceAll('日', ''),
      rank: int.tryParse(rank) ?? 0,
      rating: Rating(score: double.tryParse(score) ?? 0, total: int.tryParse(total) ?? 0),
    );
    items.add(subject);
  }
  return items;
}

/// 小组列表解析
///
/// 页面: https://bgm.tv/group
/// 结构: `<li><a href="/group/name" title="..."><span class="pictureFrameGroup"><span
///   class="image"><img src="//lain...icon..."></span>...名称</a><br /><small
///   class="feed">N 位成员</small></li>`
List<Group> parseGroupList(String html) {
  final groups = <Group>[];
  final itemRe = RegExp(
    r'<a href="/group/([^"]+)" title="([^"]*)"><span class="pictureFrameGroup"><span class="image"><img src="([^"]+)"[\s\S]*?</span></span>([^<]*)</a><br\s*/?>'
    r'<small class="feed">([\d,]+) 位成员</small>',
  );
  for (final m in itemRe.allMatches(html)) {
    final name = htmlDecode(m.group(1) ?? '');
    final title = htmlDecode(m.group(2) ?? '');
    final icon = m.group(3) ?? '';
    final label = htmlDecode(m.group(4) ?? '');
    final members = int.tryParse((m.group(5) ?? '').replaceAll(',', '')) ?? 0;
    groups.add(Group(
      name: name,
      title: title.isEmpty ? label : title,
      icon: icon.isEmpty ? '' : 'https:$icon',
      members: members,
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
  final rows = <BlogListRow>[];
  final itemRe = RegExp(r'<div class="item clearit"[^>]*data-item-user="(\d+)"[^>]*>([\s\S]*?)(?=<div class="item clearit"|</div>\s*</div>\s*<hr)');
  for (final m in itemRe.allMatches(html)) {
    final block = m.group(2) ?? '';
    final id = int.tryParse(_first(block, RegExp(r'href="/blog/(\d+)"'))) ?? 0;
    if (id == 0) continue;
    final title = _first(block, RegExp(r'<h2 class="title"><a href="/blog/\d+" class="l">([^<]+)</a></h2>'));
    final cover = _first(block, RegExp(r'<img src="(//lain\.bgm\.tv/[^"]+)"'));
    final time = _first(block, RegExp(r'<div class="time">([\s\S]*?)</div>'));
    final username = _first(time, RegExp(r'<a href="/user/[^"]+" class="l">([^<]+)</a>'));
    final replies = _first(time, RegExp(r'([\d,]+) 回复'));
    final content = _first(block, RegExp(r'<div class="content">([\s\S]*?)</div>'));
    rows.add(BlogListRow(
      id: id,
      title: title,
      cover: cover.isEmpty ? '' : 'https:$cover',
      time: _first(time, RegExp(r'·\s*([\d-]+ [\d:]+)\s*·')),
      content: content.replaceAll(RegExp(r'\s+'), ' '),
      userId: int.tryParse(m.group(1) ?? '') ?? 0,
      username: username,
      replies: int.tryParse(replies.replaceAll(',', '')) ?? 0,
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
  final rows = <CatalogRow>[];
  final itemRe = RegExp(r'<li id="item_(\d+)" class="[^"]*tml_item[^"]*"[^>]*>([\s\S]*?)</li>');
  for (final m in itemRe.allMatches(html)) {
    final block = m.group(2) ?? '';
    final id = int.tryParse(m.group(1) ?? '') ?? 0;
    if (id == 0) continue;
    final title = _first(block, RegExp(r'<h3>\s*([^<]+?)\s*</h3>'));
    final username = _first(block, RegExp(r'<span class="time tip_i">[\s\S]*?<a href="/user/[^"]+" class="l">([^<]+)</a>'));
    final avatar = _first(block, RegExp(r"background-image:url\('(//lain\.bgm\.tv/[^']+)'\)"));
    final updated = _first(block, RegExp(r'更新 <span class="tip_j">([\d-]+ [\d:]+)</span>'));
    final desc = _first(block, RegExp(r'<span class="d[\s\S]*?>([\s\S]*?)</span>'));
    var total = 0;
    for (final n in RegExp(r'<span class="num">(\d+)</span>').allMatches(block)) {
      total += int.tryParse(n.group(1) ?? '') ?? 0;
    }
    rows.add(CatalogRow(
      id: id,
      title: title,
      desc: desc,
      total: total,
      username: username,
      avatar: avatar.isEmpty ? '' : 'https:$avatar',
      updatedAt: updated,
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
  final tags = <TagItem>[];
  final itemRe = RegExp(r'<a href="/[a-z]+/tag/([^"]+)" class="l[^"]*">([^<]+)</a><small class="grey">\(([\d,]+)\)</small>');
  for (final m in itemRe.allMatches(html)) {
    final name = htmlDecode(m.group(2) ?? '');
    if (name.isEmpty) continue;
    tags.add(TagItem(
      name: name,
      count: int.tryParse((m.group(3) ?? '').replaceAll(',', '')) ?? 0,
    ));
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
  final Map<String, int> counts; // 全部条目/动画/书籍/.../编辑
  final List<WikiEntry> all;
  final List<WikiEntry> lock;

  const WikiData({this.counts = const {}, this.all = const [], this.lock = const []});
}

/// 维基人解析
///
/// 页面: https://bgm.tv/wiki
/// 结构: `.wikiStats li` 计数; `#wiki_act-all li` / `#wiki_act-lock li` 编辑动态
WikiData parseWiki(String html) {
  final counts = <String, int>{};
  for (final m in RegExp(r'<li><span>([^<]+)</span><span class="num">([\d,]+)</span></li>').allMatches(html)) {
    counts[m.group(1) ?? ''] = int.tryParse((m.group(2) ?? '').replaceAll(',', '')) ?? 0;
  }

  List<WikiEntry> parseList(String id) {
    final slice = _first(html, RegExp('$id" class="sideTpcList wikiScrollBlock">([\\s\\S]*?)</ul>'));
    final list = <WikiEntry>[];
    for (final m in RegExp(r'<li class="line_[\w]+">([\s\S]*?)</li>').allMatches(slice)) {
      final block = m.group(1) ?? '';
      final href = _first(block, RegExp(r'<a href="(/[^"]+)" target="_blank" class="l">'));
      final name = _first(block, RegExp(r'class="l">([^<]+)</a>'));
      if (name.isEmpty) continue;
      final username = _first(block, RegExp(r'by <a href="/user/[^"]+">([^<]+)</a>'));
      final time = _first(block, RegExp(r'<span class="rr">([\d-]+ [\d:]+)'));
      list.add(WikiEntry(href: href, name: name, username: username, time: time));
    }
    return list;
  }

  return WikiData(
    counts: counts,
    all: parseList('wiki_act-all'),
    lock: parseList('wiki_act-lock'),
  );
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
  // 注目动画/图书/游戏: .featuredItems .mainItem
  final rank = <ChannelRankItem>[];
  final mainRe = RegExp(
    r'<div class="mainItem"> <a href="/subject/(\d+)" title="([^"]*)"> <div class="image" style="background-image:url\(([^)]+)\);[\s\S]*?</div> </a> <p class="info">[\s\S]*?<a href="/subject/\d+" class="l">([^<]+)</a>[\s\S]*?<small class="grey">([^<]+)</small>',
  );
  for (final m in mainRe.allMatches(html)) {
    rank.add(ChannelRankItem(
      id: int.tryParse(m.group(1) ?? '') ?? 0,
      name: htmlDecode(m.group(2) ?? ''),
      cover: (m.group(3) ?? '').replaceAll('(', '').replaceAll(')', ''),
      follow: htmlDecode(m.group(5) ?? ''),
    ));
  }

  // 讨论: table.topic_list tr
  final discuss = <ChannelDiscussItem>[];
  final topicRe = RegExp(r'<tr data-item-user="\d+">([\s\S]*?)</tr>');
  for (final m in topicRe.allMatches(html)) {
    final block = m.group(1) ?? '';
    final id = int.tryParse(_first(block, RegExp(r'href="/subject/topic/(\d+)"'))) ?? 0;
    if (id == 0) continue;
    final title = _first(block, RegExp(r'class="l">([^<]+)</a>'));
    final replies = _first(block, RegExp(r'class="l">([^<]+)</a> <small class="grey">\(\+(\d+)\)'));
    final subjectName = _first(block, RegExp(r'<small class="feed"><a href="/subject/\d+">([^<]+)"</a>'));
    final username = _first(block, RegExp(r'<td class="odd" align="right"><a href="/user/[^"]+">([^<]+)</a>'));
    final time = _first(block, RegExp(r'<small class="grey">([\d-]+ [\d:]+)</small>'));
    discuss.add(ChannelDiscussItem(
      id: id,
      title: title,
      replies: int.tryParse(replies) ?? 0,
      subjectName: subjectName,
      username: username,
      time: time,
    ));
  }

  // 日志: #entry_list .item
  final entryStart = html.indexOf('#entry_list');
  final blogs = entryStart >= 0 ? parseBlogList(html.substring(entryStart)) : <BlogListRow>[];

  return ChannelData(rank: rank, discuss: discuss, blogs: blogs);
}

/// 小组/频道讨论行 (通用: /group/{name}/forum 与频道 topic_list)
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
  final rows = <TopicRow>[];
  final itemRe = RegExp(r'<tr class="topic[^"]*"[^>]*>([\s\S]*?)</tr>');
  for (final m in itemRe.allMatches(html)) {
    final block = m.group(1) ?? '';
    final id = int.tryParse(_first(block, RegExp(r'href="/group/topic/(\d+)"'))) ?? 0;
    if (id == 0) continue;
    final title = _first(block, RegExp(r'<td class="subject"><a href="/group/topic/\d+" title="[^"]*" class="l">([^<]+)</a>'));
    final username = _first(block, RegExp(r'<td class="author"><a href="/user/[^"]+" class="l">([^<]+)</a>'));
    final replies = _first(block, RegExp(r'<td class="posts">([\d,]+)</td>'));
    final lastTime = _first(block, RegExp(r'<small class="time">([\d-]+ [\d:]+)</small>'));
    rows.add(TopicRow(
      id: id,
      title: title,
      username: username,
      replies: int.tryParse(replies.replaceAll(',', '')) ?? 0,
      lastTime: lastTime,
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
  final blocks = <AwardBlock>[];
  final blockRe = RegExp(r'<div class="topicRank clearit">([\s\S]*?)(?=<div class="topicRank clearit"|</div>\s*</div>\s*<div id="footer)');
  for (final m in blockRe.allMatches(html)) {
    final block = m.group(1) ?? '';
    final title = _first(block, RegExp(r'<p data-text="([^"]+)"'));
    final subtitle = _first(block, RegExp(r'<span>([^<]+)</span>'));
    if (title.isEmpty) continue;
    final items = <AwardItem>[];
    final itemRe = RegExp(r'<li>([\s\S]*?)</li>');
    for (final im in itemRe.allMatches(block)) {
      final ib = im.group(1) ?? '';
      final href = _first(ib, RegExp(r'href="(/(?:ep|subject|character|person|anime)/[^"]+)"'));
      final name = _first(ib, RegExp(r'<a href="/(?:ep|subject|character|person|anime)/[^"]+"[^>]*>([^<]+)</a>'));
      final count = _first(ib, RegExp(r'<small>([^<]+)</small>'));
      final subName = _first(ib, RegExp(r'<small class="grey">([^<]+)</small>'));
      final cover = _first(ib, RegExp(r'<img src="(//lain\.bgm\.tv/[^"]+)"'));
      if (name.isEmpty && href.isEmpty) continue;
      items.add(AwardItem(
        href: href,
        name: name,
        count: count,
        subName: subName,
        cover: cover.isEmpty ? '' : 'https:$cover',
      ));
    }
    blocks.add(AwardBlock(title: title, subtitle: subtitle, items: items));
  }
  return blocks;
}

/// 将用户收藏 (v0) 转换为 Subject (pic/wordcloud 等复用)
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
