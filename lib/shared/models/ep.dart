import '../../core/utils/display.dart';
import 'user.dart';

/// 章节 (单集)
class Ep {
  final int id;
  final String url;
  final int type; // 0=本篇 1=特别篇 2=OP 3=ED 4=预告/宣传 6=SP
  final int sort;
  final String name;
  final String nameCn;
  final String duration;
  final String airdate;
  final int comment;
  final String desc;
  final int disc;

  /// 旧 API 放送状态: Air / Today / NA
  final String status;

  const Ep({
    this.id = 0,
    this.url = '',
    this.type = 0,
    this.sort = 0,
    this.name = '',
    this.nameCn = '',
    this.duration = '',
    this.airdate = '',
    this.comment = 0,
    this.desc = '',
    this.disc = 0,
    this.status = '',
  });

  factory Ep.fromJson(Map<String, dynamic> json) => Ep(
    id: (json['id'] as num?)?.toInt() ?? 0,
    url: json['url'] as String? ?? '',
    type: (json['type'] as num?)?.toInt() ?? 0,
    sort: (json['sort'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    nameCn: json['name_cn'] as String? ?? '',
    duration: json['duration'] as String? ?? '',
    airdate: json['airdate'] as String? ?? '',
    comment: (json['comment'] as num?)?.toInt() ?? 0,
    desc: json['desc'] as String? ?? '',
    disc: (json['disc'] as num?)?.toInt() ?? 0,
    status: json['status'] as String? ?? '',
  );

  String get displayName => cnjp(name, nameCn);

  /// 章节类型文案
  String get typeText => switch (type) {
    0 => '本篇',
    1 => '特别篇',
    2 => 'OP',
    3 => 'ED',
    4 => '预告/宣传',
    6 => 'SP',
    _ => '',
  };
}

/// 条目章节列表 API 返回
class EpList {
  final List<Ep> eps;
  final List<Ep> type1; // 特别篇
  final List<Ep> type2; // OP
  final List<Ep> type3; // ED
  final List<Ep> type4; // 预告
  final List<Ep> type6; // SP

  const EpList({
    this.eps = const [],
    this.type1 = const [],
    this.type2 = const [],
    this.type3 = const [],
    this.type4 = const [],
    this.type6 = const [],
  });

  factory EpList.fromJson(List<dynamic> json) {
    final all = json
        .map((e) => Ep.fromJson(e as Map<String, dynamic>))
        .toList();
    return EpList(
      eps: all.where((e) => e.type == 0).toList(),
      type1: all.where((e) => e.type == 1).toList(),
      type2: all.where((e) => e.type == 2).toList(),
      type3: all.where((e) => e.type == 3).toList(),
      type4: all.where((e) => e.type == 4).toList(),
      type6: all.where((e) => e.type == 6).toList(),
    );
  }

  int get total =>
      eps.length +
      type1.length +
      type2.length +
      type3.length +
      type4.length +
      type6.length;
}

/// 吐槽箱 / 回复
class Comment {
  final int id;
  final User? user;
  final int userId;
  final String createdAt;
  final String content;
  final List<Comment> subReplies;

  const Comment({
    this.id = 0,
    this.user,
    this.userId = 0,
    this.createdAt = '',
    this.content = '',
    this.subReplies = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: (json['id'] as num?)?.toInt() ?? 0,
    user: json['user'] == null
        ? null
        : User.fromJson(json['user'] as Map<String, dynamic>),
    userId: (json['user_id'] as num?)?.toInt() ?? 0,
    createdAt: json['created_at'] as String? ?? '',
    content: json['content'] as String? ?? '',
    subReplies:
        (json['sub_replies'] as List?)
            ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

/// 吐槽箱列表: { total, comments: [...] }
class CommentList {
  final int total;
  final List<Comment> comments;

  const CommentList({this.total = 0, this.comments = const []});

  factory CommentList.fromJson(Map<String, dynamic> json) => CommentList(
    total: (json['total'] as num?)?.toInt() ?? 0,
    comments:
        (json['comments'] as List?)
            ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}
