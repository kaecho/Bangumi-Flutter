import 'subject.dart';
import 'user.dart';

/// 收藏状态: 1=想看 2=看过 3=在看 4=搁置 5=抛弃
class CollectionStatus {
  static const int wish = 1;
  static const int collect = 2;
  static const int doing = 3;
  static const int onHold = 4;
  static const int dropped = 5;

  static String text(int status) => switch (status) {
    wish => '想看',
    collect => '看过',
    doing => '在看',
    onHold => '搁置',
    dropped => '抛弃',
    _ => '',
  };

  static String actionText(int status) => switch (status) {
    wish => '想看',
    collect => '看过',
    doing => '在看',
    onHold => '搁置',
    dropped => '抛弃',
    _ => '收藏',
  };
}

/// 条目类型: anime | book | real | game | music
class SubjectType {
  static const String anime = 'anime';
  static const String book = 'book';
  static const String real = 'real';
  static const String game = 'game';
  static const String music = 'music';

  static const List<String> all = [anime, book, real, game, music];

  static String text(String type) => switch (type) {
    anime => '动画',
    book => '书籍',
    real => '三次元',
    game => '游戏',
    music => '音乐',
    _ => type,
  };

  static String fromApiName(String name) => switch (name) {
    '动画' || 'anime' || '2' => anime,
    '书籍' || 'book' || '1' => book,
    '音乐' || 'music' || '3' => music,
    '游戏' || 'game' || '4' => game,
    '三次元' || 'real' || '6' => real,
    _ => name,
  };

  static String pluralText(String type) => switch (type) {
    anime => '番组',
    book => '书籍',
    real => '三次元',
    game => '游戏',
    music => '音乐',
    _ => type,
  };

  /// 原项目 $.action: 看 / 读 / 玩 / 听
  static String action(String type) => switch (type) {
    book => '读',
    game => '玩',
    music => '听',
    _ => '看',
  };

  static String statusText(int status, [String type = anime]) {
    return CollectionStatus.text(status).replaceAll('看', action(type));
  }
}

/// 用户对单个条目的收藏 (列表项)
class CollectionItem {
  final Subject subject;
  final int subjectId;
  final String subjectType;
  final int rate; // 个人评分 0-10
  final int type; // CollectionStatus
  final String comment;
  final List<String> tags;
  final int epStatus;
  final int volStatus;
  final String updatedAt;
  final String tip;

  const CollectionItem({
    required this.subject,
    this.subjectId = 0,
    this.subjectType = 'anime',
    this.rate = 0,
    this.type = 0,
    this.comment = '',
    this.tags = const [],
    this.epStatus = 0,
    this.volStatus = 0,
    this.updatedAt = '',
    this.tip = '',
  });

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    final subjectRaw = json['subject'] as Map<String, dynamic>?;
    return CollectionItem(
      subject: subjectRaw != null
          ? Subject.fromJson(subjectRaw)
          : Subject(
              id: (json['subject_id'] as num?)?.toInt() ?? 0,
              images: const SubjectImages(),
            ),
      subjectId: (json['subject_id'] as num?)?.toInt() ?? 0,
      // v0 API 返回数字类型 (1=book 2=anime 3=music 4=game 6=real), 旧版返回字符串
      subjectType: switch (json['subject_type']) {
        final String s => s,
        final num n =>
          const {1: 'book', 2: 'anime', 3: 'music', 4: 'game', 6: 'real'}[n
                  .toInt()] ??
              'anime',
        _ => 'anime',
      },
      rate: (json['rate'] as num?)?.toInt() ?? 0,
      type: (json['type'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String? ?? '',
      tags:
          (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      epStatus: (json['ep_status'] as num?)?.toInt() ?? 0,
      volStatus: (json['vol_status'] as num?)?.toInt() ?? 0,
      updatedAt: json['updated_at'] as String? ?? '',
      tip: json['tip'] as String? ?? '',
    );
  }
}

/// 用户收藏 API 返回: { total, limit, offset, data: [CollectionItem] }
class UserCollection {
  final int total;
  final int limit;
  final int offset;
  final List<CollectionItem> data;

  const UserCollection({
    this.total = 0,
    this.limit = 30,
    this.offset = 0,
    this.data = const [],
  });

  factory UserCollection.fromJson(Map<String, dynamic> json) => UserCollection(
    total: (json['total'] as num?)?.toInt() ?? 0,
    limit: (json['limit'] as num?)?.toInt() ?? 30,
    offset: (json['offset'] as num?)?.toInt() ?? 0,
    data:
        (json['data'] as List?)
            ?.map((e) => CollectionItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

/// 用户对单一条目的收藏 (v0)
class UserSubjectCollection {
  final int subjectId;
  final int rate;
  final int type;
  final String comment;
  final List<String> tags;
  final int epStatus;
  final int volStatus;
  final String updatedAt;
  final User? user;
  final Subject? subject;

  const UserSubjectCollection({
    this.subjectId = 0,
    this.rate = 0,
    this.type = 0,
    this.comment = '',
    this.tags = const [],
    this.epStatus = 0,
    this.volStatus = 0,
    this.updatedAt = '',
    this.user,
    this.subject,
  });

  factory UserSubjectCollection.fromJson(Map<String, dynamic> json) =>
      UserSubjectCollection(
        subjectId: (json['subject_id'] as num?)?.toInt() ?? 0,
        rate: (json['rate'] as num?)?.toInt() ?? 0,
        type: (json['type'] as num?)?.toInt() ?? 0,
        comment: json['comment'] as String? ?? '',
        tags:
            (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        epStatus: (json['ep_status'] as num?)?.toInt() ?? 0,
        volStatus: (json['vol_status'] as num?)?.toInt() ?? 0,
        updatedAt: json['updated_at'] as String? ?? '',
        user: json['user'] == null
            ? null
            : User.fromJson(json['user'] as Map<String, dynamic>),
        subject: json['subject'] == null
            ? null
            : Subject.fromJson(json['subject'] as Map<String, dynamic>),
      );
}

/// 收藏统计: { anime: {wish, collect, doing, on_hold, dropped}, book: {...}, ... }
class CollectionStats {
  final Map<String, Map<int, int>> byType;

  const CollectionStats({this.byType = const {}});

  factory CollectionStats.fromJson(Object? json) {
    if (json is List) return CollectionStats.fromStatusList(json);
    if (json is Map<String, dynamic>) {
      final map = <String, Map<int, int>>{};
      json.forEach((type, value) {
        if (value is! Map) return;
        final raw = Map<String, dynamic>.from(value);
        map[SubjectType.fromApiName(type)] = {
          1: (raw['wish'] as num?)?.toInt() ?? 0,
          2: (raw['collect'] as num?)?.toInt() ?? 0,
          3: (raw['doing'] as num?)?.toInt() ?? 0,
          4: (raw['on_hold'] as num?)?.toInt() ?? 0,
          5: (raw['dropped'] as num?)?.toInt() ?? 0,
        };
      });
      return CollectionStats(byType: map);
    }
    return const CollectionStats();
  }

  /// 旧版 /user/{uid}/collections/status 数组
  factory CollectionStats.fromStatusList(List<dynamic> data) {
    final byType = <String, Map<int, int>>{};
    for (final raw in data) {
      if (raw is! Map) continue;
      final entry = Map<String, dynamic>.from(raw);
      final name = SubjectType.fromApiName(entry['name'] as String? ?? '');
      final counts = <int, int>{};
      for (final collect in entry['collects'] as List? ?? const []) {
        if (collect is! Map) continue;
        final c = Map<String, dynamic>.from(collect);
        final status =
            (c['status'] as Map<String, dynamic>? ?? const {})['id'] as num?;
        if (status != null) {
          counts[status.toInt()] = (c['count'] as num?)?.toInt() ?? 0;
        }
      }
      if (name.isNotEmpty) byType[name] = counts;
    }
    return CollectionStats(byType: byType);
  }

  int count(String type, int status) => byType[type]?[status] ?? 0;

  int total(String type) {
    final m = byType[type];
    if (m == null) return 0;
    return m.values.fold<int>(0, (a, b) => a + b);
  }
}

/// 条目章节收藏状态 (v0: /v0/users/-/collections/:sid/episodes)
class EpCollectionStatus {
  final int epId;
  final int status; // 0=未看 1=看过

  const EpCollectionStatus({this.epId = 0, this.status = 0});

  factory EpCollectionStatus.fromJson(Map<String, dynamic> json) =>
      EpCollectionStatus(
        epId: (json['ep_id'] as num?)?.toInt() ?? 0,
        status: (json['status'] as num?)?.toInt() ?? 0,
      );
}
