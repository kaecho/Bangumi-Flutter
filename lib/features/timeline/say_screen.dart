import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/format.dart';
import '../../shared/models/timeline.dart';
import '../../shared/models/user.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';

/// 吐槽类型: 点赞参数 (原项目 LIKE_TYPE_SAY)
const int kLikeTypeSay = 50;

/// 吐槽评论
class SayComment {
  final int id;
  final int userId;
  final User? user;
  final String content;
  final String createdAt;
  final int likes;

  const SayComment({
    this.id = 0,
    this.userId = 0,
    this.user,
    this.content = '',
    this.createdAt = '',
    this.likes = 0,
  });

  factory SayComment.fromJson(Map<String, dynamic> json) => SayComment(
        id: (json['id'] as num?)?.toInt() ?? 0,
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        user: json['user'] == null ? null : User.fromJson(json['user'] as Map<String, dynamic>),
        content: json['content'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        likes: (json['likes'] as num?)?.toInt() ?? 0,
      );
}

/// 吐槽详情数据: 吐槽本体 + 评论列表
class SayDetail {
  final Say say;
  final List<SayComment> comments;

  const SayDetail({required this.say, this.comments = const []});
}

/// 吐槽详情 (移植自原项目 screens/timeline/say)
/// 数据: /say/{id} + /timeline/{id}/comments
final sayDetailProvider = FutureProvider.family<SayDetail, int>((ref, id) async {
  final client = ref.read(apiClientProvider);

  Say say;
  try {
    final raw = await client.get(apiSay(id));
    // /say/{id} 返回单个吐槽对象
    say = Say.fromJson(raw as Map<String, dynamic>);
  } catch (_) {
    say = Say(id: id);
  }

  List<SayComment> comments = const [];
  try {
    final raw = await client.get(apiTimelineComments(id));
    comments = (raw as List)
        .whereType<Map<String, dynamic>>()
        .map(SayComment.fromJson)
        .toList();
  } catch (_) {
    // 评论可能因权限不可用, 不阻塞页面
  }

  return SayDetail(say: say, comments: comments);
});

/// 吐槽详情页
/// 路由: /timeline/say/:id
class SayScreen extends ConsumerWidget {
  final int id;

  const SayScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(sayDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('吐槽详情')),
      body: detail.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 8),
              const Text('加载失败'),
              const SizedBox(height: 8),
              Text(apiErrorMessage(e), style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(sayDetailProvider(id)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SayHeader(say: value.say, id: id),
            const SizedBox(height: 16),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '评论 (${value.comments.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            if (value.comments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('暂无评论', style: TextStyle(fontSize: 13))),
              )
            else
              ...value.comments.map((c) => _CommentTile(comment: c)),
          ],
        ),
      ),
    );
  }
}

/// 吐槽本体 + 点赞按钮
class _SayHeader extends ConsumerStatefulWidget {
  final Say say;
  final int id;

  const _SayHeader({required this.say, required this.id});

  @override
  ConsumerState<_SayHeader> createState() => _SayHeaderState();
}

class _SayHeaderState extends ConsumerState<_SayHeader> {
  bool _liked = false;
  bool _liking = false;

  Future<void> _like() async {
    if (_liking) return;
    setState(() => _liking = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.post(apiLike(kLikeTypeSay, widget.id), host: kHost);
      if (mounted) setState(() => _liked = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('点赞失败, 请确认已登录')),
        );
      }
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final say = widget.say;
    final scheme = Theme.of(context).colorScheme;
    final user = say.user;
    final likeCount = say.likes.length + (_liked ? 1 : 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(url: user?.avatarUrl ?? '', size: 40, name: user?.displayName),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName ?? '用户${say.userId}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    friendlyTime(say.createdAt),
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '点赞',
              icon: Icon(
                _liked ? Icons.favorite : Icons.favorite_border,
                color: _liked ? scheme.primary : scheme.onSurfaceVariant,
              ),
              onPressed: _liking ? null : _like,
            ),
          ],
        ),
        if (likeCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 50, top: 4),
            child: Text(
              '$likeCount 人赞过',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 8),
        SelectableText(
          say.content,
          style: const TextStyle(fontSize: 15, height: 1.6),
        ),
      ],
    );
  }
}

/// 评论条目
class _CommentTile extends StatelessWidget {
  final SayComment comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = comment.user;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(url: user?.avatarUrl ?? '', size: 32, name: user?.displayName),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user?.displayName ?? '用户${comment.userId}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      friendlyTime(comment.createdAt),
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.content, style: const TextStyle(fontSize: 14, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
