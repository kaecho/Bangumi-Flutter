/// bgm.tv 链接匹配 → 应用内路由 (移植自原项目 utils/match matchBgmUrl + appNavigate)
library;

/// 从字符串中提取第一个 bgm 相关地址
/// 支持: bgm.tv / bangumi.tv / chii.in / next.bgm.tv 域名下的各类页面
String? matchBgmUrl(String str) {
  final cleaned = str
      .replaceAll('【', '[')
      .replaceAll('】', ']')
      .replaceAll(RegExp(r'\s'), '');
  final m = RegExp(
    r'''https?://(?:[a-z0-9-]+\.)*(?:bgm\.tv|bangumi\.tv|chii\.in|next\.bgm\.tv)/[^\s\]\)"'<>\u4e00-\u9fff]+''',
    caseSensitive: false,
  ).firstMatch(cleaned);
  return m?.group(0);
}

/// 将 bgm.tv 链接解析为应用内路由
/// 返回 null 表示无法识别
String? bgmUrlToRoute(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final host = uri.host;
  if (!host.endsWith('bgm.tv') &&
      !host.endsWith('bangumi.tv') &&
      !host.endsWith('chii.in') &&
      !host.endsWith('next.bgm.tv')) {
    return null;
  }
  final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segs.isEmpty) return '/discovery';

  final head = segs.first;
  switch (head) {
    case 'subject':
      if (segs.length >= 2 && RegExp(r'^\d+$').hasMatch(segs[1])) {
        return '/subject/${segs[1]}';
      }
      if (segs.length >= 3 &&
          segs[1] == 'topic' &&
          RegExp(r'^\d+$').hasMatch(segs[2])) {
        return '/rakuen/topic/group/${segs[2]}';
      }
      if (segs.length >= 3 &&
          segs[1] == 'ep' &&
          RegExp(r'^\d+$').hasMatch(segs[2])) {
        return '/rakuen/topic/ep/${segs[2]}';
      }
      return null;
    case 'group':
      if (segs.length >= 3 &&
          segs[1] == 'topic' &&
          RegExp(r'^\d+$').hasMatch(segs[2])) {
        return '/rakuen/topic/group/${segs[2]}';
      }
      if (segs.length >= 2 && segs[1] == 'topics') {
        return '/rakuen/group/${segs[0]}';
      }

      if (segs.length >= 2) return '/rakuen/group/${segs[1]}';
      return null;
    case 'rakuen':
      // /rakuen/topic/group/350677
      if (segs.length >= 3 && segs[1] == 'topic') {
        final topicId = segs.sublist(2).join('/');
        return '/rakuen/topic/$topicId';
      }
      return null;
    case 'topic':
      if (segs.length >= 2) return '/rakuen/topic/${segs.sublist(1).join('/')}';
      return null;
    case 'user':
      if (segs.length < 2) return null;
      final userId = segs[1];
      if (segs.length >= 3) {
        switch (segs[2]) {
          case 'index':
            return '/user/$userId/catalogs';
          case 'blog':
            return '/user/$userId/blogs';
          case 'mono':
            return '/user/$userId/mono';
          case 'friends':
            return '/user/$userId/friends';
          case 'rev_friends':
            return '/user/$userId/friends?rev=1';
          case 'timeline':
            return '/user/$userId/timeline';
        }
      }
      return '/user/$userId';
    case 'tag':
      if (segs.length >= 2) {
        return '/tags/anime/${Uri.encodeComponent(segs[1])}';
      }
      return '/tags';

    case 'character':
      if (segs.length >= 2 && RegExp(r'^\d+$').hasMatch(segs[1])) {
        return '/mono/character/${segs[1]}';
      }
      return null;
    case 'person':
      if (segs.length >= 2 && RegExp(r'^\d+$').hasMatch(segs[1])) {
        return '/mono/person/${segs[1]}';
      }
      return null;
    case 'blog':
      if (segs.length >= 2 && RegExp(r'^\d+$').hasMatch(segs[1])) {
        return '/rakuen/blog/${segs[1]}';
      }
      return null;
    case 'ep':
      if (segs.length >= 2 && RegExp(r'^\d+$').hasMatch(segs[1])) {
        return '/rakuen/topic/ep/${segs[1]}';
      }
      return null;
    case 'index':
      if (segs.length >= 2 && RegExp(r'^\d+$').hasMatch(segs[1])) {
        return '/catalog/${segs[1]}';
      }
      return null;
    case 'anime':
    case 'book':
    case 'game':
    case 'real':
      if (segs.length >= 3 && segs[1] == 'tag') {
        final type = switch (head) {
          'book' => 'book',
          'game' => 'game',
          'real' => 'real',
          _ => 'anime',
        };
        return '/tags/$type/${Uri.encodeComponent(segs[2])}';
      }
      return switch (head) {
        'game' => '/game',
        'book' => '/wenku',
        'real' => '/browser',
        _ => '/anime',
      };

    case 'calendar':
      return '/calendar';
    case 'rakuen2':
      return '/rakuen';
    default:
      return null;
  }
}
