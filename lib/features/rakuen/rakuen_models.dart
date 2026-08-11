import '../../shared/models/topic.dart';
import '../../shared/models/user.dart';

/// 分页列表数据 (帖子列表通用容器)
class RakuenListData<T> {
  final List<T> items;
  final int page;
  final bool hasMore;

  const RakuenListData({this.items = const [], this.page = 1, this.hasMore = true});
}

/// 电波提醒列表
class NotifyListData {
  final List<dynamic> items;
  final int page;
  final bool hasMore;

  const NotifyListData({this.items = const [], this.page = 1, this.hasMore = true});
}

/// 条目长评 (移植自原项目 ReviewsItem)
class Review {
  final int id;
  final String title;
  final User? user;
  final int userId;
  final String content;
  final String createdAt;
  final int replies;

  const Review({
    this.id = 0,
    this.title = '',
    this.user,
    this.userId = 0,
    this.content = '',
    this.createdAt = '',
    this.replies = 0,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        user: json['user'] == null ? null : User.fromJson(json['user'] as Map<String, dynamic>),
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        content: json['content'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        replies: (json['replies'] as num?)?.toInt() ?? 0,
      );
}

/// 条目长评列表
class ReviewListData {
  final List<Review> reviews;
  final int page;
  final bool hasMore;

  const ReviewListData({this.reviews = const [], this.page = 1, this.hasMore = true});
}

/// 浏览历史条目 (hive box 'rakuen', key 'history')
class HistoryItem {
  final String topicId;
  final String title;
  final String group;
  final String userName;
  final int replies;
  final int time;

  const HistoryItem({
    this.topicId = '',
    this.title = '',
    this.group = '',
    this.userName = '',
    this.replies = 0,
    this.time = 0,
  });

  Map<String, dynamic> toJson() => {
        'topicId': topicId,
        'title': title,
        'group': group,
        'userName': userName,
        'replies': replies,
        'time': time,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        topicId: json['topicId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        group: json['group'] as String? ?? '',
        userName: json['userName'] as String? ?? '',
        replies: (json['replies'] as num?)?.toInt() ?? 0,
        time: (json['time'] as num?)?.toInt() ?? 0,
      );
}

/// 我的数据 (主题/日志/动态)
class MineData {
  final List<Topic> topics;
  final List<Blog> blogs;
  final List<dynamic> timeline;

  const MineData({this.topics = const [], this.blogs = const [], this.timeline = const []});
}
