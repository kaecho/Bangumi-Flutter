import 'dart:math' show sqrt;

import '../../core/utils/display.dart';
import '../../shared/models/ep.dart';
import '../../shared/models/mono.dart';
import '../../shared/models/subject.dart';

/// 条目详情页聚合数据: 旧版条目信息 + v0 扩展 (infobox/tags/eps)
class SubjectDetail {
  final Subject subject;
  final List<Infobox> infobox;
  final List<Tag> tags;
  final List<SubjectListItem> eps;

  const SubjectDetail({
    required this.subject,
    this.infobox = const [],
    this.tags = const [],
    this.eps = const [],
  });

  /// 条目类型文案 (旧版 API 为数字, v0 为数字; 统一转中文)
  String get typeText => switch (subject.type) {
    'book' => '书籍',
    'anime' => '动画',
    'music' => '音乐',
    'game' => '游戏',
    'real' => '三次元',
    _ => subject.type,
  };

  /// 评分分布 (1-10 分人数)
  Map<int, int> get ratingCounts {
    final counts = subject.rating?.count ?? const <int, int>{};
    if (counts.isNotEmpty) return counts;
    return {for (var i = 1; i <= 10; i++) i: 0};
  }
}

/// v0 列表条目 (slim): typerank / works / mono 出演作品
class SubjectListItem {
  final int id;
  final String name;
  final String nameCn;
  final String date;
  final double score;
  final int rank;
  final SubjectImages images;
  final String relation; // 关系 (v0 subjects)

  const SubjectListItem({
    this.id = 0,
    this.name = '',
    this.nameCn = '',
    this.date = '',
    this.score = 0,
    this.rank = 0,
    this.images = const SubjectImages(),
    this.relation = '',
  });

  factory SubjectListItem.fromJson(Map<String, dynamic> json) =>
      SubjectListItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        nameCn: json['name_cn'] as String? ?? '',
        date: json['date'] as String? ?? '',
        score: (json['score'] as num?)?.toDouble() ?? 0,
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        images: SubjectImages.fromJson(
          json['images'] as Map<String, dynamic>? ?? const {},
        ),
        relation: json['relation'] as String? ?? '',
      );

  String get displayName => cnjp(name, nameCn);
}

/// v0 条目的角色 (含声优 actors)
class CharacterVo {
  final int id;
  final String name;
  final String nameCn;
  final String relation; // 主角 / 配角
  final MonoImages images;
  final String summary;
  final List<ActorVo> actors;

  const CharacterVo({
    this.id = 0,
    this.name = '',
    this.nameCn = '',
    this.relation = '',
    this.images = const MonoImages(),
    this.summary = '',
    this.actors = const [],
  });

  factory CharacterVo.fromJson(Map<String, dynamic> json) => CharacterVo(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    nameCn: json['name_cn'] as String? ?? '',
    relation: json['relation'] as String? ?? '',
    images: MonoImages.fromJson(
      json['images'] as Map<String, dynamic>? ?? const {},
    ),
    summary: json['summary'] as String? ?? '',
    actors:
        (json['actors'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(ActorVo.fromJson)
            .toList() ??
        const [],
  );

  String get displayName => cnjp(name, nameCn);
}

/// 声优
class ActorVo {
  final int id;
  final String name;
  final String nameCn;
  final MonoImages images;
  final List<String> career;

  const ActorVo({
    this.id = 0,
    this.name = '',
    this.nameCn = '',
    this.images = const MonoImages(),
    this.career = const [],
  });

  factory ActorVo.fromJson(Map<String, dynamic> json) => ActorVo(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    nameCn: json['name_cn'] as String? ?? '',
    images: MonoImages.fromJson(
      json['images'] as Map<String, dynamic>? ?? const {},
    ),
    career:
        (json['career'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
  );

  String get displayName => cnjp(name, nameCn);
}

/// v0 条目的制作人员
class PersonVo {
  final int id;
  final String name;
  final String nameCn;
  final String relation; // 职位
  final List<String> career;
  final MonoImages images;
  final int type;

  const PersonVo({
    this.id = 0,
    this.name = '',
    this.nameCn = '',
    this.relation = '',
    this.career = const [],
    this.images = const MonoImages(),
    this.type = 1,
  });

  factory PersonVo.fromJson(Map<String, dynamic> json) => PersonVo(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    nameCn: json['name_cn'] as String? ?? '',
    relation: json['relation'] as String? ?? '',
    career:
        (json['career'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    images: MonoImages.fromJson(
      json['images'] as Map<String, dynamic>? ?? const {},
    ),
    type: (json['type'] as num?)?.toInt() ?? 1,
  );

  String get displayName => cnjp(name, nameCn);
}

/// 角色 / 人物详情 (v0)
class MonoDetail {
  final int id;
  final String name;
  final String nameCn;
  final MonoImages images;
  final String summary;
  final List<Infobox> infobox;
  final int comments;
  final int collects;
  final List<String> career;
  final String gender;
  final String birth;
  final String bloodType;

  const MonoDetail({
    this.id = 0,
    this.name = '',
    this.nameCn = '',
    this.images = const MonoImages(),
    this.summary = '',
    this.infobox = const [],
    this.comments = 0,
    this.collects = 0,
    this.career = const [],
    this.gender = '',
    this.birth = '',
    this.bloodType = '',
  });

  factory MonoDetail.fromCharacter(Map<String, dynamic> json) {
    final stat = json['stat'] as Map<String, dynamic>? ?? const {};
    return MonoDetail(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      nameCn: json['name_cn'] as String? ?? '',
      images: MonoImages.fromJson(
        json['images'] as Map<String, dynamic>? ?? const {},
      ),
      summary: json['summary'] as String? ?? '',
      infobox:
          (json['infobox'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(Infobox.fromJson)
              .toList() ??
          const [],
      comments: (stat['comments'] as num?)?.toInt() ?? 0,
      collects: (stat['collects'] as num?)?.toInt() ?? 0,
      gender: json['gender'] as String? ?? '',
      birth: _birthOf(json),
      bloodType: json['blood_type'] as String? ?? '',
    );
  }

  factory MonoDetail.fromPerson(Map<String, dynamic> json) {
    final stat = json['stat'] as Map<String, dynamic>? ?? const {};
    return MonoDetail(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      nameCn: json['name_cn'] as String? ?? '',
      images: MonoImages.fromJson(
        json['images'] as Map<String, dynamic>? ?? const {},
      ),
      summary: json['summary'] as String? ?? '',
      infobox:
          (json['infobox'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(Infobox.fromJson)
              .toList() ??
          const [],
      comments: (stat['comments'] as num?)?.toInt() ?? 0,
      collects: (stat['collects'] as num?)?.toInt() ?? 0,
      career:
          (json['career'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      gender: json['gender'] as String? ?? '',
      birth: _birthOf(json),
      bloodType: json['blood_type'] as String? ?? '',
    );
  }

  String get displayName => cnjp(name, nameCn);

  static String _birthOf(Map<String, dynamic> json) {
    final y = (json['birth_year'] as num?)?.toInt();
    final m = (json['birth_mon'] as num?)?.toInt();
    final d = (json['birth_day'] as num?)?.toInt();
    if (y == null) return '';
    return [y, ?m, ?d].join('-');
  }
}

/// 主站 HTML 吐槽条目 (subject / ep / character 吐槽箱)
class SubjectCommentItem {
  final String id;
  final String userId;
  final String userName;
  final String avatar;
  final String time;
  final int star; // 0-10
  final String content;
  final String action; // 看过 / 在看 ...

  const SubjectCommentItem({
    this.id = '',
    this.userId = '',
    this.userName = '',
    this.avatar = '',
    this.time = '',
    this.star = 0,
    this.content = '',
    this.action = '',
  });
}

/// 吐槽分页
class CommentPage {
  final int page;
  final int pageTotal;
  final List<SubjectCommentItem> items;
  final bool hasVersion;

  const CommentPage({
    this.page = 1,
    this.pageTotal = 1,
    this.items = const [],
    this.hasVersion = false,
  });
}

/// 用户对条目的收藏详情 (旧版 /collection/{id})
class CollectionDetail {
  final int subjectId;
  final int rate; // 0-10
  final int type; // CollectionStatus
  final String comment;
  final List<String> tags;
  final int epStatus;
  final int volStatus;

  const CollectionDetail({
    this.subjectId = 0,
    this.rate = 0,
    this.type = 0,
    this.comment = '',
    this.tags = const [],
    this.epStatus = 0,
    this.volStatus = 0,
  });

  factory CollectionDetail.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as Map<String, dynamic>? ?? json;
    return CollectionDetail(
      subjectId: (json['subject_id'] as num?)?.toInt() ?? 0,
      rate: (json['rate'] as num?)?.toInt() ?? 0,
      type:
          (status['type'] as num?)?.toInt() ??
          (json['type'] as num?)?.toInt() ??
          0,
      comment: json['comment'] as String? ?? '',
      tags:
          (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      epStatus: (json['ep_status'] as num?)?.toInt() ?? 0,
      volStatus: (json['vol_status'] as num?)?.toInt() ?? 0,
    );
  }

  bool get hasCollection => type > 0;
}

/// v0 用户章节收藏状态: epId -> 是否看过 (type == 2)
class EpStatusMap {
  final Map<int, bool> watched;
  final int epStatus;

  const EpStatusMap({this.watched = const {}, this.epStatus = 0});

  bool isWatched(int epId) => watched[epId] ?? false;

  /// 已看章节数 (按 sort 顺序连续计算)
  int progressOf(List<Ep> eps) {
    if (eps.isEmpty) return epStatus;
    var count = 0;
    for (final ep in eps) {
      if (isWatched(ep.id)) {
        count++;
      }
    }
    return count > epStatus ? count : epStatus;
  }
}

/// 评分分布页数据: 1-10 分人数 + 吐槽
class RatingStats {
  final double score;
  final int total;
  final int rank;
  final Map<int, int> counts;
  final List<SubjectCommentItem> comments;

  const RatingStats({
    this.score = 0,
    this.total = 0,
    this.rank = 0,
    this.counts = const {},
    this.comments = const [],
  });

  int countOf(int score) => counts[score] ?? 0;

  /// 原项目 getDeviation / getDispute
  double get deviation {
    if (total <= 0) return 0;
    var sd = 0.0;
    for (var score = 1; score <= 10; score++) {
      final n = countOf(score);
      if (n == 0) continue;
      final d = score - this.score;
      sd += d * d * n;
    }
    return sd <= 0 ? 0 : sqrt(sd / total);
  }

  String get dispute {
    final d = deviation;
    if (d == 0) return '-';
    if (d < 1) return '异口同声';
    if (d < 1.15) return '基本一致';
    if (d < 1.3) return '略有分歧';
    if (d < 1.45) return '莫衷一是';
    if (d < 1.6) return '各执一词';
    if (d < 1.75) return '你死我活';
    return '厨黑大战';
  }
}

/// 所有人评分页 (原项目 cheerioRating)
class SubjectRatingPage {
  final int wishes;
  final int collections;
  final int doings;
  final int onHold;
  final int dropped;
  final List<SubjectCommentItem> items;

  const SubjectRatingPage({
    this.wishes = 0,
    this.collections = 0,
    this.doings = 0,
    this.onHold = 0,
    this.dropped = 0,
    this.items = const [],
  });
}

/// 目录条目 (包含该条目的目录, 主站 HTML 解析)
class CatalogItem {
  final int id;
  final String title;
  final String userName;
  final String userAvatar;
  final int collected;
  final String updatedAt;

  const CatalogItem({
    this.id = 0,
    this.title = '',
    this.userName = '',
    this.userAvatar = '',
    this.collected = 0,
    this.updatedAt = '',
  });
}

/// 维基编辑历史 (主站 HTML 解析)
class WikiEdit {
  final String time;
  final String userName;
  final String summary;
  final int rev;

  const WikiEdit({
    this.time = '',
    this.userName = '',
    this.summary = '',
    this.rev = 0,
  });
}

/// 预览截图
class PreviewImage {
  final String url;
  final String referer;

  const PreviewImage({required this.url, this.referer = ''});
}

/// 巡礼地点 (anitabi lite)
class AnitabiSpot {
  final String name;
  final String address;

  const AnitabiSpot({this.name = '', this.address = ''});
}

/// 主站条目 HTML 额外信息
class SubjectHtmlExtras {
  final String lock;
  final List<SubjectListItem> likes;
  final List<SubjectRecentUser> recent;
  final List<SubjectDisc> discs;
  final List<SubjectListItem> comics;
  final double friendScore;
  final int friendTotal;

  const SubjectHtmlExtras({
    this.lock = '',
    this.likes = const [],
    this.recent = const [],
    this.discs = const [],
    this.comics = const [],
    this.friendScore = 0,
    this.friendTotal = 0,
  });
}

/// 音乐曲目碟片 (原项目 TITLE_DISC)
class SubjectDisc {
  final String title;
  final List<SubjectDiscTrack> tracks;

  const SubjectDisc({this.title = '', this.tracks = const []});
}

class SubjectDiscTrack {
  final int epId;
  final String title;

  const SubjectDiscTrack({this.epId = 0, this.title = ''});
}

/// 条目侧栏「谁在看」 (原项目 TITLE_RECENT)
class SubjectRecentUser {
  final String userId;
  final String name;
  final String avatar;
  final int star;
  final String status;

  const SubjectRecentUser({
    this.userId = '',
    this.name = '',
    this.avatar = '',
    this.star = 0,
    this.status = '',
  });
}
