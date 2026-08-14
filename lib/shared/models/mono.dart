import '../../core/utils/display.dart';
import 'subject.dart';

/// 角色 / 人物图片
class MonoImages {
  final String large;
  final String medium;
  final String small;
  final String grid;

  const MonoImages({
    this.large = '',
    this.medium = '',
    this.small = '',
    this.grid = '',
  });

  factory MonoImages.fromJson(Map<String, dynamic> json) => MonoImages(
    large: _https(json['large'] as String? ?? ''),
    medium: _https(json['medium'] as String? ?? ''),
    small: _https(json['small'] as String? ?? ''),
    grid: _https(json['grid'] as String? ?? ''),
  );

  static String _https(String url) {
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('http://')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }
}

/// 角色 (虚拟)
class Character {
  final int id;
  final String url;
  final String name;
  final String nameCn;
  final int type; // 1=角色 2=机体 3=组织
  final MonoImages images;
  final String summary;
  final int comments;
  final int collects;
  final List<Subject> subjects; // 出演条目
  final List<MonoInfo> info;

  const Character({
    this.id = 0,
    this.url = '',
    this.name = '',
    this.nameCn = '',
    this.type = 1,
    this.images = const MonoImages(),
    this.summary = '',
    this.comments = 0,
    this.collects = 0,
    this.subjects = const [],
    this.info = const [],
  });

  factory Character.fromJson(Map<String, dynamic> json) => Character(
    id: (json['id'] as num?)?.toInt() ?? 0,
    url: json['url'] as String? ?? '',
    name: json['name'] as String? ?? '',
    nameCn: json['name_cn'] as String? ?? '',
    type: (json['type'] as num?)?.toInt() ?? 1,
    images: MonoImages.fromJson(
      json['images'] as Map<String, dynamic>? ?? const {},
    ),
    summary: json['summary'] as String? ?? '',
    comments: (json['comments'] as num?)?.toInt() ?? 0,
    collects: (json['collects'] as num?)?.toInt() ?? 0,
    subjects:
        (json['subjects'] as List?)
            ?.map((e) => Subject.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    info:
        (json['info'] as List?)
            ?.map((e) => MonoInfo.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );

  String get displayName => cnjp(name, nameCn);
}

/// 人物 (现实)
class Person {
  final int id;
  final String url;
  final String name;
  final String nameCn;
  final int type; // 1=个人 2=公司
  final MonoImages images;
  final String summary;
  final int comments;
  final int collects;
  final List<String> career; // 职业
  final List<Subject> subjects;
  final List<MonoInfo> info;

  const Person({
    this.id = 0,
    this.url = '',
    this.name = '',
    this.nameCn = '',
    this.type = 1,
    this.images = const MonoImages(),
    this.summary = '',
    this.comments = 0,
    this.collects = 0,
    this.career = const [],
    this.subjects = const [],
    this.info = const [],
  });

  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: (json['id'] as num?)?.toInt() ?? 0,
    url: json['url'] as String? ?? '',
    name: json['name'] as String? ?? '',
    nameCn: json['name_cn'] as String? ?? '',
    type: (json['type'] as num?)?.toInt() ?? 1,
    images: MonoImages.fromJson(
      json['images'] as Map<String, dynamic>? ?? const {},
    ),
    summary: json['summary'] as String? ?? '',
    comments: (json['comments'] as num?)?.toInt() ?? 0,
    collects: (json['collects'] as num?)?.toInt() ?? 0,
    career:
        (json['career'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    subjects:
        (json['subjects'] as List?)
            ?.map((e) => Subject.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    info:
        (json['info'] as List?)
            ?.map((e) => MonoInfo.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );

  String get displayName => cnjp(name, nameCn);
}

class MonoInfo {
  final String key;
  final String value;

  const MonoInfo({this.key = '', this.value = ''});

  factory MonoInfo.fromJson(Map<String, dynamic> json) => MonoInfo(
    key: json['key'] as String? ?? '',
    value: json['value']?.toString() ?? '',
  );
}
