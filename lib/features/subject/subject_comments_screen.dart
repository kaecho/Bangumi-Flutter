import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';
import '../../shared/models/collection.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';
import 'subject_models.dart';
import 'subject_providers.dart';
import 'subject_notes.dart';

const _kStatusFilters = [
  ('全部', ''),
  ('想看', 'wishes'),
  ('看过', 'collections'),
  ('在看', 'doings'),
  ('搁置', 'on_hold'),
  ('抛弃', 'dropped'),
];

List<(String, String)> typedStatusFilters(String type) => [
  for (final item in _kStatusFilters)
    (
      item.$2.isEmpty
          ? item.$1
          : item.$1.replaceAll('看', SubjectType.action(type)),
      item.$2,
    ),
];

const kCommentScoreFilters = ['全部', '9-10', '7-8', '4-6', '1-3'];

/// 倒序首次从总页-1 开始, 避开官网末页空白 (原版 fetchSubjectComments)
int commentsStartPage({required bool reverse, required int pageTotal}) {
  if (!reverse) return 1;
  return pageTotal > 1 ? pageTotal - 1 : 1;
}

int commentsNextPage({required bool reverse, required int page}) {
  return reverse ? page - 1 : page + 1;
}

bool commentsHasMore({
  required bool reverse,
  required int page,
  required int pageTotal,
}) {
  if (reverse) return page > 1;
  return page < pageTotal;
}

String subjectCommentsPath(
  int id, {
  String interestType = '',
  String score = '全部',
  bool version = false,
  bool reverse = false,
}) {
  final q = <String, String>{};
  if (interestType.isNotEmpty) q['status'] = interestType;
  if (score.isNotEmpty && score != '全部') q['score'] = score;
  if (version) q['version'] = '1';
  if (reverse) q['reverse'] = '1';
  return Uri(
    path: '/subject/$id/comments',
    queryParameters: q.isEmpty ? null : q,
  ).toString();
}

/// 条目吐槽箱 (分页)
/// 路由: /subject/:id/comments
class SubjectCommentsScreen extends ConsumerStatefulWidget {
  final int id;
  final String interestType;
  final String score;
  final bool version;
  final bool reverse;

  const SubjectCommentsScreen({
    super.key,
    required this.id,
    this.interestType = '',
    this.score = '全部',
    this.version = false,
    this.reverse = false,
  });

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
  late String _interestType = widget.interestType;
  late bool _version = widget.version;
  late String _score = widget.score;
  late bool _reverse = widget.reverse;

  ({int id, int page, String interestType, bool version}) get _query => (
    id: widget.id,
    page: _page,
    interestType: _interestType,
    version: _version,
  );

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _items.clear();
      _loaded = false;
    }
    try {
      if (reset && _reverse) {
        if (_pageTotal <= 1) {
          final probe = await ref.read(
            subjectCommentsProvider((
              id: widget.id,
              page: 1,
              interestType: _interestType,
              version: _version,
            )).future,
          );
          if (!mounted) return;
          _pageTotal = probe.pageTotal;
          _hasVersion = probe.hasVersion || _hasVersion;
        }
        _page = commentsStartPage(reverse: true, pageTotal: _pageTotal);
      } else if (reset) {
        _page = 1;
      }

      final page = await ref.read(subjectCommentsProvider(_query).future);
      if (!mounted) return;
      final items = _reverse ? page.items.reversed.toList() : page.items;
      setState(() {
        _items.addAll(items);
        _pageTotal = page.pageTotal;
        _hasVersion = page.hasVersion || _hasVersion;
        _loaded = true;
      });
    } catch (_) {
      // 保持 _loaded=false, 由 watch 的 error 分支展示重试
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore ||
        !commentsHasMore(
          reverse: _reverse,
          page: _page,
          pageTotal: _pageTotal,
        )) {
      return;
    }
    setState(() => _loadingMore = true);
    _page = commentsNextPage(reverse: _reverse, page: _page);
    await _load();
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _applyServerFilter() async {
    ref.invalidate(subjectCommentsProvider);
    _pageTotal = 1;
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

  String _statusLabel(List<(String, String)> filters) {
    return filters
        .firstWhere((e) => e.$2 == _interestType, orElse: () => ('全部', ''))
        .$1;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(subjectCommentsProvider(_query));
    final visible = _visible;
    final subjectType =
        ref.watch(subjectDetailProvider(widget.id)).valueOrNull?.subject.type ??
        'anime';
    final statusFilters = typedStatusFilters(subjectType);
    return Scaffold(
      appBar: BgmAppBar(
        title: extraNamedTitle(
          ref
              .watch(subjectDetailProvider(widget.id))
              .valueOrNull
              ?.subject
              .displayName,
          '吐槽',
          named: (n) => '$n的吐槽',
        ),

        showBackButton: true,
        actions: [
          BgmHeaderMore.browser(
            () => openExternalUrl(
              htmlSubjectComments(
                widget.id,
                interestType: _interestType,
                version: _version,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: SubjectCommentChrome(
              countLabel: _loaded ? '${_items.length}+' : '',
              hasVersion: _hasVersion,
              version: _version,
              interestType: _interestType,
              interestLabel: _statusLabel(statusFilters),
              statusFilters: statusFilters,
              score: _score,
              reverse: _reverse,
              onVersion: () {
                setState(() {
                  _version = !_version;
                  _reverse = false;
                });
                _applyServerFilter();
              },
              onStatus: (v) {
                if (v == _interestType) return;
                setState(() {
                  _interestType = v;
                  _score = '全部';
                  _reverse = false;
                });
                _applyServerFilter();
              },
              onScore: (v) => setState(() => _score = v),
              onReverse: () {
                setState(() => _reverse = !_reverse);
                _applyServerFilter();
              },
            ),
          ),
          Expanded(
            child: !_loaded
                ? async.when(
                    loading: () => const Loading(text: '加载中...'),
                    error: (e, _) => BgmRetry(
                      onRetry: () {
                        ref.invalidate(subjectCommentsProvider(_query));
                        _load(reset: true);
                      },
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
                      itemCount:
                          visible.length +
                          (commentsHasMore(
                                reverse: _reverse,
                                page: _page,
                                pageTotal: _pageTotal,
                              )
                              ? 1
                              : 0),
                      itemBuilder: (_, i) {
                        if (i >= visible.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: _loadingMore
                                  ? const BgmSpinner(size: 20)
                                  : BgmTextAction('加载更多', onPressed: _loadMore),
                            ),
                          );
                        }
                        return _CommentTile(comment: visible[i]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 原版吐槽 SectionTitle 右侧: 版本 / 收藏状态 / 分数 / 倒序
class SubjectCommentChrome extends StatelessWidget {
  final String countLabel;
  final bool hasVersion;
  final bool version;
  final String interestType;
  final String interestLabel;
  final List<(String, String)> statusFilters;
  final String score;
  final bool reverse;
  final VoidCallback? onVersion;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onScore;
  final VoidCallback onReverse;
  final Widget? extra;

  const SubjectCommentChrome({
    super.key,
    this.countLabel = '',
    required this.hasVersion,
    required this.version,
    required this.interestType,
    required this.interestLabel,
    required this.statusFilters,
    required this.score,
    required this.reverse,
    this.onVersion,
    required this.onStatus,
    required this.onScore,
    required this.onReverse,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '吐槽',
              style: ds.section,
              children: [
                if (countLabel.isNotEmpty)
                  TextSpan(
                    text: ' $countLabel',
                    style: ds.meta.copyWith(color: ds.textSecondary),
                  ),
              ],
            ),
          ),
        ),
        ?extra,

        if (hasVersion)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onVersion,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                version ? '当前版本' : '全部版本',
                style: ds.label.copyWith(
                  color: version ? ds.accent : ds.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        _CommentIconPopover(
          icon: Icons.filter_list,
          label: interestType.isEmpty ? '' : interestLabel,
          active: interestType.isNotEmpty,
          tooltip: interestType.isEmpty ? '筛选收藏状态' : interestLabel,
          options: [for (final s in statusFilters) s.$1],
          onSelected: (label) {
            final match = statusFilters.firstWhere(
              (e) => e.$1 == label,
              orElse: () => statusFilters.first,
            );
            onStatus(match.$2);
          },
        ),
        _CommentIconPopover(
          icon: Icons.menu,
          label: score == '全部' ? '' : score,
          active: score != '全部',
          tooltip: score == '全部' ? '筛选评分' : score,
          options: kCommentScoreFilters,
          onSelected: onScore,
        ),
        Tooltip(
          message: reverse ? '正序' : '倒序',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onReverse,
            child: SizedBox(
              width: 38,
              height: 38,
              child: Center(
                child: Transform.scale(
                  scaleY: reverse ? -1 : 1,
                  child: Icon(
                    Icons.swap_vert,
                    size: 22,
                    color: reverse ? ds.accent : ds.textHint,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentIconPopover extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final String tooltip;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _CommentIconPopover({
    required this.icon,
    required this.label,
    required this.active,
    required this.tooltip,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final color = active ? ds.accent : ds.textHint;
    return PopupMenuButton<String>(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final o in options) PopupMenuItem(value: o, child: Text(o)),
      ],
      child: SizedBox(
        height: 38,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  label,
                  style: ds.label.copyWith(
                    color: ds.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
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
    final ds = context.ds;
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
                        style: ds.meta.copyWith(color: ds.accent),
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
                      Text(comment.action, style: ds.tiny),
                    ],
                    if (comment.time.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(comment.time, style: ds.tiny),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  displayText(comment.content),
                  style: ds.body.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
