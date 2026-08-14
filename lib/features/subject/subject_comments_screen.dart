import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';

import '../../shared/widgets/app_bar.dart';

import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';
import 'subject_models.dart';
import 'subject_providers.dart';
import '../../shared/models/collection.dart';

const _kStatusFilters = [
  ('全部', ''),
  ('想看', 'wishes'),
  ('看过', 'collections'),
  ('在看', 'doings'),
  ('搁置', 'on_hold'),
  ('抛弃', 'dropped'),
];

List<(String, String)> _typedStatusFilters(String type) => [
  for (final item in _kStatusFilters)
    (
      item.$2.isEmpty
          ? item.$1
          : item.$1.replaceAll('看', SubjectType.action(type)),
      item.$2,
    ),
];

const _kScoreFilters = ['全部', '9-10', '7-8', '4-6', '1-3'];

/// 条目吐槽箱 (分页)
/// 路由: /subject/:id/comments
class SubjectCommentsScreen extends ConsumerStatefulWidget {
  final int id;

  const SubjectCommentsScreen({super.key, required this.id});

  @override
  ConsumerState<SubjectCommentsScreen> createState() =>
      _SubjectCommentsScreenState();
}

class _SubjectCommentsScreenState extends ConsumerState<SubjectCommentsScreen> {
  int _page = 1;
  final List<SubjectCommentItem> _items = [];
  int _pageTotal = 1;
  bool _loadingMore = false;
  bool _loaded = false;
  bool _hasVersion = false;
  String _interestType = '';
  bool _version = false;
  String _score = '全部';

  ({int id, int page, String interestType, bool version}) get _query => (
    id: widget.id,
    page: _page,
    interestType: _interestType,
    version: _version,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _items.clear();
      _loaded = false;
    }
    try {
      final page = await ref.read(subjectCommentsProvider(_query).future);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _pageTotal = page.pageTotal;
        _hasVersion = page.hasVersion || _hasVersion;
        _loaded = true;
      });
    } catch (_) {
      // 保持 _loaded=false, 由 watch 的 error 分支展示重试
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _pageTotal) return;
    setState(() => _loadingMore = true);
    _page++;
    await _load();
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _applyServerFilter() async {
    ref.invalidate(subjectCommentsProvider);
    await _load(reset: true);
  }

  List<SubjectCommentItem> get _visible {
    if (_score == '全部') return _items;
    final parts = _score.split('-');
    if (parts.length != 2) return _items;
    final lo = int.tryParse(parts[0]) ?? 0;
    final hi = int.tryParse(parts[1]) ?? 10;
    return [
      for (final item in _items)
        if (item.star >= lo && item.star <= hi) item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(subjectCommentsProvider(_query));
    final visible = _visible;
    final theme = Theme.of(context);
    final subjectType =
        ref.watch(subjectDetailProvider(widget.id)).valueOrNull?.subject.type ??
        'anime';
    final statusFilters = _typedStatusFilters(subjectType);
    return Scaffold(
      appBar: BgmAppBar(
        title: '吐槽箱',
        showBackButton: true,
        actions: [
          PopupMenuButton<String>(
            tooltip: _interestType.isEmpty
                ? '筛选收藏状态'
                : statusFilters
                      .firstWhere(
                        (e) => e.$2 == _interestType,
                        orElse: () => ('全部', ''),
                      )
                      .$1,
            icon: Icon(
              Icons.filter_list,
              color: _interestType.isEmpty ? null : theme.colorScheme.primary,
            ),
            onSelected: (v) {
              if (v == _interestType) return;
              setState(() => _interestType = v);
              _applyServerFilter();
            },
            itemBuilder: (_) => [
              for (final s in statusFilters)
                PopupMenuItem(value: s.$2, child: Text(s.$1)),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: _score == '全部' ? '筛选评分' : _score,
            icon: Icon(
              Icons.menu,
              color: _score == '全部' ? null : theme.colorScheme.primary,
            ),
            onSelected: (v) => setState(() => _score = v),
            itemBuilder: (_) => [
              for (final s in _kScoreFilters)
                PopupMenuItem(value: s, child: Text(s)),
            ],
          ),
          if (_hasVersion)
            TextButton(
              onPressed: () {
                setState(() => _version = !_version);
                _applyServerFilter();
              },
              child: Text(
                _version ? '当前版本' : '全部版本',
                style: TextStyle(
                  color: _version ? theme.colorScheme.primary : null,
                ),
              ),
            ),
          IconButton(
            tooltip: '浏览器查看',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => openExternalUrl(
              htmlSubjectComments(
                widget.id,
                interestType: _interestType,
                version: _version,
              ),
            ),
          ),
        ],
      ),
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
                        ref.invalidate(subjectCommentsProvider(_query));
                        _load(reset: true);
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
              data: (_) => const SizedBox.shrink(),
            )
          : visible.isEmpty
          ? const Empty(text: '暂无吐槽', icon: Icons.chat_bubble_outline)
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                  _loadMore();
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: visible.length + (_page < _pageTotal ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= visible.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: _loadingMore
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : TextButton(
                                onPressed: _loadMore,
                                child: const Text('加载更多'),
                              ),
                      ),
                    );
                  }
                  return _CommentTile(comment: visible[i]);
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
                        displayText(comment.userName),

                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    UserAgeBadge(userId: comment.userId),
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
                Text(
                  displayText(comment.content),

                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
