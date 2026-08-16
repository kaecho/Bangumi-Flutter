/// 主站 HTML 页面解析 (吐槽箱 / 目录 / 维基修订历史)
///
/// 旧版 API 的吐槽/目录/维基接口已下线 (返回 code:404),
/// 与原生 App 一致, 直接从主站 HTML 页面提取数据。
library;

import '../../shared/models/subject.dart';
import '../../shared/models/mono.dart';

import 'subject_models.dart';
import 'package:html/parser.dart' as parser;

import '../../core/html/bgm_html_parser.dart';

/// 去除 HTML 标签, 还原实体
String stripHtmlTags(String html) {
  return html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// 从 style="background-image:url('...')" 提取图片地址
String _avatarFromStyle(String style) {
  final m = RegExp(r"url\('([^']+)'\)").firstMatch(style);
  if (m == null) return '';
  return _https(m.group(1)!);
}

/// 图片地址统一转 https
String _https(String url) {
  if (url.startsWith('//')) return 'https:$url';
  if (url.startsWith('http://')) return url.replaceFirst('http://', 'https://');
  return url;
}

/// 解析条目吐槽页: /subject/{id}/comments
/// 结构: #comment_box > div.item.clearit
CommentPage parseSubjectCommentsHtml(String html) {
  final items = <SubjectCommentItem>[];
  final itemRe = RegExp(
    r'<div class="item clearit" data-item-user="([^"]*)">([\s\S]*?)(?=<div class="item clearit"|</div>\s*</div>\s*</div>\s*$|$)',
  );
  for (final m in itemRe.allMatches(html)) {
    final userId = m.group(1) ?? '';
    final block = m.group(2) ?? '';
    if (block.trim().isEmpty) continue;

    final userName =
        RegExp(
          r'<a href="/user/[^"]+" class="l"[^>]*>([\s\S]*?)</a>',
        ).firstMatch(block)?.group(1)?.trim() ??
        '';
    final starMatch = RegExp(r'starlight stars(\d+)').firstMatch(block);
    final star = starMatch == null ? 0 : int.tryParse(starMatch.group(1)!) ?? 0;
    final greys = RegExp(r'<small class="grey">([\s\S]*?)</small>')
        .allMatches(block)
        .map((e) => e.group(1)!.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final action = greys.isEmpty
        ? ''
        : greys.first.replaceFirst('@', '').trim();
    final time = greys.length > 1
        ? greys.last.replaceFirst('@', '').trim()
        : '';
    final content =
        RegExp(
          r'<p class="comment">([\s\S]*?)</p>',
        ).firstMatch(block)?.group(1) ??
        '';
    final avatar = _avatarFromStyle(
      RegExp(
            r'<span class="avatarNeue[^"]*" style="([^"]*)"',
          ).firstMatch(block)?.group(1) ??
          '',
    );

    items.add(
      SubjectCommentItem(
        id: '${userId}_${items.length}',
        userId: userId,
        userName: userName,
        avatar: avatar,
        time: time,
        star: star,
        content: stripHtmlTags(content),
        action: action,
      ),
    );
  }

  final page =
      int.tryParse(
        RegExp(
              r'<strong class="p_cur">(\d+)</strong>',
            ).firstMatch(html)?.group(1) ??
            '1',
      ) ??
      1;
  final edge = RegExp(
    r'p_edge">[^0-9]*(\d+)[^0-9]*/[^0-9]*(\d+)',
  ).firstMatch(html);
  final pageTotal = int.tryParse(edge?.group(2) ?? '') ?? (page > 1 ? page : 1);

  final hasVersion =
      html.contains('version=current') ||
      html.contains("id='SecTab'") ||
      html.contains('id="SecTab"');
  return CommentPage(
    page: page,
    pageTotal: pageTotal,
    items: items,
    hasVersion: hasVersion,
  );
}

/// 解析章节 / 角色吐槽: /ep/{id} 或 /character/{id}
/// 结构: #comment_list > div.row.row_reply
CommentPage parseTopicCommentsHtml(String html) {
  final items = <SubjectCommentItem>[];
  final itemRe = RegExp(
    r'<div id="post_(\d+)" class="[^"]*row_reply[^"]*" name="[^"]*" data-item-user="([^"]*)">([\s\S]*?)(?=<div id="post_\d+"|$)',
  );
  for (final m in itemRe.allMatches(html)) {
    final id = m.group(1) ?? '';
    final userId = m.group(2) ?? '';
    final block = m.group(3) ?? '';
    if (block.trim().isEmpty) continue;

    final userName =
        RegExp(
          r'<a href="/user/[^"]+" class="l[^"]*"[^>]*>([\s\S]*?)</a>',
        ).firstMatch(block)?.group(1)?.trim() ??
        '';
    final time =
        RegExp(
          r'floor-anchor">#[^<]*</a> - ([\s\S]*?)</small>',
        ).firstMatch(block)?.group(1)?.trim() ??
        '';
    final content =
        RegExp(
          r'<div class="message clearit">([\s\S]*?)</div>',
        ).firstMatch(block)?.group(1) ??
        '';
    final avatar = _avatarFromStyle(
      RegExp(
            r'<span class="avatarNeue[^"]*" style="([^"]*)"',
          ).firstMatch(block)?.group(1) ??
          '',
    );

    items.add(
      SubjectCommentItem(
        id: id,
        userId: userId,
        userName: userName,
        avatar: avatar,
        time: time,
        content: stripHtmlTags(content),
      ),
    );
  }

  final page =
      int.tryParse(
        RegExp(
              r'<strong class="p_cur">(\d+)</strong>',
            ).firstMatch(html)?.group(1) ??
            '1',
      ) ??
      1;
  final edge = RegExp(
    r'p_edge">[^0-9]*(\d+)[^0-9]*/[^0-9]*(\d+)',
  ).firstMatch(html);
  final pageTotal = int.tryParse(edge?.group(2) ?? '') ?? (page > 1 ? page : 1);

  return CommentPage(page: page, pageTotal: pageTotal, items: items);
}

/// 解析包含条目的目录页: /subject/{id}/index
List<CatalogItem> parseCatalogsHtml(String html) {
  final items = <CatalogItem>[];
  final itemRe = RegExp(
    r'<li id="item_(\d+)" class="[^"]*index-item[^"]*">([\s\S]*?)(?=<li id="item_\d+"|$)',
  );
  for (final m in itemRe.allMatches(html)) {
    final id = int.tryParse(m.group(1) ?? '') ?? 0;
    final block = m.group(2) ?? '';
    if (block.isEmpty) continue;

    final collected =
        int.tryParse(
          RegExp(
                r'<span class="num">(\d+)</span>',
              ).firstMatch(block)?.group(1) ??
              '',
        ) ??
        0;
    final title =
        RegExp(r'<h3>([\s\S]*?)</h3>').firstMatch(block)?.group(1)?.trim() ??
        '';
    final userMatch = RegExp(
      r'<a href="/user/[^"]+" class="l">([\s\S]*?)</a>',
    ).firstMatch(block);
    final userName = userMatch?.group(1)?.trim() ?? '';
    final updatedAt =
        RegExp(
          r'更新 <span class="tip_j">([\s\S]*?)</span>',
        ).firstMatch(block)?.group(1)?.trim() ??
        '';
    final avatar = _avatarFromStyle(
      RegExp(
            r'<span class="avatarNeue[^"]*" style="([^"]*)"',
          ).firstMatch(block)?.group(1) ??
          '',
    );

    items.add(
      CatalogItem(
        id: id,
        title: stripHtmlTags(title),
        userName: userName,
        userAvatar: avatar,
        collected: collected,
        updatedAt: updatedAt,
      ),
    );
  }
  return items;
}

/// 解析维基修订历史: /subject/{id}/edit
List<WikiEdit> parseWikiEditsHtml(String html) {
  final items = <WikiEdit>[];
  final itemRe = RegExp(
    r'<li class="line_(?:even|odd)">([\s\S]*?)(?=<li class="line_(?:even|odd)">|$)',
  );
  for (final m in itemRe.allMatches(html)) {
    final block = m.group(1) ?? '';
    if (!block.contains('subjectRevisionEntry')) continue;

    final time =
        RegExp(
          r'<a href="#;" title="[^"]*">([\s\S]*?)</a>',
        ).firstMatch(block)?.group(1)?.trim() ??
        '';
    final userName =
        RegExp(
          r'<a href="/user/[^"]+" title="[^"]*" class="l">([\s\S]*?)</a>',
        ).firstMatch(block)?.group(1)?.trim() ??
        '';
    final summary =
        RegExp(
          r'<span class="comment">\(?([\s\S]*?)\)?</span>',
        ).firstMatch(block)?.group(1)?.trim() ??
        '';
    final rev =
        int.tryParse(
          RegExp(r'name="rev\[\]" value="(\d+)"').firstMatch(block)?.group(1) ??
              '',
        ) ??
        0;

    items.add(
      WikiEdit(time: time, userName: userName, summary: summary, rev: rev),
    );
  }
  return items;
}

/// 解析条目主站页: 锁定提示 + 猜你喜欢
SubjectHtmlExtras parseSubjectHtmlExtras(String html) {
  final lock =
      RegExp(
        r'<div class="tipIntro">[\s\S]*?<div class="inner">[\s\S]*?<h3>([\s\S]*?)</h3>',
      ).firstMatch(html)?.group(1)?.trim() ??
      '';
  final likes = <SubjectListItem>[];
  final likeBlock = RegExp(
    r'<ul class="coversSmall">([\s\S]*?)</ul>',
  ).firstMatch(html)?.group(1);
  if (likeBlock != null) {
    final itemRe = RegExp(r'<li[^>]*>([\s\S]*?)</li>');
    for (final m in itemRe.allMatches(likeBlock)) {
      final block = m.group(1) ?? '';
      final href =
          RegExp(r'href="(/subject/\d+)"').firstMatch(block)?.group(1) ?? '';
      final id = int.tryParse(href.split('/').last) ?? 0;
      if (id <= 0) continue;
      final name =
          RegExp(r'title="([^"]*)"').firstMatch(block)?.group(1)?.trim() ??
          stripHtmlTags(
            RegExp(
                  r'<a[^>]*class="l"[^>]*>([\s\S]*?)</a>',
                ).firstMatch(block)?.group(1) ??
                '',
          );
      final image = _https(
        _avatarFromStyle(
          RegExp(r'<span[^>]*style="([^"]*)"').firstMatch(block)?.group(1) ??
              '',
        ),
      );
      likes.add(
        SubjectListItem(
          id: id,
          name: name,
          images: SubjectImages(
            common: image,
            medium: image,
            small: image,
            grid: image,
            large: image,
          ),
        ),
      );
    }
  }
  final recent = <SubjectRecentUser>[];
  final whoBlock = RegExp(
    r'id="subjectPanelCollect"[^>]*>([\s\S]*?)</ul>',
  ).firstMatch(html)?.group(1);
  if (whoBlock != null) {
    final itemRe = RegExp(r'<li[^>]*>([\s\S]*?)</li>');
    for (final m in itemRe.allMatches(whoBlock)) {
      final block = m.group(1) ?? '';
      final userId =
          RegExp(r'href="/user/([^"]+)"').firstMatch(block)?.group(1) ?? '';
      if (userId.isEmpty) continue;
      final name = stripHtmlTags(
        RegExp(
              r'<a[^>]*class="avatar"[^>]*>([\s\S]*?)</a>',
            ).firstMatch(block)?.group(1) ??
            RegExp(
              r'<a href="/user/[^"]+"[^>]*>([\s\S]*?)</a>',
            ).firstMatch(block)?.group(1) ??
            '',
      );
      final avatar = _https(
        _avatarFromStyle(
          RegExp(
                r'<span class="avatarNeue[^"]*" style="([^"]*)"',
              ).firstMatch(block)?.group(1) ??
              '',
        ),
      );
      final starMatch = RegExp(r'starlight stars(\d+)').firstMatch(block);
      final star = starMatch == null
          ? 0
          : int.tryParse(starMatch.group(1)!) ?? 0;
      final status = stripHtmlTags(
        RegExp(
              r'<small class="grey">([\s\S]*?)</small>',
            ).firstMatch(block)?.group(1) ??
            '',
      ).replaceAll('小时', '时').replaceAll('分钟', '分');
      recent.add(
        SubjectRecentUser(
          userId: userId,
          name: name,
          avatar: avatar,
          star: star,
          status: status,
        ),
      );
    }
  }
  final discs = <SubjectDisc>[];
  final musicBlock = RegExp(
    r'<ul class="line_list_music">([\s\S]*?)</ul>',
  ).firstMatch(html)?.group(1);
  if (musicBlock != null) {
    final itemRe = RegExp(r'<li([^>]*)>([\s\S]*?)</li>');
    for (final m in itemRe.allMatches(musicBlock)) {
      final attrs = m.group(1) ?? '';
      final block = m.group(2) ?? '';
      if (attrs.contains('cat')) {
        discs.add(SubjectDisc(title: stripHtmlTags(block)));
        continue;
      }
      if (discs.isEmpty) discs.add(const SubjectDisc(title: 'Disc'));
      final href =
          RegExp(r'href="(/ep/\d+)"').firstMatch(block)?.group(1) ?? '';
      final epId = int.tryParse(href.split('/').last) ?? 0;
      final title = stripHtmlTags(
        RegExp(
              r'<h6[^>]*>[\s\S]*?<a[^>]*>([\s\S]*?)</a>',
            ).firstMatch(block)?.group(1) ??
            '',
      );
      if (title.isEmpty) continue;
      final last = discs.removeLast();
      discs.add(
        SubjectDisc(
          title: last.title,
          tracks: [
            ...last.tracks,
            SubjectDiscTrack(epId: epId, title: title),
          ],
        ),
      );
    }
  }
  final comics = <SubjectListItem>[];
  final comicBlock = RegExp(
    r'单行本[\s\S]*?<ul class="browserCoverMedium">([\s\S]*?)</ul>',
  ).firstMatch(html)?.group(1);
  if (comicBlock != null) {
    final itemRe = RegExp(r'<li[^>]*>([\s\S]*?)</li>');
    for (final m in itemRe.allMatches(comicBlock)) {
      final block = m.group(1) ?? '';
      final href =
          RegExp(r'href="(/subject/\d+)"').firstMatch(block)?.group(1) ?? '';
      final id = int.tryParse(href.split('/').last) ?? 0;
      if (id <= 0) continue;
      final name =
          RegExp(r'title="([^"]*)"').firstMatch(block)?.group(1)?.trim() ??
          stripHtmlTags(
            RegExp(
                  r'<a[^>]*class="title"[^>]*>([\s\S]*?)</a>',
                ).firstMatch(block)?.group(1) ??
                '',
          );
      final image = _https(
        _avatarFromStyle(
          RegExp(r'style="([^"]*)"').firstMatch(block)?.group(1) ?? '',
        ),
      );
      comics.add(
        SubjectListItem(
          id: id,
          name: name,
          images: SubjectImages(
            common: image,
            medium: image,
            small: image,
            grid: image,
            large: image,
          ),
        ),
      );
    }
  }
  final friendScore =
      double.tryParse(
        RegExp(
              r'<div class="frdScore">[\s\S]*?<span class="num">([\d.]+)</span>',
            ).firstMatch(html)?.group(1) ??
            '',
      ) ??
      0;
  final friendTotal =
      int.tryParse(
        RegExp(
              r'<div class="frdScore">[\s\S]*?<a class="l">(\d+)\s*人评分',
            ).firstMatch(html)?.group(1) ??
            '',
      ) ??
      0;
  return SubjectHtmlExtras(
    lock: stripHtmlTags(lock),
    likes: likes,
    recent: recent,
    discs: discs,
    comics: comics,
    friendScore: friendScore,
    friendTotal: friendTotal,
  );
}

/// 解析所有人评分页: /subject/{id}/{status}?filter=friends
/// 结构对齐原项目 cheerioRating: ul.secTab + #memberUserList li
SubjectRatingPage parseSubjectRatingHtml(String html) {
  var wishes = 0;
  var collections = 0;
  var doings = 0;
  var onHold = 0;
  var dropped = 0;
  final tabRe = RegExp(r'<li[^>]*>([\s\S]*?)</li>');
  final tabBlock = RegExp(
    r'<ul class="secTab"[^>]*>([\s\S]*?)</ul>',
  ).firstMatch(html)?.group(1);
  if (tabBlock != null) {
    for (final m in tabRe.allMatches(tabBlock)) {
      final text = stripHtmlTags(m.group(1) ?? '');
      final n =
          int.tryParse(RegExp(r'(\d+)').firstMatch(text)?.group(1) ?? '') ?? 0;
      if (text.contains('想')) {
        wishes = n;
      } else if (text.contains('过')) {
        collections = n;
      } else if (text.contains('在')) {
        doings = n;
      } else if (text.contains('搁置')) {
        onHold = n;
      } else if (text.contains('抛弃')) {
        dropped = n;
      }
    }
  }

  final items = <SubjectCommentItem>[];
  final itemRe = RegExp(r'<li[^>]*>([\s\S]*?)</li>');
  final listBlock = RegExp(
    r'id="memberUserList"[^>]*>([\s\S]*?)</ul>',
  ).firstMatch(html)?.group(1);
  if (listBlock != null) {
    for (final m in itemRe.allMatches(listBlock)) {
      final block = m.group(1) ?? '';
      if (block.trim().isEmpty) continue;
      final userHref =
          RegExp(r'href="(/user/[^"]+)"').firstMatch(block)?.group(1) ?? '';
      final userId = userHref.replaceFirst('/user/', '');
      if (userId.isEmpty) continue;
      final name =
          RegExp(
            r'<a href="/user/[^"]+" class="avatar"[^>]*>([\s\S]*?)</a>',
          ).firstMatch(block)?.group(1)?.trim() ??
          '';
      final time =
          RegExp(
            r'<p class="info">([\s\S]*?)</p>',
          ).firstMatch(block)?.group(1)?.trim() ??
          '';
      final starMatch = RegExp(r'starlight stars(\d+)').firstMatch(block);
      final star = starMatch == null
          ? 0
          : int.tryParse(starMatch.group(1)!) ?? 0;
      final avatar = _avatarFromStyle(
        RegExp(
              r'<span class="avatarNeue[^"]*" style="([^"]*)"',
            ).firstMatch(block)?.group(1) ??
            '',
      );
      final raw = stripHtmlTags(
        RegExp(
              r'<div class="userContainer">([\s\S]*?)</div>',
            ).firstMatch(block)?.group(1) ??
            '',
      );
      var comment = raw;
      if (name.isNotEmpty) comment = comment.replaceFirst(name, '').trim();
      if (time.isNotEmpty) comment = comment.replaceFirst(time, '').trim();
      items.add(
        SubjectCommentItem(
          id: userId,
          userId: userId,
          userName: stripHtmlTags(name),
          avatar: avatar,
          time: stripHtmlTags(time),
          star: star,
          content: comment,
        ),
      );
    }
  }

  return SubjectRatingPage(
    wishes: wishes,
    collections: collections,
    doings: doings,
    onHold: onHold,
    dropped: dropped,
    items: items,
  );
}

String _absCover(String url) {
  if (url.isEmpty) return '';
  final clean = url.split('?').first;
  if (clean == '/img/info_only_m.png') return '';
  if (clean.startsWith('//')) return 'https:$clean';
  if (clean.startsWith('http://')) {
    return clean.replaceFirst('http://', 'https://');
  }

  return clean;
}

int _idFromHref(String href, String prefix) {
  final m = RegExp('$prefix(\\d+)').firstMatch(href);
  return int.tryParse(m?.group(1) ?? '') ?? 0;
}

/// 解析人物角色页: /person/{id}/works/voice
/// 结构对齐原项目 cheerioMonoVoices
MonoVoicesPage parseMonoVoices(String html) {
  final fragment = htmlMatch(html, '<div id="columnCrtB', '<div id="footer');
  final doc = parser.parse(fragment.isEmpty ? html : fragment);
  final list = <MonoVoiceItem>[];
  for (final row in doc.querySelectorAll('ul.browserList > li.item')) {
    final left = row.querySelector('div.innerLeftItem');
    final a = left?.querySelector('h3 > a.l');
    if (a == null) continue;
    final subjects = <MonoVoiceSubject>[];
    for (final li in row.querySelectorAll('ul.innerRightList > li')) {
      final sa = li.querySelector('h3 > a.l');
      if (sa == null) continue;
      subjects.add(
        MonoVoiceSubject(
          id: _idFromHref(sa.attributes['href'] ?? '', '/subject/'),
          name: htmlDecode(sa.text.trim()),
          nameCn: htmlDecode(
            li.querySelector('div.inner small.grey')?.text.trim() ?? '',
          ),
          cover: _absCover(
            li.querySelector('img.cover')?.attributes['src'] ?? '',
          ),
          staff: htmlDecode(
            li.querySelector('span.badge_job')?.text.trim() ?? '',
          ),
          tip: htmlDecode(
            li.querySelector('span.badge_job_tip')?.text.trim() ?? '',
          ),
        ),
      );
    }
    list.add(
      MonoVoiceItem(
        id: _idFromHref(a.attributes['href'] ?? '', '/character/'),
        name: htmlDecode(a.text.trim()),
        nameCn: htmlDecode(
          left?.querySelector('h3 > p.tip')?.text.trim() ?? '',
        ),
        cover: _absCover(
          left?.querySelector('img.avatar')?.attributes['src'] ?? '',
        ),
        subjects: subjects,
      ),
    );
  }
  final filters = <MonoVoiceFilter>[];
  for (final group in doc.querySelectorAll('div.subjectFilter > ul.grouped')) {
    final title = htmlDecode(
      group.querySelector('li.title')?.text.trim() ?? '',
    );
    if (title.isEmpty) continue;
    filters.add(
      MonoVoiceFilter(
        title: title,
        options: [
          for (final a in group.querySelectorAll('a.l'))
            (
              (a.attributes['href'] ?? '').split('/works/voice').last,
              htmlDecode(a.text.trim()),
            ),
        ],
      ),
    );
  }
  return MonoVoicesPage(list: list, filters: filters);
}

/// 解析人物详情页「最近演出角色」预览
List<MonoVoiceItem> parsePersonRecentVoices(String html) {
  final m = RegExp(
    r'<h2 class="subtitle">最近演出角色</h2><ul class="browserList([\s\S]+?)</ul><a href=',
  ).firstMatch(html.replaceAll('\n', ''));
  if (m == null) return const [];
  return parseMonoVoices(
    '<div id="columnCrtB"><ul class="browserList${m.group(1)}</ul></div><div id="footer">',
  ).list;
}

/// 解析人物作品: /person/{id}/works 或 /character/{id}/works
/// 结构对齐原项目 cheerioMonoWorks
MonoWorksPage parseMonoWorks(String html) {
  final fragment = htmlMatch(html, '<div id="columnCrtB', '<div id="footer');
  final doc = parser.parse(fragment.isEmpty ? html : fragment);
  final list = <MonoWorkItem>[];
  for (final row in doc.querySelectorAll('ul#browserItemList > li.item')) {
    final coverA = row.querySelector('a.cover');
    final titleA = row.querySelector('h3 a.l');
    if (coverA == null && titleA == null) continue;
    final href = coverA?.attributes['href'] ?? titleA?.attributes['href'] ?? '';
    final typeClass =
        row.querySelector('span.ico_subject_type')?.attributes['class'] ?? '';
    final typeKey = typeClass
        .replaceAll('ico_subject_type', '')
        .replaceAll('subject_type_', '')
        .replaceAll('ll', '')
        .trim();
    list.add(
      MonoWorkItem(
        id: _idFromHref(href, '/subject/'),
        cover: _absCover(
          row.querySelector('img.cover')?.attributes['src'] ?? '',
        ),
        name: htmlDecode(row.querySelector('small.grey')?.text.trim() ?? ''),
        nameCn: htmlDecode(titleA?.text.trim() ?? ''),
        tip: htmlDecode(row.querySelector('p.tip')?.text.trim() ?? ''),
        positions: [
          for (final job in row.querySelectorAll('span.badge_job'))
            htmlDecode(job.text.trim()),
        ],
        score:
            double.tryParse(
              row.querySelector('small.fade')?.text.trim() ?? '',
            ) ??
            0,
        total: htmlDecode(row.querySelector('span.tip_j')?.text.trim() ?? ''),
        rank:
            int.tryParse(
              (row.querySelector('span.rank')?.text.trim() ?? '').replaceFirst(
                'Rank ',
                '',
              ),
            ) ??
            0,
        collected: row.querySelector('p.collectModify') != null,
        type: typeKey,
      ),
    );
  }
  final filters = <MonoVoiceFilter>[];
  for (final group in doc.querySelectorAll('div.subjectFilter > ul.grouped')) {
    final title = htmlDecode(
      group.querySelector('li.title')?.text.trim() ?? '',
    );
    if (title.isEmpty) continue;
    filters.add(
      MonoVoiceFilter(
        title: title,
        options: [
          for (final a in group.querySelectorAll('a.l'))
            (
              (a.attributes['href'] ?? '').split('/works').last,
              htmlDecode(a.text.trim()),
            ),
        ],
      ),
    );
  }
  return MonoWorksPage(list: list, filters: filters);
}

/// 解析条目更多制作人员: /subject/{id}/persons
/// 结构对齐原项目 cheerioPersons
List<PersonVo> parseSubjectPersons(String html) {
  final fragment = htmlMatch(
    html,
    '<div id="columnInSubjectA',
    '<div id="columnInSubjectB',
  );
  final doc = parser.parse(fragment.isEmpty ? html : fragment);
  final list = <PersonVo>[];
  for (final row in doc.querySelectorAll('div.light_odd')) {
    final a = row.querySelector('h2 > a');
    if (a == null) continue;
    final href = a.attributes['href'] ?? '';
    final id = _idFromHref(href, '/person/');
    if (id == 0) continue;
    final cover = _absCover(
      row.querySelector('img.avatar')?.attributes['src'] ?? '',
    );
    final jobs = [
      for (final job in row.querySelectorAll('span.badge_job'))
        if (htmlDecode(job.text.trim()).isNotEmpty) htmlDecode(job.text.trim()),
    ];
    final tip = htmlDecode(a.querySelector('.tip')?.text.trim() ?? '');
    var name = htmlDecode(a.text.trim());
    if (tip.isNotEmpty) name = name.replaceFirst(tip, '').trim();
    list.add(
      PersonVo(
        id: id,
        name: name,
        nameCn: tip,
        relation: jobs.isEmpty ? '' : jobs.first,
        positions: jobs,
        info: htmlDecode(
          row.querySelectorAll('div.prsn_info').isEmpty
              ? ''
              : row.querySelectorAll('div.prsn_info').last.text.trim(),
        ),
        images: MonoImages(
          large: cover,
          medium: cover,
          small: cover,
          grid: cover,
        ),
      ),
    );
  }
  return list;
}

/// 解析人物收藏动作: `.collect.action a.icon` + `.ico_like`
/// 对齐原项目 cheerioMono collectUrl / eraseCollectUrl
({String collectUrl, String eraseCollectUrl}) parseMonoCollect(String html) {
  final fragment = htmlMatch(
    html,
    '<div id="headerSubject',
    '<div class="crtCommentList',
  );
  final doc = parser.parse(fragment.isEmpty ? html : fragment);
  final action = doc.querySelector('.collect.action a.icon');
  final href = action?.attributes['href'] ?? '';
  if (href.isEmpty) return (collectUrl: '', eraseCollectUrl: '');
  final collected = doc.querySelector('.collect.action .ico_like') != null;
  return collected
      ? (collectUrl: '', eraseCollectUrl: href)
      : (collectUrl: href, eraseCollectUrl: '');
}
