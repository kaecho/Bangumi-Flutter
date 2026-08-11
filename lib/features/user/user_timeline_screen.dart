import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/format.dart';
import '../../shared/models/timeline.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'user_models.dart';

/// 用户时光机数据 (按日期分组 + 分页)
class UserTimelineData {
  final List<UserTimelineGroup> groups;
  final int page;
  final bool hasMore;

  const UserTimelineData({this.groups = const [], this.page = 1, this.hasMore = true});
}

/// 用户时光机 (bgm.tv/user/{uid}/timeline, 主站 HTML)
final userTimelineProvider =
    AsyncNotifierProvider.family<UserTimelineNotifier, UserTimelineData, String>(
        UserTimelineNotifier.new);

class UserTimelineNotifier extends FamilyAsyncNotifier<UserTimelineData, String> {
  @override
  Future<UserTimelineData> build(String userId) async {
    return _fetch(1, userId);
  }

  Future<UserTimelineData> _fetch(int page, String userId) async {
    final client = ref.read(apiClientProvider);
    final html = await client.get(apiUserTimelineHtml(userId, page: page), host: kHost);
    final groups = parseUserTimeline(html as String);
    final count = groups.fold<int>(0, (a, g) => a + g.items.length);
    return UserTimelineData(groups: groups, page: page, hasMore: count >= 30);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(current.page + 1, arg);
      state = AsyncData(UserTimelineData(
        groups: [...current.groups, ...next.groups],
        page: next.page,
        hasMore: next.hasMore,
      ));
    } catch (_) {}
  }
}

/// 时光机 (用户空间独立页)
class UserTimelineScreen extends ConsumerWidget {
  final String userId;

  const UserTimelineScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('时光机')),
      body: _UserTimelineBody(userId: userId, enablePagination: true),
    );
  }
}

/// 时光机列表 (zone tab 与独立页共用)
class UserTimelineBody extends ConsumerStatefulWidget {
  final String userId;
  final bool enablePagination;

  const UserTimelineBody({super.key, required this.userId, this.enablePagination = false});

  @override
  ConsumerState<UserTimelineBody> createState() => _UserTimelineBodyState();
}

class _UserTimelineBodyState extends ConsumerState<UserTimelineBody> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.enablePagination) {
      _scroll.addListener(() {
        if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
          ref.read(userTimelineProvider(widget.userId).notifier).loadMore();
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userTimelineProvider(widget.userId));
    return async.when(
      loading: () => const Loading(),
      error: (_, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('加载失败'),
            TextButton(
              onPressed: () => ref.invalidate(userTimelineProvider(widget.userId)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (data) {
        if (data.groups.isEmpty) {
          return const Center(child: Text('暂无动态'));
        }
        final rows = <Widget>[];
        for (final group in data.groups) {
          rows.add(Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
            child: Text(
              group.date,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ));
          for (final item in group.items) {
            rows.add(_UserTimelineRow(item: item));
          }
        }
        return ListView(
          controller: _scroll,
          padding: const EdgeInsets.only(bottom: 24),
          children: rows,
        );
      },
    );
  }
}

class _UserTimelineRow extends StatelessWidget {
  final TimelineItem item;

  const _UserTimelineRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = item.subject;
    return InkWell(
      onTap: () {
        if (subject != null && subject.id > 0) {
          context.push('/subject/${subject.id}');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subject != null && subject.images.common.isNotEmpty)
              Cover(url: subject.images.common, width: 44, height: 60, radius: 4),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.content,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.createdAt.isNotEmpty)
                        Text(
                          friendlyTime(item.createdAt),
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                        ),
                    ],
                  ),
                  if (subject != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subject.displayName,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subject.rating?.score != null && subject.rating!.score > 0)
                      Text(
                        '${subject.rating!.score}分',
                        style: const TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
