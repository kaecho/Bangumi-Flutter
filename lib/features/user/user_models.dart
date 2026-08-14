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
  return TimelineItem(
    id: int.tryParse(idMatch?.group(1) ?? '') ?? 0,
    createdAt: createdAt,
    content: text,
    clearHref: clear,
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
