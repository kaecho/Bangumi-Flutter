/// 用户域模型 + 主站 HTML 解析 (移植自原项目 stores/users + screens/user)
///
/// 旧版 JSON API 与主站 HTML 页面 (blog/friends/catalogs/timeline/pm) 混用:
/// - API: /user/{uid}, /user/{uid}/collections/status, /v0/users/{uid}/collections
/// - HTML: 日志/好友/目录/时光机/短信 (bgm.tv 主站, 调用时传 host: kHost)
library;

import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;

import '../../core/html/bgm_html_parser.dart';
import '../../shared/models/collection.dart';
import '../../shared/models/subject.dart';
import '../../shared/models/timeline.dart';
import '../../shared/models/user.dart';

/// 用户标识: username 优先, 否则数字 id
String userPathId(User user) =>
    user.username.isEmpty ? '${user.id}' : user.username;

/// v0 subject_type 数字映射 (1=book 2=anime 3=music 4=game 6=real)
int v0SubjectTypeInt(String type) => switch (type) {
  'book' => 1,
  'anime' => 2,
  'music' => 3,
  'game' => 4,
  'real' => 6,
  _ => 2,
};

/// 用户空间收藏类型 Tab (含音乐, 与原项目一致)
const kUserTypeTabs = [
  ('anime', '动画'),
  ('book', '书籍'),
  ('music', '音乐'),
  ('game', '游戏'),
  ('real', '三次元'),
];

/// 收藏状态 Tab: (状态值, 文案)
const kCollectionStatusTabs = [
  (0, '全部'),
  (CollectionStatus.wish, '想看'),
  (CollectionStatus.collect, '看过'),
  (CollectionStatus.doing, '在看'),
  (CollectionStatus.onHold, '搁置'),
  (CollectionStatus.dropped, '抛弃'),
];

class ZoneCollectionCover {
  final int id;
  final String name;
  final String nameCn;
  final String cover;

  const ZoneCollectionCover({
    this.id = 0,
    this.name = '',
    this.nameCn = '',
    this.cover = '',
  });

  String get displayName => nameCn.isNotEmpty ? nameCn : name;
}

class ZoneCollectionSection {
  final int status;
  final String title;
  final int count;
  final List<ZoneCollectionCover> items;

  const ZoneCollectionSection({
    this.status = 0,
    this.title = '',
    this.count = 0,
    this.items = const [],
  });
}

int zoneCollectionStatusId(String name) {
  final n = name.trim();
  if (n.contains('想')) return CollectionStatus.wish;
  if (n.contains('过')) return CollectionStatus.collect;
  if (n.contains('在')) return CollectionStatus.doing;
  if (n == '搁置') return CollectionStatus.onHold;
  if (n == '抛弃') return CollectionStatus.dropped;
  return 0;
}

List<int> zoneExpandOrder() => const [
  CollectionStatus.doing,
  CollectionStatus.collect,
  CollectionStatus.wish,
  CollectionStatus.onHold,
  CollectionStatus.dropped,
];

List<ZoneCollectionSection> parseZoneCollectionsOverview(Object? json) {
  Object? source = json;
  if (json is List && json.isNotEmpty && json.first is Map) {
    final first = Map<String, dynamic>.from(json.first as Map);
    if (first['collects'] is List) source = first['collects'];
  } else if (json is Map && json['collects'] is List) {
    source = json['collects'];
  }
  if (source is! List) return const [];
  final sections = <ZoneCollectionSection>[];
  for (final raw in source) {
    if (raw is! Map) continue;
    final entry = Map<String, dynamic>.from(raw);
    final title = entry['status'] is Map
        ? (entry['status'] as Map)['name']?.toString() ?? ''
        : entry['status']?.toString() ?? '';
    final status = zoneCollectionStatusId(title);
    if (status == 0) continue;
    final items = <ZoneCollectionCover>[];
    final list = entry['list'] as List? ?? const [];
    for (final row in list) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final subjectRaw = map['subject'] is Map
          ? Map<String, dynamic>.from(map['subject'] as Map)
          : map;
      final images = subjectRaw['images'] is Map
          ? Map<String, dynamic>.from(subjectRaw['images'] as Map)
          : const <String, dynamic>{};
      final id = (subjectRaw['id'] as num?)?.toInt() ?? 0;
      if (id == 0) continue;
      items.add(
        ZoneCollectionCover(
          id: id,
          name: subjectRaw['name'] as String? ?? '',
          nameCn: subjectRaw['name_cn'] as String? ?? '',
          cover: absUrl(
            images['medium'] as String? ?? images['common'] as String? ?? '',
          ),
        ),
      );
    }
    sections.add(
      ZoneCollectionSection(
        status: status,
        title: title,
        count: (entry['count'] as num?)?.toInt() ?? items.length,
        items: items,
      ),
    );
  }
  sections.sort(
    (a, b) =>
        zoneExpandOrder().indexOf(a.status) -
        zoneExpandOrder().indexOf(b.status),
  );
  return sections;
}

List<String> zoneCollectionMoreItems({
  required bool collapse,
  required bool alignCenter,
}) => ['自动折叠〔${collapse ? '开' : '关'}〕', '标题居中〔${alignCenter ? '开' : '关'}〕'];

/// 绝对化图片地址 (//lain.bgm.tv/... → https://lain.bgm.tv/...)
String absUrl(String url) {
  if (url.isEmpty) return '';
  if (url.startsWith('//')) return 'https:$url';
  return url;
}

/// 从 style="background-image:url('...')" 提取图片地址
String bgImageUrl(String style) {
  final match = RegExp(r'''url\(['"]?([^'")]+)['"]?\)''').firstMatch(style);
  return absUrl(match?.group(1) ?? '');
}

/// 日志
class UserBlog {
  final String id;
  final String title;
  final String cover;
  final String content;
  final String time;
  final String replies;
  final List<String> tags;

  const UserBlog({
    this.id = '',
    this.title = '',
    this.cover = '',
    this.content = '',
    this.time = '',
    this.replies = '',
    this.tags = const [],
  });
}

/// 目录
class UserCatalog {
  final String id;
  final String title;
  final String desc;
  final String created;
  final String updated;
  final Map<String, int> counts; // type → 条目数

  const UserCatalog({
    this.id = '',
    this.title = '',
    this.desc = '',
    this.created = '',
    this.updated = '',
    this.counts = const {},
  });

  int get total => counts.values.fold<int>(0, (a, b) => a + b);
}

/// 好友
class Friend {
  final String userId;
  final String userName;
  final String avatar;

  const Friend({this.userId = '', this.userName = '', this.avatar = ''});
}

/// 收藏的人物 (虚构角色 / 现实人物)
class UserMono {
  final String id; // character/123 | person/456
  final String name;
  final String avatar;

  const UserMono({this.id = '', this.name = '', this.avatar = ''});
}

/// 短信列表项 (收件箱)
class PmItem {
  final String id; // conversation id
  final String title;
  final String content;
  final String avatar;
  final String name;
  final String userId;
  final String time;
  final bool isNew;

  const PmItem({
    this.id = '',
    this.title = '',
    this.content = '',
    this.avatar = '',
    this.name = '',
    this.userId = '',
    this.time = '',
    this.isNew = false,
  });
}

/// 原版 userStore.hasNewPM: 收件箱任一条 isNew
bool hasNewPm(Iterable<PmItem> items) => items.any((item) => item.isNew);

/// 短信详情消息 (type: label=线程分隔 / message=消息)
class PmMessage {
  final String type;
  final String threadTitle;
  final String threadId;
  final String name;
  final String avatar;
  final String userId;
  final String content;
  final String time;

  const PmMessage({
    this.type = 'message',
    this.threadTitle = '',
    this.threadId = '',
    this.name = '',
    this.avatar = '',
    this.userId = '',
    this.content = '',
    this.time = '',
  });
}

/// 发送短信所需表单参数 (从页面提取)
class PmForm {
  final String related;
  final String msgReceivers;
  final String currentMsgId;
  final String formhash;
  final String msgTitle;
  final String peerUserId;
  final String peerUserName;
  final List<(String id, String title)> threads;

  const PmForm({
    this.related = '',
    this.msgReceivers = '',
    this.currentMsgId = '',
    this.formhash = '',
    this.msgTitle = '',
    this.peerUserId = '',
    this.peerUserName = '',
    this.threads = const [],
  });
}

/// 时光机分组: 按日期分组的用户时间线
class UserTimelineGroup {
  final String date;
  final List<TimelineItem> items;

  const UserTimelineGroup({required this.date, this.items = const []});
}

/// 解析用户时光机 (bgm.tv/user/{uid}/timeline?ajax=1)
/// 页面结构: <h4 class="Header">日期</h4> + <li id="tml_..." class="tml_item">
List<UserTimelineGroup> parseUserTimeline(String html) {
  var fragment = htmlMatch(html, '<div id="timeline', '<div id="pm_pager');
  if (fragment.isEmpty) {
    fragment = htmlMatch(html, '<div id="timeline', '<div id="tmlPager');
  }

  final doc = parser.parse(fragment.isEmpty ? html : fragment);
  final groups = <UserTimelineGroup>[];
  final container = doc.querySelector('#timeline');
  if (container == null) return groups;

  // 按文档顺序遍历日期头与条目 (条目嵌套在 ul 内)
  String currentDate = '';
  final current = <TimelineItem>[];
  for (final el in container.querySelectorAll('h4.Header, li.tml_item')) {
    if (el.localName == 'h4') {
      if (currentDate.isNotEmpty && current.isNotEmpty) {
        groups.add(
          UserTimelineGroup(date: currentDate, items: List.of(current)),
        );
        current.clear();
      }
      currentDate = el.text.trim();
      continue;
    }
    final item = _timelineItemFromElement(el);
    if (item.id > 0 || item.content.isNotEmpty) current.add(item);
  }
  if (currentDate.isNotEmpty && current.isNotEmpty) {
    groups.add(UserTimelineGroup(date: currentDate, items: List.of(current)));
  }
  return groups;
}

TimelineItem _timelineItemFromElement(Element li) {
  final idMatch = RegExp(r'tml_(\d+)').firstMatch(li.id);
  final info = li.querySelector('.info_full');

  // 动作文本: 链接替换为中文名后去标签
  var text = '';
  if (info != null) {
    var raw = info.outerHtml;
    final beforeCard = raw.split('<div class="card').first;
    text = htmlDecode(
      beforeCard
          .replaceAllMapped(
            RegExp(r'<a [^>]*data-subject-name-cn="([^"]*)"[^>]*>.*?</a>'),
            (m) => m.group(1)!.isEmpty ? '' : m.group(1)!,
          )
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
    );
  }

  // 条目信息
  var subjectId = 0;
  var cnName = '';
  var jpName = '';
  final link = li.querySelector('a[data-subject-id]');
  if (link != null) {
    subjectId = int.tryParse(link.attributes['data-subject-id'] ?? '') ?? 0;
    cnName = htmlDecode(link.attributes['data-subject-name-cn'] ?? '');
    jpName = htmlDecode(link.attributes['data-subject-name'] ?? '');
  }
  var cover = '';
  final img =
      li.querySelector('img[src*="pic/cover"]') ?? li.querySelector('img');
  if (img != null) cover = absUrl(img.attributes['src'] ?? '');

  // 评分
  var score = 0.0;
  final rate = li.querySelector('.rateInfo small.fade');
  if (rate != null) score = double.tryParse(rate.text.trim()) ?? 0;

  // 时间
  var createdAt = '';
  final tip = li.querySelector('.post_actions span[title]');
  if (tip != null) createdAt = tip.attributes['title'] ?? '';

  final clear = li.querySelector('a.tml_del')?.attributes['href'] ?? '';
  final likeType =
      int.tryParse(
        li.querySelector('a.like_dropdown')?.attributes['data-like-type'] ?? '',
      ) ??
      40;
  final relatedId =
      int.tryParse(
        (li.querySelector('.likes_grid')?.id ?? '').replaceFirst(
          'likes_grid_',
          '',
        ),
      ) ??
      0;
  return TimelineItem(
    id: int.tryParse(idMatch?.group(1) ?? '') ?? 0,
    createdAt: createdAt,
    content: text,
    clearHref: clear,
    likeType: likeType,
    relatedId: relatedId,
    subject: subjectId > 0
        ? Subject(
            id: subjectId,
            name: jpName,
            nameCn: cnName,
            images: SubjectImages(common: cover),
            rating: score > 0 ? Rating(score: score) : null,
          )
        : null,
    user: _timelineUserFromElement(li),
  );
}

User? _timelineUserFromElement(Element li) {
  final link =
      li.querySelector('a.l[href*="/user/"]') ??
      li.querySelector('a[href*="/user/"]');
  if (link == null) return null;
  final href = link.attributes['href'] ?? '';
  final name = htmlDecode(link.text.trim());
  if (name.isEmpty) return null;
  final idMatch = RegExp(r'/user/([^/?#]+)').firstMatch(href);
  final rawId = idMatch?.group(1) ?? '';
  if (rawId.isEmpty) return null;
  final avatarEl = li.querySelector('span.avatarNeue');
  final style = avatarEl?.attributes['style'] ?? '';
  final avatarMatch = RegExp(r"url\('?([^')]+)'?\)").firstMatch(style);
  var avatar = avatarMatch?.group(1) ?? '';
  if (avatar.startsWith('//')) avatar = 'https:$avatar';
  return User(
    id: int.tryParse(rawId) ?? 0,
    username: rawId,
    nickname: name,
    avatar: UserAvatar(large: avatar, medium: avatar, small: avatar),
  );
}

/// 解析用户日志列表 (bgm.tv/user/{uid}/blog)
/// 结构: #entry_list .item (可选 .cover > a.avatar img) + .entry
List<UserBlog> parseUserBlogs(String html) {
  final fragment = htmlMatch(html, '<div id="entry_list', '<div id="columnB"');
  final doc = parser.parse(fragment.isEmpty ? html : fragment);
  final list = doc.querySelector('#entry_list');
  if (list == null) return const [];

  final blogs = <UserBlog>[];
  for (final item in list.querySelectorAll('.item')) {
    final titleA = item.querySelector('h2.title a');
    if (titleA == null) continue;
    final idMatch = RegExp(
      r'/blog/(\d+)',
    ).firstMatch(titleA.attributes['href'] ?? '');
    final cover = item.querySelector('a.avatar img');
    final contentA = item.querySelector('.content a');
    final timeEl = item.querySelector('.time');
    final timeText = timeEl == null
        ? ''
        : htmlDecode(timeEl.text.replaceAll(RegExp(r'\s+'), ' ').trim());
    final replies = RegExp(r'(\d+)\s*回复').firstMatch(timeText)?.group(1) ?? '';
    final time = timeText.split('·').first.trim();

    blogs.add(
      UserBlog(
        id: idMatch?.group(1) ?? '',
        title: htmlDecode(titleA.text.trim()),
        cover: cover == null ? '' : absUrl(cover.attributes['src'] ?? ''),
        content: contentA == null
            ? ''
            : htmlDecode(contentA.text.replaceAll(RegExp(r'\s+'), ' ').trim()),
        time: time,
        replies: replies,
        tags: [
          for (final tag in item.querySelectorAll('.tags .badge_tag'))
            htmlDecode(tag.text.trim()),
        ],
      ),
    );
  }
  return blogs;
}

/// 解析用户目录列表 (bgm.tv/user/{uid}/index)
/// 结构: #timeline li.index-item
List<UserCatalog> parseUserCatalogs(String html) {
  final fragment = htmlMatch(html, '<div id="timeline', '<div id="footer');
  final doc = parser.parse(fragment.isEmpty ? html : fragment);
  final timeline = doc.querySelector('#timeline');
  if (timeline == null) return const [];

  final catalogs = <UserCatalog>[];
  for (final item in timeline.querySelectorAll('li.index-item')) {
    final titleA = item.querySelector('a[href*="/index/"] h3');
    final link = item.querySelector('a[href*="/index/"]');
    if (link == null) continue;
    final idMatch = RegExp(
      r'/index/(\d+)',
    ).firstMatch(link.attributes['href'] ?? '');

    final counts = <String, int>{};
    for (final type in ['1', '2', '3', '4', '6']) {
      final numEl = item.querySelector('.subject_type_$type .num');
      if (numEl != null) counts[type] = int.tryParse(numEl.text.trim()) ?? 0;
    }

    final tips = item.querySelectorAll('.time .tip_j');
    final desc = item.querySelector('.desc');

    catalogs.add(
      UserCatalog(
        id: idMatch?.group(1) ?? '',
        title: titleA == null ? '' : htmlDecode(titleA.text.trim()),
        desc: desc == null ? '' : htmlDecode(desc.text.trim()),
        created: tips.isNotEmpty ? tips.first.text.trim() : '',
        updated: tips.length > 1 ? tips[1].text.trim() : '',
        counts: counts,
      ),
    );
  }
  return catalogs;
}

/// 解析好友列表 (bgm.tv/user/{uid}/friends)
/// 结构: #memberUserList li.user > .userContainer > strong > a.avatar
List<Friend> parseUserFriends(String html) {
  final fragment = htmlMatch(
    html,
    '<div id="columnUserSingle',
    '<div id="footer',
  );
  final doc = parser.parse(fragment.isEmpty ? html : fragment);
  final list = doc.querySelector('#memberUserList');
  if (list == null) return const [];

  final friends = <Friend>[];
  for (final item in list.querySelectorAll('li.user')) {
    final a = item.querySelector('a.avatar');
    if (a == null) continue;
    final idMatch = RegExp(
      r'/user/([^/]+)',
    ).firstMatch(a.attributes['href'] ?? '');
    final avatarEl = item.querySelector('.avatarNeue');
    friends.add(
      Friend(
        userId: idMatch?.group(1) ?? '',
        userName: htmlDecode(a.text.trim()),
        avatar: avatarEl == null
            ? ''
            : bgImageUrl(avatarEl.attributes['style'] ?? ''),
      ),
    );
  }
  return friends;
}

/// 解析收藏的人物 (bgm.tv/user/{uid}/mono/{character|person})
/// 结构: .coverList li > a[href] + img.avatarCover + a.title
List<UserMono> parseUserMono(String html) {
  final fragment = htmlMatch(html, '<div id="columnA', '<div id="footer');
  final doc = parser.parse(fragment.isEmpty ? html : fragment);
  final list = doc.querySelector('.coverList');
  if (list == null) return const [];

  final monos = <UserMono>[];
  for (final item in list.querySelectorAll('li')) {
    final a = item.querySelector('a.title');
    if (a == null) continue;
    final img = item.querySelector('img');
    monos.add(
      UserMono(
        id: (a.attributes['href'] ?? '').replaceFirst(RegExp(r'^/'), ''),
        name: htmlDecode(a.text.trim()),
        avatar: img == null ? '' : absUrl(img.attributes['src'] ?? ''),
      ),
    );
  }
  return monos;
}

/// 解析收件箱 (bgm.tv/pm/inbox.chii)
/// 结构: a.pm-conversation-item (href=/pm/conversation/ID.chii)
List<PmItem> parsePmInbox(String html) {
  final doc = parser.parse(html);
  final items = <PmItem>[];
  for (final a in doc.querySelectorAll('a.pm-conversation-item')) {
    final idMatch = RegExp(
      r'/conversation/(\d+)',
    ).firstMatch(a.attributes['href'] ?? '');
    if (idMatch == null) continue;

    final avatarEl = a.querySelector('.avatarNeue');
    final name = a.querySelector('.pm-conversation-name');
    final date = a.querySelector('.pm-conversation-date');
    final desc = a.querySelector('.pm-conversation-desc');
    final rawDesc = desc == null
        ? ''
        : htmlDecode(desc.text.replaceAll(RegExp(r'\s+'), ' ').trim());

    final hasRe = rawDesc.startsWith('Re:');
    var cleanDesc = hasRe ? rawDesc.substring(3).trim() : rawDesc;
    var title = cleanDesc;
    var content = cleanDesc;
    if (cleanDesc.contains(' / ')) {
      final parts = cleanDesc.split(' / ');
      title = parts.first.trim();
      content = parts.sublist(1).join(' / ').trim();
    }
    if (hasRe) content = 'Re: $content';

    final avatar = avatarEl == null
        ? ''
        : bgImageUrl(avatarEl.attributes['style'] ?? '');
    final userIdMatch = RegExp(r'/(\d+)\.jpg').firstMatch(avatar);

    items.add(
      PmItem(
        id: idMatch.group(1)!,
        title: title,
        content: content,
        avatar: avatar,
        name: name == null ? '' : htmlDecode(name.text.trim()),
        time: date == null ? '' : date.text.trim(),
        userId: userIdMatch?.group(1) ?? '0',
        isNew:
            a.className.contains('pm_new') ||
            a.querySelector('.pm-conversation-unread') != null,
      ),
    );
  }
  return items;
}

/// 解析短信详情 (bgm.tv/pm/conversation/ID.chii)
/// 结构: .pm-message-list 下 .pm-thread-label / .pm-message
({List<PmMessage> list, PmForm form}) parsePmChat(String html) {
  final doc = parser.parse(html);

  // 线程过滤
  final threadMap = <String, String>{};
  for (final a in doc.querySelectorAll('.pm-thread-filter a')) {
    final id =
        RegExp(
          r'thread=(\d+)',
        ).firstMatch(a.attributes['href'] ?? '')?.group(1) ??
        '';
    final title = a.text.trim();
    if (id.isNotEmpty && title.isNotEmpty) threadMap[title] = id;
  }

  var currentThreadId = '';
  final list = <PmMessage>[];
  final container = doc.querySelector('.pm-message-list');
  if (container != null) {
    for (final el in container.children) {
      if (el.className.contains('pm-thread-label')) {
        final label = el.text.trim();
        currentThreadId = threadMap[label] ?? '';
        list.add(
          PmMessage(
            type: 'label',
            threadTitle: label,
            threadId: currentThreadId,
          ),
        );
        continue;
      }
      if (!el.className.contains('pm-message')) continue;

      final avatarEl = el.querySelector('.avatarNeue');
      final avatarA = el.querySelector('a.avatar');
      final body = el.querySelector('.pm-message-body');
      final info = el.querySelector('.pm-message-info small');
      final isSelf = el.className.contains('pm-message-self');
      final peerInMsg = doc.querySelector('.pm-chat-title strong a.l');
      final peerUserIdInMsg = (peerInMsg?.attributes['href'] ?? '')
          .replaceFirst(RegExp(r'^/user/'), '');
      final peerName = peerInMsg == null
          ? ''
          : htmlDecode(peerInMsg.text.trim());

      list.add(
        PmMessage(
          type: 'message',
          threadId: currentThreadId,
          name: isSelf ? '我' : (peerName.isEmpty ? peerUserIdInMsg : peerName),
          avatar: avatarEl == null
              ? ''
              : bgImageUrl(avatarEl.attributes['style'] ?? ''),
          userId: (avatarA?.attributes['href'] ?? '').replaceFirst(
            RegExp(r'^/user/'),
            '',
          ),
          content: body == null ? '' : body.innerHtml,
          time: info == null
              ? ''
              : info.text.trim().replaceAll(RegExp(r'\s*/\s*del\s*$'), ''),
        ),
      );
    }
  }

  String inputValue(String name) =>
      doc.querySelector('input[name="$name"]')?.attributes['value'] ?? '';

  final peer = doc.querySelector('.pm-chat-title strong a.l');
  final peerUserId = (peer?.attributes['href'] ?? '').replaceFirst(
    RegExp(r'^/user/'),
    '',
  );
  final peerUserName = peer == null ? '' : htmlDecode(peer.text.trim());
  return (
    list: list,
    form: PmForm(
      related: inputValue('related'),
      msgReceivers: inputValue('msg_receivers'),
      currentMsgId: inputValue('current_msg_id'),
      formhash: inputValue('formhash'),
      msgTitle: inputValue('msg_title'),
      peerUserId: peerUserId,
      peerUserName: peerUserName,
      threads: [for (final e in threadMap.entries) (e.value, e.key)],
    ),
  );
}

/// 解析发短信页 (bgm.tv/pm/compose/{uid}.chii)
PmForm parsePmCompose(String html) {
  final doc = parser.parse(html);
  String inputValue(String name) =>
      doc.querySelector('input[name="$name"]')?.attributes['value'] ?? '';
  return PmForm(
    related: inputValue('related'),
    msgReceivers: inputValue('msg_receivers'),
    currentMsgId: inputValue('current_msg_id'),
    formhash: inputValue('formhash'),
    msgTitle: inputValue('msg_title'),
  );
}

/// 用户收藏概览标签 (原项目 UserCollectionsTags / cheerioUserCollectionsTags)
class UserCollectionTag {
  final String tag;
  final int count;

  const UserCollectionTag({this.tag = '', this.count = 0});
}

/// 只取一级文本节点, 对齐原版 cText(\$row, true)
String cTextFirst(Element? el) {
  if (el == null) return '';
  final text = el.nodes
      .where((n) => n.nodeType == Node.TEXT_NODE)
      .map((n) => n.text ?? '')
      .join();
  return htmlDecode(text).trim();
}

List<UserCollectionTag> parseUserCollectionsTags(String html) {
  final fragment = htmlMatch(
    html,
    '<ul id="userTagList"',
    '<div class="menu_inner"',
  );
  if (fragment.isEmpty) return const [];
  final doc = parser.parse(fragment);
  final items = <UserCollectionTag>[];
  for (final a in doc.querySelectorAll('li a.l')) {
    final tag = cTextFirst(a);
    if (tag.isEmpty) continue;
    items.add(
      UserCollectionTag(
        tag: tag,
        count: int.tryParse(cText(a.querySelector('small'))) ?? 0,
      ),
    );
  }
  return items;
}

List<String> userCollectionTagMenuItems(
  List<UserCollectionTag> tags, {
  bool reset = true,
}) => [if (reset) '重置' else '全部', ...tags.map((e) => '${e.tag} (${e.count})')];

String userCollectionTagLabel(String tag) => tag.isEmpty ? '标签' : tag;

String parseUserCollectionTagSelect(String label) {
  if (label == '重置' || label == '全部') return '';
  return label.replaceFirst(RegExp(r' \(\d+\)$'), '');
}

class UserCollectionsPage {
  final List<CollectionItem> items;
  final int page;
  final int pageTotal;

  const UserCollectionsPage({
    this.items = const [],
    this.page = 1,
    this.pageTotal = 1,
  });
}

String _absCover(String url) {
  if (url.isEmpty || url == '/img/info_only.png') return '';
  if (url.startsWith('//')) return 'https:$url';
  return url;
}

int _starFromClass(String cls) {
  final m = RegExp(r'stars(\d+)').firstMatch(cls);
  return int.tryParse(m?.group(1) ?? '') ?? 0;
}

({int page, int pageTotal}) parseUserCollectionsPagination(String html) {
  final edge = RegExp(
    r'p_edge">[^0-9]*(\d+)[^0-9]*/[^0-9]*(\d+)',
  ).firstMatch(html);
  if (edge != null) {
    return (
      page: int.tryParse(edge.group(1)!) ?? 1,
      pageTotal: int.tryParse(edge.group(2)!) ?? 1,
    );
  }
  var maxPage = 1;
  var cur = 1;
  for (final m in RegExp(r'[?&]page=(\d+)').allMatches(html)) {
    final n = int.tryParse(m.group(1) ?? '') ?? 0;
    if (n > maxPage) maxPage = n;
  }
  final curEl = RegExp(r'class="p_cur">(\d+)').firstMatch(html);
  if (curEl != null) cur = int.tryParse(curEl.group(1)!) ?? 1;
  return (page: cur, pageTotal: maxPage);
}

/// 原项目 cheerioUserCollections
UserCollectionsPage parseUserCollections(
  String html, {
  required String subjectType,
  required int status,
}) {
  final fragment = htmlMatch(
    html,
    '<ul id="browserItemList"',
    '<div id="columnSubjectBrowserB"',
  );
  final doc = parser.parse(fragment.isEmpty ? html : fragment);
  final items = <CollectionItem>[];
  for (final li in doc.querySelectorAll('#browserItemList li.item')) {
    final a = li.querySelector('h3 a.l');
    final href = cData(a, 'href');
    final id =
        int.tryParse(
          RegExp(r'/subject/(\d+)').firstMatch(href)?.group(1) ?? '',
        ) ??
        int.tryParse(RegExp(r'item_(\d+)').firstMatch(li.id)?.group(1) ?? '') ??
        0;
    if (id == 0) continue;
    final nameCn = htmlDecode(cText(a));
    final name = htmlDecode(cText(li.querySelector('small.grey')));
    final cover = _absCover(cData(li.querySelector('img.cover'), 'src'));
    final tagsText = htmlDecode(
      cText(li.querySelector('.collectInfo .tip')),
    ).replaceFirst(RegExp(r'^标签:\s*'), '');
    final tip = htmlDecode(
      cText(li.querySelector('.info.tip')),
    ).replaceAll(RegExp(r'\s+'), ' ');
    items.add(
      CollectionItem(
        subject: Subject(
          id: id,
          type: subjectType,
          name: name,
          nameCn: nameCn,
          images: SubjectImages(common: cover, medium: cover),
        ),
        subjectId: id,
        subjectType: subjectType,
        rate: _starFromClass(cData(li.querySelector('.starlight'), 'class')),
        type: status,
        comment: htmlDecode(cText(li.querySelector('.text_main_even'))),
        tags: [
          for (final t in tagsText.split(RegExp(r'\s+')))
            if (t.isNotEmpty && t != '自己可见') t,
        ],
        updatedAt: cText(li.querySelector('.collectInfo .tip_j')),
        tip: tip,
      ),
    );
  }
  final page = parseUserCollectionsPagination(html);
  return UserCollectionsPage(
    items: items,
    page: page.page,
    pageTotal: page.pageTotal,
  );
}

/// 用户主页附加信息 (原项目 stores/users join / recent / percent)
class UserHomeExtra {
  final String join;
  final String recent;
  final double percent;
  final String hobby;

  const UserHomeExtra({
    this.join = '',
    this.recent = '',
    this.percent = 0,
    this.hobby = '',
  });
}

UserHomeExtra parseUserHomeExtra(String html) {
  final doc = parser.parse(html);
  final join = htmlDecode(doc.querySelector('span.tip')?.text.trim() ?? '');
  final recent = htmlDecode(
    doc.querySelector('.timeline small.time')?.text.trim() ?? '',
  );
  final percentText = doc.querySelector('span.percent_text')?.text ?? '';
  final percent = double.tryParse(percentText.replaceAll('%', '').trim()) ?? 0;
  final hobbyMatch = RegExp(
    r'\d+',
  ).firstMatch(doc.querySelector('small.hot')?.text ?? '');
  return UserHomeExtra(
    join: join,
    recent: recent,
    percent: percent,
    hobby: hobbyMatch?.group(0) ?? '',
  );
}

/// 主站页面是否实际返回了内容 (登录失效/反爬时返回空壳页)
bool isMainSiteValidPage(String html, String marker) {
  if (html.trim().isEmpty) return false;
  final title =
      RegExp(r'<title>([^<]*)</title>').firstMatch(html)?.group(1) ?? '';
  if (title.contains('登录')) return false;
  return html.contains(marker);
}

/// 基础片假名 → 罗马音 (仅单音, 不含拗音/促音/长音, 用于本地管理的标题注音)
const Map<String, String> _katakanaRomaji = {
  'ア': 'a',
  'イ': 'i',
  'ウ': 'u',
  'エ': 'e',
  'オ': 'o',
  'カ': 'ka',
  'キ': 'ki',
  'ク': 'ku',
  'ケ': 'ke',
  'コ': 'ko',
  'サ': 'sa',
  'シ': 'shi',
  'ス': 'su',
  'セ': 'se',
  'ソ': 'so',
  'タ': 'ta',
  'チ': 'chi',
  'ツ': 'tsu',
  'テ': 'te',
  'ト': 'to',
  'ナ': 'na',
  'ニ': 'ni',
  'ヌ': 'nu',
  'ネ': 'ne',
  'ノ': 'no',
  'ハ': 'ha',
  'ヒ': 'hi',
  'フ': 'fu',
  'ヘ': 'he',
  'ホ': 'ho',
  'マ': 'ma',
  'ミ': 'mi',
  'ム': 'mu',
  'メ': 'me',
  'モ': 'mo',
  'ヤ': 'ya',
  'ユ': 'yu',
  'ヨ': 'yo',
  'ラ': 'ra',
  'リ': 'ri',
  'ル': 'ru',
  'レ': 're',
  'ロ': 'ro',
  'ワ': 'wa',
  'ヲ': 'wo',
  'ン': 'n',
  'ガ': 'ga',
  'ギ': 'gi',
  'グ': 'gu',
  'ゲ': 'ge',
  'ゴ': 'go',
  'ザ': 'za',
  'ジ': 'ji',
  'ズ': 'zu',
  'ゼ': 'ze',
  'ゾ': 'zo',
  'ダ': 'da',
  'ヂ': 'ji',
  'ヅ': 'zu',
  'デ': 'de',
  'ド': 'do',
  'バ': 'ba',
  'ビ': 'bi',
  'ブ': 'bu',
  'ベ': 'be',
  'ボ': 'bo',
  'パ': 'pa',
  'ピ': 'pi',
  'プ': 'pu',
  'ペ': 'pe',
  'ポ': 'po',
};

String basicKatakanaToRomaji(String text) {
  if (text.isEmpty) return '';
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_katakanaRomaji[ch] ?? ch);
  }
  return buffer.toString();
}
