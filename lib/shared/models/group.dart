import 'user.dart';

/// 小组
class Group {
  final int id;
  final String name;
  final String title;
  final String content;
  final String icon;
  final int members;
  final int created;
  final User? user;
  final int userId;

  const Group({
    this.id = 0,
    this.name = '',
    this.title = '',
    this.content = '',
    this.icon = '',
    this.members = 0,
    this.created = 0,
    this.user,
    this.userId = 0,
  });

  factory Group.fromJson(Map<String, dynamic> json) => Group(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    icon: json['icon'] as String? ?? '',
    members: (json['members'] as num?)?.toInt() ?? 0,
    created: (json['created'] as num?)?.toInt() ?? 0,
    user: json['user'] == null
        ? null
        : User.fromJson(json['user'] as Map<String, dynamic>),
    userId: (json['user_id'] as num?)?.toInt() ?? 0,
  );
}

/// 小组列表
class GroupList {
  final List<Group> list;

  const GroupList({this.list = const []});

  factory GroupList.fromJson(Map<String, dynamic> json) => GroupList(
    list:
        (json['list'] as List?)
            ?.map((e) => Group.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

/// 目录 (用户收藏目录)
class Catalog {
  final int id;
  final String title;
  final String desc;
  final int total;
  final User? user;
  final int userId;
  final String updatedAt;
  final int replies;

  const Catalog({
    this.id = 0,
    this.title = '',
    this.desc = '',
    this.total = 0,
    this.user,
    this.userId = 0,
    this.updatedAt = '',
    this.replies = 0,
  });

  factory Catalog.fromJson(Map<String, dynamic> json) => Catalog(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? '',
    desc: json['desc'] as String? ?? '',
    total: (json['total'] as num?)?.toInt() ?? 0,
    user: json['user'] == null
        ? null
        : User.fromJson(json['user'] as Map<String, dynamic>),
    userId: (json['user_id'] as num?)?.toInt() ?? 0,
    updatedAt: json['updated_at'] as String? ?? '',
    replies: (json['replies'] as num?)?.toInt() ?? 0,
  );
}

class CatalogList {
  final List<Catalog> list;

  const CatalogList({this.list = const []});

  factory CatalogList.fromJson(Map<String, dynamic> json) => CatalogList(
    list:
        (json['list'] as List?)
            ?.map((e) => Catalog.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

/// 电波提醒
class Notify {
  final int id;
  final String type;
  final String title;
  final String content;
  final String createdAt;
  final int isRead;
  final String url;
  final String avatar;

  const Notify({
    this.id = 0,
    this.type = '',
    this.title = '',
    this.content = '',
    this.createdAt = '',
    this.isRead = 0,
    this.url = '',
    this.avatar = '',
  });

  factory Notify.fromJson(Map<String, dynamic> json) => Notify(
    id: (json['id'] as num?)?.toInt() ?? 0,
    type: json['type'] as String? ?? '',
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
    isRead: (json['is_read'] as num?)?.toInt() ?? 0,
    url: json['url'] as String? ?? '',
    avatar: json['avatar'] as String? ?? '',
  );
}
