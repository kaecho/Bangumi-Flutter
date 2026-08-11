/// 主站 HTML 页面解析 (吐槽箱 / 目录 / 维基修订历史)
///
/// 旧版 API 的吐槽/目录/维基接口已下线 (返回 code:404),
/// 与原生 App 一致, 直接从主站 HTML 页面提取数据。
library;

import 'subject_models.dart';

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
        RegExp(r'<a href="/user/[^"]+" class="l"[^>]*>([\s\S]*?)</a>').firstMatch(block)?.group(1)?.trim() ?? '';
    final starMatch = RegExp(r'starlight stars(\d+)').firstMatch(block);
    final star = starMatch == null ? 0 : int.tryParse(starMatch.group(1)!) ?? 0;
    final greys = RegExp(r'<small class="grey">([\s\S]*?)</small>')
        .allMatches(block)
        .map((e) => e.group(1)!.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final action = greys.isEmpty ? '' : greys.first.replaceFirst('@', '').trim();
    final time = greys.length > 1 ? greys.last.replaceFirst('@', '').trim() : '';
    final content =
        RegExp(r'<p class="comment">([\s\S]*?)</p>').firstMatch(block)?.group(1) ?? '';
    final avatar = _avatarFromStyle(
        RegExp(r'<span class="avatarNeue[^"]*" style="([^"]*)"').firstMatch(block)?.group(1) ?? '');

    items.add(SubjectCommentItem(
      id: '${userId}_${items.length}',
      userId: userId,
      userName: userName,
      avatar: avatar,
      time: time,
      star: star,
      content: stripHtmlTags(content),
      action: action,
    ));
  }

  final page = int.tryParse(
          RegExp(r'<strong class="p_cur">(\d+)</strong>').firstMatch(html)?.group(1) ?? '1') ??
      1;
  final edge = RegExp(r'p_edge">[^0-9]*(\d+)[^0-9]*/[^0-9]*(\d+)')
      .firstMatch(html);
  final pageTotal = int.tryParse(edge?.group(2) ?? '') ?? (page > 1 ? page : 1);

  return CommentPage(page: page, pageTotal: pageTotal, items: items);
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

    final userName = RegExp(
            r'<a href="/user/[^"]+" class="l[^"]*"[^>]*>([\s\S]*?)</a>')
        .firstMatch(block)?.group(1)?.trim() ?? '';
    final time = RegExp(r'floor-anchor">#[^<]*</a> - ([\s\S]*?)</small>')
            .firstMatch(block)?.group(1)?.trim() ??
        '';
    final content = RegExp(r'<div class="message clearit">([\s\S]*?)</div>')
            .firstMatch(block)?.group(1) ??
        '';
    final avatar = _avatarFromStyle(
        RegExp(r'<span class="avatarNeue[^"]*" style="([^"]*)"').firstMatch(block)?.group(1) ?? '');

    items.add(SubjectCommentItem(
      id: id,
      userId: userId,
      userName: userName,
      avatar: avatar,
      time: time,
      content: stripHtmlTags(content),
    ));
  }

  final page = int.tryParse(
          RegExp(r'<strong class="p_cur">(\d+)</strong>').firstMatch(html)?.group(1) ?? '1') ??
      1;
  final edge = RegExp(r'p_edge">[^0-9]*(\d+)[^0-9]*/[^0-9]*(\d+)')
      .firstMatch(html);
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
        int.tryParse(RegExp(r'<span class="num">(\d+)</span>').firstMatch(block)?.group(1) ?? '') ??
            0;
    final title = RegExp(r'<h3>([\s\S]*?)</h3>').firstMatch(block)?.group(1)?.trim() ?? '';
    final userMatch = RegExp(r'<a href="/user/[^"]+" class="l">([\s\S]*?)</a>').firstMatch(block);
    final userName = userMatch?.group(1)?.trim() ?? '';
    final updatedAt = RegExp(r'更新 <span class="tip_j">([\s\S]*?)</span>')
            .firstMatch(block)?.group(1)?.trim() ??
        '';
    final avatar = _avatarFromStyle(
        RegExp(r'<span class="avatarNeue[^"]*" style="([^"]*)"').firstMatch(block)?.group(1) ?? '');

    items.add(CatalogItem(
      id: id,
      title: stripHtmlTags(title),
      userName: userName,
      userAvatar: avatar,
      collected: collected,
      updatedAt: updatedAt,
    ));
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
        RegExp(r'<a href="#;" title="[^"]*">([\s\S]*?)</a>').firstMatch(block)?.group(1)?.trim() ??
            '';
    final userName = RegExp(r'<a href="/user/[^"]+" title="[^"]*" class="l">([\s\S]*?)</a>')
            .firstMatch(block)?.group(1)?.trim() ??
        '';
    final summary = RegExp(r'<span class="comment">\(?([\s\S]*?)\)?</span>')
            .firstMatch(block)?.group(1)?.trim() ??
        '';
    final rev = int.tryParse(
            RegExp(r'name="rev\[\]" value="(\d+)"').firstMatch(block)?.group(1) ?? '') ??
        0;

    items.add(WikiEdit(time: time, userName: userName, summary: summary, rev: rev));
  }
  return items;
}
