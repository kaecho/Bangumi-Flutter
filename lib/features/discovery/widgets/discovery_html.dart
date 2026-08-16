/// bgm.tv 主站 HTML 解析 (package:html 版, 对应原项目 cheerio 解析器)
///
/// 原项目部分屏幕 (排行榜/日志/小组/标签/维基/频道/新番/年鉴等) 通过抓取
/// bgm.tv 主站 HTML 页面获得数据 (旧版 JSON API 已下线, 返回 404)。这里
/// 复用 lib/core/html/bgm_html_parser.dart 的解析基础设施。
library;

import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';

import '../../../core/html/bgm_html_parser.dart';
import '../../../core/utils/display.dart';
import '../../../shared/models/group.dart';
import '../../../shared/models/subject.dart';

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
    final collected = li.querySelector('.collectModify .thickbox') != null;

    final infoText = cText(info);
    final epsMatch = RegExp(r'(\d+)话').firstMatch(infoText);
    final dateMatch = RegExp(
      r'(\d{4})年(\d{1,2})月(\d{1,2})日',
    ).firstMatch(infoText);
    final totalText = cText(totalEl).replaceAll(RegExp(r'[()人评分]'), '');

    items.add(
      Subject(
        id: id,
        type: typeEl == null
            ? 'anime'
            : _typeName(
                typeEl.className.contains('subject_type_1')
                    ? 1
                    : (typeEl.className.contains('subject_type_4')
                          ? 4
                          : (typeEl.className.contains('subject_type_6')
                                ? 6
                                : 2)),
              ),
        name: jpEl == null ? cText(titleA) : htmlDecode(jpEl.text.trim()),
        nameCn: cText(titleA),
        images: SubjectImages(
          medium: img == null ? '' : _abs(img.attributes['src'] ?? ''),
        ),
        eps: int.tryParse(epsMatch?.group(1) ?? '') ?? 0,
        airDate: dateMatch == null
            ? ''
            : '${dateMatch.group(1)}-${dateMatch.group(2)}-${dateMatch.group(3)}',
        rank: int.tryParse(cText(rankEl).replaceAll(RegExp(r'[^\d]'), '')) ?? 0,
        rating: Rating(
          score: double.tryParse(cText(scoreEl)) ?? 0,
          total: int.tryParse(totalText) ?? 0,
        ),
        collected: collected,
      ),
    );
  }
  return items;
}

/// 排行榜 / 索引 条目列表 (单独保留 tip / collected 以匹配原项目 cheerioRank)
///
/// 与 [parseSubjectList] 同结构但额外解析 `tip` 文案与 `collected` 收藏标记,
/// 对应原项目 `cheerioRank` (`<ul id="browserItemList">` li.item)。
List<RankSubject> parseRankList(String html) {
  final doc = parser.parse(html);
  final container = doc.querySelector('#browserItemList') ?? doc;
  final items = <RankSubject>[];
  for (final li in container.querySelectorAll('li.item')) {
    final idMatch = RegExp(r'item_(\d+)').firstMatch(li.id);
    final id = int.tryParse(idMatch?.group(1) ?? '') ?? 0;
    final href = cData(li.querySelector('h3 a.l'), 'href');
    final subjectId = href.isEmpty
        ? id
        : int.tryParse(
                RegExp(r'/subject/(\d+)').firstMatch(href)?.group(1) ?? '',
              ) ??
              id;
    if (subjectId == 0) continue;

    final titleA = li.querySelector('h3 a.l');
    final jpEl = li.querySelector('h3 small.grey');
    final img = li.querySelector('img.cover');
    final cover = img == null ? '' : _abs(cData(img, 'src'));
    final rankEl = li.querySelector('.rank');
    final infoEl = li.querySelector('p.info, .info.tip');
    final scoreEl = li.querySelector('.rateInfo small.fade, .rateInfo .fade');
    final totalEl = li.querySelector('.rateInfo .tip_j');
    final collected = li.querySelector('.collectModify .thickbox') != null;

    final tip = htmlDecode(cText(infoEl));
    final totalText = cText(totalEl).replaceAll(RegExp(r'[()人评分]'), '');
    items.add(
      RankSubject(
        id: subjectId,
        name: jpEl == null ? cText(titleA) : htmlDecode(jpEl.text.trim()),
        nameCn: cText(titleA),
        cover: cover == '/img/info_only.png' ? '' : cover,
        rank: int.tryParse(cText(rankEl).replaceAll(RegExp(r'[^\d]'), '')) ?? 0,
        score: double.tryParse(cText(scoreEl)) ?? 0,
        total: int.tryParse(totalText) ?? 0,
        tip: tip,
        collected: collected,
      ),
    );
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
    groups.add(
      Group(
        name: name,
        title: htmlDecode(a.attributes['title'] ?? ''),
        icon: img == null ? '' : _abs(img.attributes['src'] ?? ''),
        members: int.tryParse(membersText) ?? 0,
      ),
    );
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
    final idMatch = RegExp(
      r'/blog/(\d+)',
    ).firstMatch(titleA.attributes['href'] ?? '');
    final id = int.tryParse(idMatch?.group(1) ?? '') ?? 0;
    if (id == 0) continue;

    final img = item.querySelector('a.avatar img');
    final contentA =
        item.querySelector('.content a') ?? item.querySelector('.content');
    final timeEl = item.querySelector('.time');
    final timeText = timeEl == null
        ? ''
        : htmlDecode(timeEl.text.replaceAll(RegExp(r'\s+'), ' ').trim());
    final userMatch = RegExp(
      r'<a href="/user/([^"]+)" class="l">([^<]+)</a>',
    ).firstMatch(timeEl?.innerHtml ?? '');
    final repliesMatch = RegExp(r'([\d,]+)\s*回复').firstMatch(timeText);
    final timeMatch = RegExp(r'·\s*([\d-]+ [\d:]+)\s*·').firstMatch(timeText);

    rows.add(
      BlogListRow(
        id: id,
        title: cText(titleA),
        cover: img == null ? '' : _abs(img.attributes['src'] ?? ''),
        time: timeMatch?.group(1) ?? timeText.split('·').first.trim(),
        content: contentA == null
            ? ''
            : htmlDecode(contentA.text.replaceAll(RegExp(r'\s+'), ' ').trim()),
        userId: int.tryParse(userMatch?.group(1) ?? '') ?? 0,
        username: userMatch?.group(2) ?? '',
        replies:
            int.tryParse((repliesMatch?.group(1) ?? '').replaceAll(',', '')) ??
            0,
      ),
    );
  }
  return rows;
}

/// 目录列表行 (索引 /index/browser, 对应原项目 cheerioCatalog)
class CatalogRow {
  final int id;
  final String title;
  final String desc;
  final int userId;
  final String username;
  final String avatar;

  /// 创建时间
  final String createdAt;

  /// 更新时间
  final String updatedAt;

  /// 各条目类型收录数 (anime/book/music/game/real)
  final int anime;
  final int book;
  final int music;
  final int game;
  final int real;

  const CatalogRow({
    this.id = 0,
    this.title = '',
    this.desc = '',
    this.userId = 0,
    this.username = '',
    this.avatar = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.anime = 0,
    this.book = 0,
    this.music = 0,
    this.game = 0,
    this.real = 0,
  });

  /// 收录条目总数
  int get total => anime + book + music + game + real;
}

/// 目录列表解析
///
/// 页面: https://bgm.tv/index/browser?page=..&orderby=..
/// 结构: `<li id="item_N" class="clearit tml_item index-item"> ... </li>`
/// 字段对应原项目 cheerioCatalog (stores/discovery/common.ts)
List<CatalogRow> parseCatalogList(String html) {
  final doc = parser.parse(html);
  final rows = <CatalogRow>[];
  for (final li in doc.querySelectorAll('li.tml_item, li.index-item')) {
    if (!li.classes.contains('tml_item')) continue;
    final idMatch = RegExp(r'item_(\d+)').firstMatch(li.id);
    final id = int.tryParse(idMatch?.group(1) ?? '') ?? 0;
    if (id == 0) continue;

    final a = li.querySelector('a.l[href*="/index/"]');

    // 用户名 / 用户 id: .time a.l (href=/user/N)
    final userLink = li.querySelector('.time a.l');
    final userHref = userLink?.attributes['href'] ?? '';
    final userId =
        int.tryParse(
          RegExp(r'/user/(\d+)').firstMatch(userHref)?.group(1) ?? '',
        ) ??
        0;

    // 创建 / 更新时间: .time .tip_j (两个)
    final tips = li.querySelectorAll('.time .tip_j');

    // 头像: .avatar .avatarNeue (style background-image)
    final avatarEl = li.querySelector('.avatar .avatarNeue');

    // 各类型计数: .subject_type_<bit> .num
    int typeNum(String bit) {
      final el = li.querySelector('.subject_type_$bit .num');
      return int.tryParse(el?.text.trim() ?? '') ?? 0;
    }

    rows.add(
      CatalogRow(
        id: id,
        title: a == null
            ? ''
            : htmlDecode(a.querySelector('h3')?.text.trim() ?? a.text.trim()),
        desc: cText(li.querySelector('.desc')),
        userId: userId,
        username: cText(userLink),
        avatar: avatarEl == null ? '' : _abs(matchAvatar(avatarEl)),
        createdAt: tips.isNotEmpty ? tips[0].text.trim() : '',
        updatedAt: tips.length > 1 ? tips[1].text.trim() : '',
        // 1=book 2=anime 3=music 4=game 6=real
        anime: typeNum('2'),
        book: typeNum('1'),
        music: typeNum('3'),
        game: typeNum('4'),
        real: typeNum('6'),
      ),
    );
  }
  return rows;
}

/// 目录详情非条目项 (角色 / 人物 / 小组 / 章节 / 日志)
class CatalogExtraItem {
  final String href;
  final String title;
  final String image;
  final String info;

  const CatalogExtraItem({
    this.href = '',
    this.title = '',
    this.image = '',
    this.info = '',
  });
}

/// 目录详情 HTML extras (原项目 cheerioCatalogDetail)
class CatalogDetailExtra {
  final String joinUrl;
  final String byeUrl;
  final String collect;
  final String progress;
  final int replyCount;
  final String userId;
  final List<Subject> subjects;
  final List<CatalogExtraItem> characters;
  final List<CatalogExtraItem> persons;
  final List<CatalogExtraItem> topics;
  final List<CatalogExtraItem> eps;
  final List<CatalogExtraItem> blogs;

  const CatalogDetailExtra({
    this.joinUrl = '',
    this.byeUrl = '',
    this.collect = '',
    this.progress = '',
    this.replyCount = 0,
    this.userId = '',
    this.subjects = const [],
    this.characters = const [],
    this.persons = const [],
    this.topics = const [],
    this.eps = const [],
    this.blogs = const [],
  });

  bool get collected => byeUrl.isNotEmpty;
}

/// 原版 typeData: 有条目才出「动画 N」
List<(String, int)> catalogTypeData(CatalogDetailExtra extra) => [
  if (extra.subjects.isNotEmpty) ('动画', extra.subjects.length),
  if (extra.characters.isNotEmpty) ('角色', extra.characters.length),
  if (extra.persons.isNotEmpty) ('人物', extra.persons.length),
  if (extra.topics.isNotEmpty) ('小组', extra.topics.length),
  if (extra.eps.isNotEmpty) ('章节', extra.eps.length),
  if (extra.blogs.isNotEmpty) ('日志', extra.blogs.length),
];

/// 原版留言: 刚好 5 条显示 5+
String catalogReplyText(int replyCount) {
  if (replyCount <= 0) return '';
  return replyCount == 5 ? '5+' : '$replyCount';
}

const kCatalogSorts = <(String, String)>[
  ('0', '默认'),
  ('1', '时间'),
  ('2', '评分'),
  ('3', '评分人数'),
];

const kCatalogCollects = <(String, String)>[
  ('all', '全部'),
  ('collected', '只看收藏'),
  ('uncollect', '不看收藏'),
];

String catalogSortLabel(String sort) =>
    kCatalogSorts.where((e) => e.$1 == sort).firstOrNull?.$2 ?? '默认';

String catalogCollectLabel(String collect) =>
    kCatalogCollects.where((e) => e.$1 == collect).firstOrNull?.$2 ?? '全部';

List<Subject> catalogFilterCollect(List<Subject> items, String collect) {
  if (collect == 'collected') {
    return [
      for (final item in items)
        if (item.collected) item,
    ];
  }
  if (collect == 'uncollect') {
    return [
      for (final item in items)
        if (!item.collected) item,
    ];
  }
  return items;
}

/// 原版 sort=1 时间 / 2 评分 / 3 评分人数
List<Subject> catalogSortSubjects(List<Subject> items, String sort) {
  final next = [...items];
  switch (sort) {
    case '1':
      next.sort((a, b) => b.airDate.compareTo(a.airDate));
    case '2':
      next.sort(
        (a, b) => (b.rating?.score ?? 0).compareTo(a.rating?.score ?? 0),
      );
    case '3':
      next.sort(
        (a, b) => (b.rating?.total ?? 0).compareTo(a.rating?.total ?? 0),
      );
  }
  return next;
}

/// 从创建目录跳转地址取 id (原项目 responseURL.match(/\d+/))
int? parseCreatedCatalogId(String location) {
  final fromPath = RegExp(r'/index/(\d+)').firstMatch(location);
  if (fromPath != null) return int.tryParse(fromPath.group(1)!);
  final digits = RegExp(r'\d+').firstMatch(location);
  return int.tryParse(digits?.group(0) ?? '');
}

CatalogExtraItem _catalogExtraItem(
  Element row, {
  required String linkSel,
  required String imgSel,
  String infoSel = 'span.tip',
}) {
  final link = row.querySelector(linkSel);
  final href = link?.attributes['href'] ?? '';
  final img =
      row.querySelector(imgSel)?.attributes['src'] ??
      _bgImage(row.querySelector('span.avatarNeue')) ??
      '';
  return CatalogExtraItem(
    href: href,
    title: htmlDecode(cText(link)),
    image: _abs(img),
    info: htmlDecode(
      cText(row.querySelector(infoSel) ?? row.querySelector('span.badge_job')),
    ),
  );
}

String? _bgImage(Element? el) {
  final style = el?.attributes['style'] ?? '';
  final m = RegExp(r'''url\(['"]?([^'")]+)''').firstMatch(style);
  return m?.group(1);
}

/// 解析 /index/{id}: 收藏、留言、类型列表 (原版 cheerioCatalogDetail)
CatalogDetailExtra parseCatalogDetailExtra(String html) {
  final fragment = htmlMatch(html, '<div id="header', '<div id="footer');
  final doc = parser.parse(fragment.isEmpty ? html : fragment);
  final box = doc.querySelector('.grp_box');
  final href =
      box?.querySelector('.btnPink')?.attributes['href'] ??
      box?.querySelector('.btnBlue')?.attributes['href'] ??
      '';
  var joinUrl = '';
  var byeUrl = '';
  if (href.contains('erase_collect')) {
    byeUrl = href;
  } else if (href.isNotEmpty) {
    joinUrl = href;
  }
  final tips = box?.querySelectorAll('.tip_j .tip') ?? const [];
  final userHref = box?.querySelector('.tip_j a.l')?.attributes['href'] ?? '';
  final userId = userHref.replaceFirst(RegExp(r'.*/user/'), '');
  final mono = [
    for (final row in doc.querySelectorAll('.browserCrtList > div'))
      _catalogExtraItem(row, linkSel: 'a.l', imgSel: 'img.avatar'),
  ];
  return CatalogDetailExtra(
    joinUrl: joinUrl,
    byeUrl: byeUrl,
    collect: tips.length > 2 ? tips[2].text.trim() : '',
    progress: htmlDecode(
      doc.querySelector('.progress small')?.text.trim() ?? '',
    ),
    replyCount: doc.querySelectorAll('.timeline_img li.clearit').length,
    userId: userId,
    subjects: parseSubjectList(html),
    characters: [
      for (final item in mono)
        if (item.href.contains('character')) item,
    ],
    persons: [
      for (final item in mono)
        if (item.href.contains('person')) item,
    ],
    topics: [
      for (final row in doc.querySelectorAll('.topic-list > .row'))
        _catalogExtraItem(
          row,
          linkSel: 'a.l',
          imgSel: 'img.avatar',
          infoSel: 'p.info',
        ),
    ],
    eps: [
      for (final row in doc.querySelectorAll('.browserList > .item'))
        _catalogExtraItem(
          row,
          linkSel: 'a.l',
          imgSel: 'img.avatar',
          infoSel: 'span.tip_j',
        ),
    ],
    blogs: [
      for (final row in doc.querySelectorAll('#entry_list > .item'))
        _catalogExtraItem(
          row,
          linkSel: 'a.l',
          imgSel: 'img.avatarCover',
          infoSel: '.time',
        ),
    ],
  );
}

/// 标签项
class TagItem {
  final String name;
  final int count;

  const TagItem({required this.name, this.count = 0});
}

/// 排行榜条目 (对应原项目 cheerioRank TagItem, 含 tip/collected)
class RankSubject {
  final int id;
  final String name;
  final String nameCn;
  final String cover;
  final int rank;
  final double score;
  final int total;
  final String tip;
  final bool collected;

  const RankSubject({
    required this.id,
    this.name = '',
    this.nameCn = '',
    this.cover = '',
    this.rank = 0,
    this.score = 0,
    this.total = 0,
    this.tip = '',
    this.collected = false,
  });

  String get displayName => cnjp(name, nameCn);
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
    final countText = next == null
        ? ''
        : cText(next).replaceAll(RegExp(r'[()]'), '');
    tags.add(
      TagItem(
        name: name,
        count: int.tryParse(countText.replaceAll(',', '')) ?? 0,
      ),
    );
  }
  return tags;
}

/// 维基条目 (编辑动态)
class WikiEntry {
  final String href;
  final String name;
  final String username;
  final String time;

  const WikiEntry({
    this.href = '',
    this.name = '',
    this.username = '',
    this.time = '',
  });
}

/// 维基人页数据
class WikiData {
  final List<(String, int)> counts;
  final Map<String, List<WikiEntry>> lists;

  const WikiData({this.counts = const [], this.lists = const {}});

  List<WikiEntry> of(String id) => lists[id] ?? const [];

  List<WikiEntry> get all => of('wiki_act-all');
  List<WikiEntry> get lock => of('wiki_act-lock');
}

/// 维基人解析
///
/// 页面: https://bgm.tv/wiki
/// 结构: `.wikiStats li` 计数; `#wiki_act-*` 编辑动态; `#latest_*` 最近入库
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
      final a =
          li.querySelector('a[target="_blank"].l') ?? li.querySelector('a.l');
      if (a == null) continue;
      final byUser = li.querySelector('small.grey a[href^="/user/"]');
      final time = li.querySelector('.rr');
      entries.add(
        WikiEntry(
          href: a.attributes['href'] ?? '',
          name: htmlDecode(a.text.trim()),
          username: byUser == null ? '' : htmlDecode(byUser.text.trim()),
          time: cText(time).split(' / ').first,
        ),
      );
    }
    return entries;
  }

  const ids = [
    'wiki_act-all',
    'wiki_act-lock',
    'wiki_act-merge',
    'wiki_act-crt',
    'wiki_act-prsn',
    'wiki_act-ep',
    'wiki_act-subject-relation',
    'wiki_act-subject-person',
    'wiki_act-subject-crt',
    'latest_all',
    'latest_1',
    'latest_2',
    'latest_3',
    'latest_4',
    'latest_6',
  ];
  return WikiData(
    counts: counts,
    lists: {for (final id in ids) id: parseList(id)},
  );
}

/// 频道条目 (注目动画)
class ChannelRankItem {
  final int id;
  final String name;
  final String cover;
  final String follow;

  const ChannelRankItem({
    this.id = 0,
    this.name = '',
    this.cover = '',
    this.follow = '',
  });
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
  final List<ChannelFriendItem> friends;

  const ChannelData({
    this.rank = const [],
    this.discuss = const [],
    this.blogs = const [],
    this.friends = const [],
  });
}

/// 频道好友最近关注 (原项目 ChannelFriendsItem)
class ChannelFriendItem {
  final int id;
  final String name;
  final String cover;
  final String userId;
  final String userName;
  final String action;
  final String avatar;

  const ChannelFriendItem({
    this.id = 0,
    this.name = '',
    this.cover = '',
    this.userId = '',
    this.userName = '',
    this.action = '',
    this.avatar = '',
  });
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
    rank.add(
      ChannelRankItem(
        id:
            int.tryParse(
              (a.attributes['href'] ?? '').replaceFirst('/subject/', ''),
            ) ??
            0,
        name: htmlDecode(a.attributes['title'] ?? ''),
        cover: image == null
            ? ''
            : _abs(matchAttr(image, 'style', RegExp(r'url\(([^)]+)\)'))),
        follow: cText(grey),
      ),
    );
  }

  // 讨论: table.topic_list tr
  final discuss = <ChannelDiscussItem>[];
  for (final row in doc.querySelectorAll('table.topic_list tr')) {
    final titleA = row.querySelector('td a.l');
    if (titleA == null) continue;
    final idMatch = RegExp(
      r'/subject/topic/(\d+)',
    ).firstMatch(titleA.attributes['href'] ?? '');
    final id = int.tryParse(idMatch?.group(1) ?? '') ?? 0;
    if (id == 0) continue;
    final replies = row.querySelector('td a.l + small.grey');
    final subjectA = row.querySelector('small.feed a');
    final right = row.querySelector('td[align="right"]');
    final userA = right?.querySelector('a');
    final time = right?.querySelector('small');
    discuss.add(
      ChannelDiscussItem(
        id: id,
        title: cText(titleA),
        replies:
            int.tryParse(cText(replies).replaceAll(RegExp(r'[()]'), '')) ?? 0,
        subjectName: cText(subjectA),
        username: cText(userA),
        time: cText(time),
      ),
    );
  }

  // 日志: #entry_list .item
  final blogs = parseBlogList(html);

  // 好友最近关注: ul.coversSmall > li
  final friends = <ChannelFriendItem>[];
  for (final li in doc.querySelectorAll('ul.coversSmall > li')) {
    final subjectA = li.querySelector('a');
    if (subjectA == null) continue;
    if (!(subjectA.attributes['href'] ?? '').contains('/subject/')) continue;
    final img = subjectA.querySelector('img');
    final cover = img?.attributes['src'] ?? '';
    if (cover.contains('/img/no_img.gif')) continue;
    final userA = li.querySelector('a.l');
    final info = cText(li.querySelector('p.info'));
    final userName = cText(userA);
    friends.add(
      ChannelFriendItem(
        id:
            int.tryParse(
              (subjectA.attributes['href'] ?? '').replaceFirst('/subject/', ''),
            ) ??
            0,
        name: htmlDecode(subjectA.attributes['title'] ?? ''),
        cover: _abs(cover),
        userId: (userA?.attributes['href'] ?? '').replaceFirst('/user/', ''),
        userName: userName,
        action: info.replaceFirst(userName, '').trim(),
        avatar: _abs(
          userA?.querySelector('img')?.attributes['src'] ??
              matchAttr(
                userA?.querySelector('.avatarNeue') ?? userA,
                'style',
                RegExp(r'url\(([^)]+)\)'),
              ),
        ),
      ),
    );
  }

  return ChannelData(
    rank: rank,
    discuss: discuss,
    blogs: blogs,
    friends: friends,
  );
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
    final idMatch = RegExp(
      r'/group/topic/(\d+)',
    ).firstMatch(titleA.attributes['href'] ?? '');
    final id = int.tryParse(idMatch?.group(1) ?? '') ?? 0;
    if (id == 0) continue;
    final userA = tr.querySelector('td.author a.l');
    final posts = tr.querySelector('td.posts');
    final last = tr.querySelector('td.lastpost small.time');
    rows.add(
      TopicRow(
        id: id,
        title: cText(titleA),
        username: cText(userA),
        replies: int.tryParse(cText(posts).replaceAll(',', '')) ?? 0,
        lastTime: cText(last),
      ),
    );
  }
  return rows;
}

/// 年鉴排行块
class AwardBlock {
  final String title;
  final String subtitle;
  final List<AwardItem> items;

  const AwardBlock({
    this.title = '',
    this.subtitle = '',
    this.items = const [],
  });
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
    final title =
        block.querySelector('h3.chl p') ?? block.querySelector('h3 p');
    final subtitle =
        block.querySelector('h3.chl span') ?? block.querySelector('h3 span');
    if (title == null) continue;

    final items = <AwardItem>[];
    for (final li in block.querySelectorAll('ul > li')) {
      final a =
          li.querySelector('div.inner p a') ?? li.querySelector('a[href^="/"]');
      if (a == null) continue;
      final img = li.querySelector('img');
      final count = li.querySelector('div.inner p small');
      final sub = li.querySelector('div.inner a small.grey');
      final name = a.text.trim();
      if (name.isEmpty && count == null) continue;
      items.add(
        AwardItem(
          href: a.attributes['href'] ?? '',
          name: htmlDecode(name),
          count: count == null ? '' : htmlDecode(count.text.trim()),
          subName: sub == null ? '' : htmlDecode(sub.text.trim()),
          cover: img == null ? '' : _abs(img.attributes['src'] ?? ''),
        ),
      );
    }

    blocks.add(
      AwardBlock(
        title: htmlDecode(title.text.trim()),
        subtitle: subtitle == null ? '' : htmlDecode(subtitle.text.trim()),
        items: items,
      ),
    );
  }
  return blocks;
}

/// 将用户收藏 (v0) 转换为 Subject (照片墙/词云等复用)
Subject subjectFromCollectionItem(Map<String, dynamic> json) {
  final subject = json['subject'] as Map<String, dynamic>? ?? const {};
  final platform = subject['platform'] as String? ?? '';
  final tags = [
    ...?(subject['tags'] as List?)?.map(
      (e) => Tag.fromJson(e as Map<String, dynamic>),
    ),
    if (platform.isNotEmpty) Tag(name: platform, count: 0),
  ];
  return Subject(
    id:
        (json['subject_id'] as num?)?.toInt() ??
        (subject['id'] as num?)?.toInt() ??
        0,
    name: subject['name'] as String? ?? '',
    nameCn: subject['name_cn'] as String? ?? '',
    airDate: subject['date'] as String? ?? subject['air_date'] as String? ?? '',
    eps: (subject['eps'] as num?)?.toInt() ?? 0,
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
    tags: tags,
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
      subjectId:
          (json['subject_id'] as num?)?.toInt() ??
          (subject['id'] as num?)?.toInt() ??
          0,
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

/// 搜索结果项 (条目 + 人物共用)
class SearchItem {
  /// 条目: /subject/{id} → int; 人物: /character/{id} 或 /person/{id} → int
  /// 用字符串存是为了保留原始 href 语义; UI 渲染条目时取 int.parse。
  /// 这里直接存为 int (条目 id / 人物 id), 对应原项目 cData($a, 'href') 提取的数字。
  final int id;
  final String type; // subject | character | person; '' 表示无法判断
  final String cover;
  final String name;
  final String nameCn;
  final String tip;
  final double score;
  final int rank;
  final String comments;

  const SearchItem({
    this.id = 0,
    this.type = '',
    this.cover = '',
    this.name = '',
    this.nameCn = '',
    this.tip = '',
    this.score = 0,
    this.rank = 0,
    this.comments = '',
  });
}

/// 搜索结果分页信息
class SearchPage {
  final List<SearchItem> list;
  final int page;
  final int pageTotal;

  const SearchPage({this.list = const [], this.page = 1, this.pageTotal = 1});
}

/// 从 href 中提取 id (如 /subject/123 → 123, /character/45 → 45)
int _idFromHref(String href) {
  final m = RegExp(r'/(\d+)').firstMatch(href);
  return int.tryParse(m?.group(1) ?? '') ?? 0;
}

/// 条目类型 class → 类型名 (如 span.ll class='subject_type_2' → anime)
/// 对应原项目 cheerioSearch type 字段 (matched 数字, 在 UI 端再做映射)
String _subjectTypeFromSpan(Element? el) {
  final cls = cData(el, 'class');
  final m = RegExp(r'subject_type_(\d+)').firstMatch(cls);
  final n = int.tryParse(m?.group(1) ?? '');
  return switch (n) {
    1 => 'book',
    2 => 'anime',
    3 => 'music',
    4 => 'game',
    6 => 'real',
    _ => '',
  };
}

/// 条目搜索结果解析 (对应原项目 cheerioSearch)
///
/// 页面: /{subject|catalog|user}_search/... {@code #searchResultList} 不存在,
/// 实际结构来自原项目 selectors: `#browserItemList .item` 的统一条目列表。
/// 原项目 cheerio 使用 `#searchResultList li.item`, 实为裁剪后 DOM;
/// 这里按真实主站 DOM (#browserItemList li.item) 解析, 与 parseSubjectList 同源,
/// 但同时提取 score (rateInfo .fade) / rank / tip (p.info) 与 type。
SearchPage parseSearchSubject(String html) {
  final fragment = htmlMatch(html, '<div id="columnSearchB', '<div id="footer');
  final doc = parseDom(removeCF(fragment.isEmpty ? html : fragment));

  // bgm.tv 搜索页条目列表容器为 #browserItemList (与浏览器页一致)
  final container = doc.querySelector('#browserItemList') ?? doc;
  final items = <SearchItem>[];
  for (final li in container.querySelectorAll('li.item')) {
    final a = li.querySelector('h3 a.l');
    if (a == null) continue;
    final id = _idFromHref(cData(a, 'href'));
    if (id == 0) continue;
    final grey = li.querySelector('h3 small.grey');
    final coverEl = li.querySelector('img.cover');
    final info = li.querySelector('p.info');
    final rateInfo = li.querySelector('.rateInfo');
    final scoreEl = rateInfo?.querySelector('.fade');
    final totalEl = rateInfo?.querySelector('.tip_j');
    final rankEl = li.querySelector('.rank');
    final typeSpan = li.querySelector('h3 span.ll');

    final scoreStr = cText(scoreEl);
    final totalText = cText(totalEl).replaceAll(RegExp(r'[()人评分]'), '');
    items.add(
      SearchItem(
        id: id,
        type: 'subject:${_subjectTypeFromSpan(typeSpan)}',
        cover: _abs(cData(coverEl, 'src')),
        name: grey == null ? cText(a) : htmlDecode(grey.text.trim()),
        nameCn: cText(a),
        tip: cText(info),
        score: double.tryParse(scoreStr) ?? 0,
        rank: int.tryParse(cText(rankEl).replaceAll(RegExp(r'[^\d]'), '')) ?? 0,
        comments: totalText,
      ),
    );
  }

  final page = _searchPagination(doc);
  return SearchPage(list: items, page: page.page, pageTotal: page.pageTotal);
}

/// 人物搜索结果解析 (对应原项目 cheerioSearchMono)
///
/// 页面: /mono_search/...; 原项目 selector 为 `.light_odd`
/// 行结构: h2 a.l (href+名/中名), img.avatar (封面), .prsn_info (tip),
/// small.na (comments)
SearchPage parseSearchMono(String html) {
  final fragment = htmlMatch(html, '<div id="columnSearchB', '<div id="footer');
  final doc = parseDom(removeCF(fragment.isEmpty ? html : fragment));

  final items = <SearchItem>[];
  for (final row in doc.querySelectorAll('.light_odd')) {
    final a = row.querySelector('h2 a.l');
    if (a == null) continue;
    final href = cData(a, 'href');
    final id = _idFromHref(href);
    if (id == 0) continue;

    // 名/中名按 '/' 分割 (对应原项目: split('/') name=parts[0] nameCn=parts[1:])
    final fullText = cText(a);
    final slash = fullText.indexOf('/');
    final name = slash < 0
        ? fullText.trim()
        : fullText.substring(0, slash).trim();
    final nameCn = slash < 0 ? '' : fullText.substring(slash + 1).trim();

    final avatar = row.querySelector('img.avatar');
    final prsnInfo = row.querySelector('.prsn_info');
    final na = row.querySelector('small.na');

    items.add(
      SearchItem(
        id: id,
        type: href.contains('/character/') ? 'character' : 'person',
        cover: _abs(cData(avatar, 'src')),
        name: name,
        nameCn: nameCn,
        tip: cText(prsnInfo),
        score: 0,
        rank: 0,
        comments: cText(na),
      ),
    );
  }

  final page = _searchPagination(doc);
  return SearchPage(list: items, page: page.page, pageTotal: page.pageTotal);
}

/// 搜索页分页解析 (bgm.tv 搜索页 #multipage)
({int page, int pageTotal}) _searchPagination(Document doc) {
  final multipage = doc.querySelector('#multipage');
  if (multipage == null) return (page: 1, pageTotal: 1);
  // 优先取 .p_edge (1 / N) 形式
  final edge = multipage.querySelector('.p_edge');
  if (edge != null) {
    final m = RegExp(r'/\s*(\d+)').firstMatch(cText(edge));
    if (m != null) {
      return (page: 1, pageTotal: int.tryParse(m.group(1)!) ?? 1);
    }
  }
  // 否则取所有分页数字最大值
  int maxPage = 1;
  int cur = 1;
  for (final el in multipage.querySelectorAll('.p, .p_cur')) {
    final n = int.tryParse(cText(el));
    if (n != null) {
      if (n > maxPage) maxPage = n;
      if (el.classes.contains('p_cur')) cur = n;
    }
  }
  return (page: cur, pageTotal: maxPage);
}

/// 收藏人物的最近作品 (原项目 RecentsItem / cheerioRecents)
class MonoRecentItem {
  final int id;
  final String cover;
  final int type;
  final String href;
  final String name;
  final String nameJp;
  final String info;
  final int star;
  final String starInfo;
  final List<(String id, String avatar, String name, String info)> actors;

  const MonoRecentItem({
    this.id = 0,
    this.cover = '',
    this.type = 0,
    this.href = '',
    this.name = '',
    this.nameJp = '',
    this.info = '',
    this.star = 0,
    this.starInfo = '',
    this.actors = const [],
  });
}

/// 解析 /mono/update: #browserItemList li.item
List<MonoRecentItem> parseMonoRecents(String html) {
  final fragment = htmlMatch(
    html,
    '<div id="columnCrtBrowserB',
    '<div id="footer',
  );
  final doc = parser.parse(fragment.isEmpty ? html : fragment);
  final list = doc.querySelector('#browserItemList');
  if (list == null) return const [];

  final items = <MonoRecentItem>[];
  for (final row in list.querySelectorAll('li.item')) {
    final a = row.querySelector('h3 a.l');
    if (a == null) continue;
    final href = a.attributes['href'] ?? '';
    final idMatch = RegExp(r'/subject/(\d+)').firstMatch(href);
    final idFromLi = (row.attributes['id'] ?? '').replaceFirst('item_', '');
    final typeClass =
        row.querySelector('h3 span.ll')?.attributes['class'] ?? '';
    final type =
        int.tryParse(
          RegExp(r'subject_type_(\d+)').firstMatch(typeClass)?.group(1) ?? '',
        ) ??
        0;
    final starClass =
        row.querySelector('span.starlight')?.attributes['class'] ?? '';
    final star =
        int.tryParse(
          RegExp(r'stars(\d+)').firstMatch(starClass)?.group(1) ?? '',
        ) ??
        0;
    final actors = <(String, String, String, String)>[];
    for (final badge in row.querySelectorAll('.actorBadge')) {
      final ba = badge.querySelector('a.l');
      final img = badge.querySelector('img');
      final avatarA = badge.querySelector('a.avatar');
      actors.add((
        (avatarA?.attributes['href'] ?? ba?.attributes['href'] ?? '')
            .replaceFirst(RegExp(r'^/+'), ''),
        _abs(img?.attributes['src'] ?? ''),
        ba == null ? '' : htmlDecode(ba.text.trim()),
        htmlDecode(badge.querySelector('small.grey')?.text.trim() ?? ''),
      ));
    }
    items.add(
      MonoRecentItem(
        id:
            int.tryParse(idMatch?.group(1) ?? '') ??
            int.tryParse(idFromLi) ??
            0,
        cover: _abs(row.querySelector('img.cover')?.attributes['src'] ?? ''),
        type: type,
        href: href,
        name: htmlDecode(a.text.trim()),
        nameJp: htmlDecode(
          row.querySelector('h3 small.grey')?.text.trim() ?? '',
        ),
        info: htmlDecode(row.querySelector('p.info')?.text.trim() ?? ''),
        star: star,
        starInfo: htmlDecode(
          row.querySelector('.rateInfo .tip_j')?.text.trim() ?? '',
        ),
        actors: actors,
      ),
    );
  }
  return items;
}

/// Dollars 聊天条 (原项目 DollarsItem / cheerioDollars)
class DollarsChatItem {
  final String id;
  final String avatar;
  final String nickname;
  final String msg;
  final String color;

  const DollarsChatItem({
    this.id = '',
    this.avatar = '',
    this.nickname = '',
    this.msg = '',
    this.color = '',
  });

  factory DollarsChatItem.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar'] as String? ?? '';
    return DollarsChatItem(
      id: '${json['id'] ?? ''}',
      avatar: avatar.startsWith('http')
          ? avatar
          : avatar.isEmpty
          ? ''
          : 'https://lain.bgm.tv/pic/user/m/$avatar',
      nickname: json['nickname'] as String? ?? json['name'] as String? ?? '',
      msg: json['msg'] as String? ?? json['message'] as String? ?? '',
      color: json['color'] as String? ?? '',
    );
  }
}

/// 解析 /dollars: #chatList ul li
({List<DollarsChatItem> list, String online}) parseDollars(String html) {
  final doc = parser.parse(html);
  final items = <DollarsChatItem>[];
  for (final row in doc.querySelectorAll('#chatList ul li')) {
    final rawId = (row.attributes['id'] ?? '').split('_');
    final id = rawId.length > 1
        ? rawId[1].substring(0, rawId[1].length.clamp(0, 10))
        : '';
    final src = row.querySelector('img.avatar')?.attributes['src'] ?? '';
    var avatar = src;
    final mid = src.split('/m/');
    if (mid.length > 1) {
      avatar = 'https://lain.bgm.tv/pic/user/m/${mid.last}';
    } else if (src.startsWith('//')) {
      avatar = 'https:$src';
    }
    final style = row.querySelector('.content')?.attributes['style'] ?? '';
    final color = style.contains(':') ? style.split(':').last.trim() : '';
    items.add(
      DollarsChatItem(
        id: id,
        avatar: avatar,
        nickname: htmlDecode(row.querySelector('.icon p')?.text.trim() ?? ''),
        msg: htmlDecode(row.querySelector('.content p')?.text.trim() ?? ''),
        color: color,
      ),
    );
  }
  final onlineRaw = doc.querySelector('#toolBox')?.text ?? '';
  final online = onlineRaw.contains(':')
      ? onlineRaw.split(':').last.trim()
      : onlineRaw.trim();
  return (list: items, online: online);
}
