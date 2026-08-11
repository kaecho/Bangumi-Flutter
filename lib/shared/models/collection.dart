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

  static String pluralText(String type) => switch (type) {
        anime => '番组',
        book => '书籍',
        real => '三次元',
        game => '游戏',
        music => '音乐',
        _ => type,
      };
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
      subjectType: json['subject_type'] as String? ?? 'anime',
      rate: (json['rate'] as num?)?.toInt() ?? 0,
      type: (json['type'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String? ?? '',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      epStatus: (json['ep_status'] as num?)?.toInt() ?? 0,
      volStatus: (json['vol_status'] as num?)?.toInt() ?? 0,
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

/// 用户收藏 API 返回: { total, limit, offset, data: [CollectionItem] }
class UserCollection {
  final int total;
  final int limit;
  final int offset;
  final List<CollectionItem> data;

  const UserCollection({this.total = 0, this.limit = 30, this.offset = 0, this.data = const []});

  factory UserCollection.fromJson(Map<String, dynamic> json) => UserCollection(
        total: (json['total'] as num?)?.toInt() ?? 0,
        limit: (json['limit'] as num?)?.toInt() ?? 30,
        offset: (json['offset'] as num?)?.toInt() ?? 0,
        data: (json['data'] as List?)
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
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        epStatus: (json['ep_status'] as num?)?.toInt() ?? 0,
        volStatus: (json['vol_status'] as num?)?.toInt() ?? 0,
        updatedAt: json['updated_at'] as String? ?? '',
        user: json['user'] == null ? null : User.fromJson(json['user'] as Map<String, dynamic>),
        subject: json['subject'] == null
            ? null
            : Subject.fromJson(json['subject'] as Map<String, dynamic>),
      );
}

/// 收藏统计: { anime: {wish, collect, doing, on_hold, dropped}, book: {...}, ... }
class CollectionStats {
  final Map<String, Map<int, int>> byType;

  const CollectionStats({this.byType = const {}});

  factory CollectionStats.fromJson(Map<String, dynamic> json) {
    final map = <String, Map<int, int>>{};
    json.forEach((type, value) {
      final raw = value as Map<String, dynamic>? ?? const {};
      map[type] = {
        1: (raw['wish'] as num?)?.toInt() ?? 0,
        2: (raw['collect'] as num?)?.toInt() ?? 0,
        3: (raw['doing'] as num?)?.toInt() ?? 0,
        4: (raw['on_hold'] as num?)?.toInt() ?? 0,
        5: (raw['dropped'] as num?)?.toInt() ?? 0,
      };
    });
    return CollectionStats(byType: map);
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

  factory EpCollectionStatus.fromJson(Map<String, dynamic> json) => EpCollectionStatus(
        epId: (json['ep_id'] as num?)?.toInt() ?? 0,
        status: (json['status'] as num?)?.toInt() ?? 0,
      );
}
