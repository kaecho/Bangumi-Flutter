import 'subject.dart';
import 'user.dart';

/// 时间线条目
class TimelineItem {
  final int id;
  final String type; // collect | say | blog | topic | ...
  final String createdAt;
  final User? user;
  final int userId;
  final Subject? subject;
  final TimelineStatus? status;
  final String content;

  const TimelineItem({
    this.id = 0,
    this.type = '',
    this.createdAt = '',
    this.user,
    this.userId = 0,
    this.subject,
    this.status,
    this.content = '',
  });

  factory TimelineItem.fromJson(Map<String, dynamic> json) => TimelineItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        type: json['type'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        user: json['user'] == null ? null : User.fromJson(json['user'] as Map<String, dynamic>),
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        subject: json['subject'] == null
            ? null
            : Subject.fromJson(json['subject'] as Map<String, dynamic>),
        status: json['status'] == null
            ? null
            : TimelineStatus.fromJson(json['status'] as Map<String, dynamic>),
        content: json['content'] as String? ?? '',
      );
}

/// 时间线状态 (收藏动作等)
class TimelineStatus {
  final int id;
  final String text;
  final String title;

  const TimelineStatus({this.id = 0, this.text = '', this.title = ''});

  factory TimelineStatus.fromJson(Map<String, dynamic> json) => TimelineStatus(
        id: (json['id'] as num?)?.toInt() ?? 0,
        text: json['text'] as String? ?? '',
        title: json['title'] as String? ?? '',
      );
}

/// 吐槽 (时间线发言)
class Say {
  final int id;
  final User? user;
  final int userId;
  final String createdAt;
  final String content;
  final List<CommentLike> likes;

  const Say({
    this.id = 0,
    this.user,
    this.userId = 0,
    this.createdAt = '',
    this.content = '',
    this.likes = const [],
  });

  factory Say.fromJson(Map<String, dynamic> json) => Say(
        id: (json['id'] as num?)?.toInt() ?? 0,
        user: json['user'] == null ? null : User.fromJson(json['user'] as Map<String, dynamic>),
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        createdAt: json['created_at'] as String? ?? '',
        content: json['content'] as String? ?? '',
        likes: (json['likes'] as List?)
                ?.map((e) => CommentLike.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class CommentLike {
  final int uid;
  final String nickname;

  const CommentLike({this.uid = 0, this.nickname = ''});

  factory CommentLike.fromJson(Map<String, dynamic> json) => CommentLike(
        uid: (json['uid'] as num?)?.toInt() ?? 0,
        nickname: json['nickname'] as String? ?? '',
      );
}

/// 每日放送: 数组按星期索引 (0=周日 ... 6=周六)
class CalendarDay {
  final int weekday;
  final String cn;
  final String ja;
  final List<Subject> items;

  const CalendarDay({this.weekday = 0, this.cn = '', this.ja = '', this.items = const []});

  factory CalendarDay.fromJson(Map<String, dynamic> json) => CalendarDay(
        weekday: (json['weekday']?['id'] as num?)?.toInt() ?? 0,
        cn: json['weekday']?['cn'] as String? ?? '',
        ja: json['weekday']?['ja'] as String? ?? '',
        items: (json['items'] as List?)
                ?.map((e) => Subject.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
