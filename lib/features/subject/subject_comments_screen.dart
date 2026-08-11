import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';
import 'subject_models.dart';
import 'subject_providers.dart';

/// 条目吐槽箱 (分页)
/// 路由: /subject/:id/comments
class SubjectCommentsScreen extends ConsumerStatefulWidget {
  final int id;

  const SubjectCommentsScreen({super.key, required this.id});

  @override
  ConsumerState<SubjectCommentsScreen> createState() => _SubjectCommentsScreenState();
}

class _SubjectCommentsScreenState extends ConsumerState<SubjectCommentsScreen> {
  int _page = 1;
  final List<SubjectCommentItem> _items = [];
  int _pageTotal = 1;
  bool _loadingMore = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final page = await ref.read(subjectCommentsProvider((id: widget.id, page: _page)).future);
    if (!mounted) return;
    setState(() {
      _items.addAll(page.items);
      _pageTotal = page.pageTotal;
      _loaded = true;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _pageTotal) return;
    setState(() => _loadingMore = true);
    _page++;
    await _load();
    if (mounted) setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(subjectCommentsProvider((id: widget.id, page: _page)));
    return Scaffold(
      appBar: BgmAppBar(title: '吐槽箱', showBackButton: true),
      body: !_loaded
          ? async.when(
              loading: () => const Loading(text: '加载中...'),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 8),
                    const Text('加载失败'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        ref.invalidate(subjectCommentsProvider((id: widget.id, page: _page)));
                        _load();
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
              data: (_) => const SizedBox.shrink(),
            )
          : _items.isEmpty
              ? const Empty(text: '暂无吐槽', icon: Icons.chat_bubble_outline)
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) _loadMore();
                    return false;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _items.length + (_page < _pageTotal ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= _items.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: _loadingMore
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : TextButton(
                                    onPressed: _loadMore,
                                    child: const Text('加载更多'),
                                  ),
                          ),
                        );
                      }
                      return _CommentTile(comment: _items[i]);
                    },
                  ),
                ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final SubjectCommentItem comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(url: comment.avatar, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.userName,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (comment.star > 0) ...[
                      const SizedBox(width: 4),
                      Stars(score: comment.star.toDouble(), size: 9),
                    ],
                    if (comment.action.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        comment.action,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (comment.time.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        comment.time,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.content, style: const TextStyle(fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
