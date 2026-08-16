import 'group.dart';
import 'user.dart';

/// 帖子 (小组/条目/章节/人物 相关讨论)
class Topic {
  final int id;
  final String url;
  final String title;
  final User? user;
  final int userId;
  final Group? group;
  final int replies;
  final int commentsCount;
  final String createdAt;
  final String updatedAt;
  final String content; // 帖子详情内容 (HTML)
  final List<TopicReply> comments; // 帖子详情楼层
  final int mainId;
  final String type; // group | subject | ep | prsn | crt

  const Topic({
    this.id = 0,
    this.url = '',
    this.title = '',
    this.user,
    this.userId = 0,
    this.group,
    this.replies = 0,
    this.commentsCount = 0,
    this.createdAt = '',
    this.updatedAt = '',
    this.content = '',
    this.comments = const [],
    this.mainId = 0,
    this.type = 'group',
  });

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
    id: (json['id'] as num?)?.toInt() ?? 0,
    url: json['url'] as String? ?? '',
    title: json['title'] as String? ?? '',
    user: json['user'] == null
        ? null
        : User.fromJson(json['user'] as Map<String, dynamic>),
    userId: (json['user_id'] as num?)?.toInt() ?? 0,
    group: json['group'] == null
        ? null
        : Group.fromJson(json['group'] as Map<String, dynamic>),
    replies: (json['replies'] as num?)?.toInt() ?? 0,
    commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
    createdAt: json['created_at'] as String? ?? '',
    updatedAt: json['updated_at'] as String? ?? '',
    content: json['content'] as String? ?? '',
    comments:
        (json['comments'] as List?)
            ?.map((e) => TopicReply.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    mainId: (json['main_id'] as num?)?.toInt() ?? 0,
    type: json['type'] as String? ?? 'group',
  );

  /// 帖子跳转地址 (用于深链)
  String get topicId => '$type/$id';

  /// 展示时间: 更新时间优先
  String get displayTime => updatedAt.isNotEmpty ? updatedAt : createdAt;
}

/// 帖子楼层
class TopicReply {
  final int id;
  final User? user;
  final int userId;
  final String createdAt;
  final String content;
  final List<TopicReply> subReplies;

  const TopicReply({
    this.id = 0,
    this.user,
    this.userId = 0,
    this.createdAt = '',
    this.content = '',
    this.subReplies = const [],
  });

  factory TopicReply.fromJson(Map<String, dynamic> json) => TopicReply(
    id: (json['id'] as num?)?.toInt() ?? 0,
    user: json['user'] == null
        ? null
        : User.fromJson(json['user'] as Map<String, dynamic>),
    userId: (json['user_id'] as num?)?.toInt() ?? 0,
    createdAt: json['created_at'] as String? ?? '',
    content: json['content'] as String? ?? '',
    subReplies:
        (json['sub_replies'] as List?)
            ?.map((e) => TopicReply.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

/// 帖子列表 API 返回: { topics: [...] }
class TopicList {
  final List<Topic> topics;

  const TopicList({this.topics = const []});

  factory TopicList.fromJson(Map<String, dynamic> json) => TopicList(
    topics:
        (json['topics'] as List?)
            ?.map((e) => Topic.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

/// 用户日志
class Blog {
  final int id;
  final String url;
  final String title;
  final User? user;
  final int userId;
  final int replies;
  final String createdAt;
  final String updatedAt;
  final String summary;
  final String content; // 日志详情 (HTML)

  const Blog({
    this.id = 0,
    this.url = '',
    this.title = '',
    this.user,
    this.userId = 0,
    this.replies = 0,
    this.createdAt = '',
    this.updatedAt = '',
    this.summary = '',
    this.content = '',
  });

  factory Blog.fromJson(Map<String, dynamic> json) => Blog(
    id: (json['id'] as num?)?.toInt() ?? 0,
    url: json['url'] as String? ?? '',
    title: json['title'] as String? ?? '',
    user: json['user'] == null
        ? null
        : User.fromJson(json['user'] as Map<String, dynamic>),
    userId: (json['user_id'] as num?)?.toInt() ?? 0,
    replies: (json['replies'] as num?)?.toInt() ?? 0,
    createdAt: json['created_at'] as String? ?? '',
    updatedAt: json['updated_at'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    content: json['content'] as String? ?? '',
  );
}

/// 日志列表: { list: [...] }
class BlogList {
  final List<Blog> list;

  const BlogList({this.list = const []});

  factory BlogList.fromJson(Map<String, dynamic> json) => BlogList(
    list:
        (json['list'] as List?)
            ?.map((e) => Blog.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}
