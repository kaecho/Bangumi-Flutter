import '../../core/utils/display.dart';

/// 条目基本信息 (bgm.tv 旧版 API 结构)
class Subject {
  final int id;
  final String url;
  final String type; // anime | book | real | game
  final String name;
  final String nameCn;
  final String summary;
  final int eps;
  final int epsCount;
  final String airDate;
  final int airWeekday;
  final SubjectImages images;
  final Rating? rating;
  final CollectionCount? collection;
  final List<Tag> tags;
  final List<Infobox> infobox;
  final int rank;
  final int volums;
  final bool nsfw;
  final bool collected;

  const Subject({
    required this.id,
    this.url = '',
    this.type = 'anime',
    this.name = '',
    this.nameCn = '',
    this.summary = '',
    this.eps = 0,
    this.epsCount = 0,
    this.airDate = '',
    this.airWeekday = 0,
    required this.images,
    this.rating,
    this.collection,
    this.tags = const [],
    this.infobox = const [],
    this.rank = 0,
    this.volums = 0,
    this.nsfw = false,
    this.collected = false,
  });

  /// 旧版 API / v0 API 返回数字类型 (1=book 2=anime 3=music 4=game 6=real),
  /// 兼容字符串类型
  static String parseType(dynamic value) {
    if (value is String) return value;
    if (value is num) {
      return switch (value.toInt()) {
        1 => 'book',
        2 => 'anime',
        3 => 'music',
        4 => 'game',
        6 => 'real',
        _ => 'anime',
      };
    }
    return 'anime';
  }

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
    id: (json['id'] as num?)?.toInt() ?? 0,
    url: json['url'] as String? ?? '',
    type: parseType(json['type']),
    name: json['name'] as String? ?? '',
    nameCn: json['name_cn'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    eps: (json['eps'] as num?)?.toInt() ?? 0,
    epsCount: (json['eps_count'] as num?)?.toInt() ?? 0,
    airDate: json['air_date'] as String? ?? '',
    airWeekday: (json['air_weekday'] as num?)?.toInt() ?? 0,
    images: SubjectImages.fromJson(
      json['images'] as Map<String, dynamic>? ?? const {},
    ),
    rating: json['rating'] == null
        ? null
        : Rating.fromJson(json['rating'] as Map<String, dynamic>),
    collection: json['collection'] == null
        ? null
        : CollectionCount.fromJson(json['collection'] as Map<String, dynamic>),
    tags:
        (json['tags'] as List?)
            ?.map((e) => Tag.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    infobox:
        (json['infobox'] as List?)
            ?.map((e) => Infobox.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    rank: (json['rank'] as num?)?.toInt() ?? 0,
    volums: (json['volums'] as num?)?.toInt() ?? 0,
    nsfw: json['nsfw'] == true,
    collected: json['collected'] == true,
  );

  /// 展示名: 对齐原版 cnFirst
  String get displayName => cnjp(name, nameCn);

  /// 收藏数文案: 比期望值 期望, 在看 在看, 看过 看过...
  String get collectionText {
    final c = collection;
    if (c == null) return '';
    final parts = <String>[];
    if (c.wish > 0) parts.add('${c.wish} 期望');
    if (c.doing > 0) parts.add('${c.doing} 在看');
    if (c.collect > 0) parts.add('${c.collect} 看过');
    if (c.onHold > 0) parts.add('${c.onHold} 搁置');
    if (c.dropped > 0) parts.add('${c.dropped} 抛弃');
    return parts.join(' / ');
  }
}

class SubjectImages {
  final String large;
  final String common;
  final String medium;
  final String small;
  final String grid;

  const SubjectImages({
    this.large = '',
    this.common = '',
    this.medium = '',
    this.small = '',
    this.grid = '',
  });

  factory SubjectImages.fromJson(Map<String, dynamic> json) => SubjectImages(
    large: _https(json['large'] as String? ?? ''),
    common: _https(json['common'] as String? ?? ''),
    medium: _https(json['medium'] as String? ?? ''),
    small: _https(json['small'] as String? ?? ''),
    grid: _https(json['grid'] as String? ?? ''),
  );

  /// 图片地址统一 https (旧版 API 返回 http://lain.bgm.tv)
  static String _https(String url) {
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('http://')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }
}

class Rating {
  final int total;
  final double score;
  final int rank;
  final Map<int, int> count;

  const Rating({
    this.total = 0,
    this.score = 0,
    this.rank = 0,
    this.count = const {},
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    final raw = json['count'] as Map<String, dynamic>? ?? const {};
    final count = <int, int>{};
    raw.forEach((k, v) => count[int.tryParse(k) ?? 0] = (v as num).toInt());
    return Rating(
      total: (json['total'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      count: count,
    );
  }
}

class CollectionCount {
  final int wish;
  final int collect;
  final int doing;
  final int onHold;
  final int dropped;

  const CollectionCount({
    this.wish = 0,
    this.collect = 0,
    this.doing = 0,
    this.onHold = 0,
    this.dropped = 0,
  });

  factory CollectionCount.fromJson(Map<String, dynamic> json) =>
      CollectionCount(
        wish: (json['wish'] as num?)?.toInt() ?? 0,
        collect: (json['collect'] as num?)?.toInt() ?? 0,
        doing: (json['doing'] as num?)?.toInt() ?? 0,
        onHold: (json['on_hold'] as num?)?.toInt() ?? 0,
        dropped: (json['dropped'] as num?)?.toInt() ?? 0,
      );

  int get total => wish + collect + doing + onHold + dropped;
}

class Tag {
  final String name;
  final int count;

  const Tag({this.name = '', this.count = 0});

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
    name: json['name'] as String? ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
  );
}

class Infobox {
  final String key;
  final dynamic value;

  const Infobox({required this.key, this.value});

  factory Infobox.fromJson(Map<String, dynamic> json) =>
      Infobox(key: json['key'] as String? ?? '', value: json['value']);

  /// 展示值: 兼容字符串 / 数字 / v0 的 [{v: '...'}] 嵌套结构
  String get valueText {
    final v = value;
    if (v == null) return '';
    if (v is String || v is num) return v.toString();
    if (v is List) {
      return v
          .map((e) {
            if (e is Map) {
              final item = e['v'] ?? e['value'] ?? e.values.firstOrNull;
              return item?.toString() ?? '';
            }
            return e.toString();
          })
          .where((s) => s.isNotEmpty)
          .join(' / ');
    }
    if (v is Map) {
      final item = v['v'] ?? v['value'];
      if (item != null) return item.toString();
      return v.values.whereType<String>().join(' / ');
    }
    return v.toString();
  }
}
