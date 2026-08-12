import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/utils/format.dart';
import '../../shared/models/timeline.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../design_system/design_system.dart';

/// 时间线类型 (移植自原项目 MODEL_TIMELINE_TYPE)
const kTimelineTabs = [
  ('全部', 'all'),
  ('吐槽', 'say'),
  ('收藏', 'subject'),
  ('进度', 'progress'),
  ('日志', 'blog'),
  ('人物', 'mono'),
  ('好友', 'relation'),
  ('小组', 'group'),
  ('维基', 'wiki'),
  ('目录', 'index'),
];

/// 时间线数据
class TimelineData {
  final List<TimelineItem> items;
  final int page;
  final bool hasMore;

  const TimelineData({this.items = const [], this.page = 1, this.hasMore = true});
}

final timelineProvider =
    AsyncNotifierProvider.family<TimelineNotifier, TimelineData, String>(TimelineNotifier.new);

class TimelineNotifier extends FamilyAsyncNotifier<TimelineData, String> {
  @override
  Future<TimelineData> build(String type) async {
    return _fetch(1, type);
  }

  Future<TimelineData> _fetch(int page, String type) async {
    final client = ref.read(apiClientProvider);
    final path = type == 'all' ? apiTimeline() : apiTimelineType(type, page: page);
    final data = await client.get(path, query: type == 'all' ? {'page': page} : null);
    final items = (data as List)
        .map((e) => TimelineItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return TimelineData(items: items, page: page, hasMore: items.length >= 30);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(current.page + 1, arg);
      state = AsyncData(TimelineData(
        items: [...current.items, ...next.items],
        page: next.page,
        hasMore: next.hasMore,
      ));
    } catch (_) {}
  }
}

/// 时间线 Tab (Tab 2)
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: kTimelineTabs.length, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = ref.watch(isLoggedInProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('时间线'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final t in kTimelineTabs) Tab(text: t.$1)],
        ),
      ),
      body: isLogin
          ? TabBarView(
              controller: _tabController,
              children: [
                for (final t in kTimelineTabs) _TimelineList(type: t.$2),
              ],
            )
          : const _TimelineLoginGate(),
    );
  }
}

class _TimelineList extends ConsumerStatefulWidget {
  final String type;

  const _TimelineList({required this.type});

  @override
  ConsumerState<_TimelineList> createState() => _TimelineListState();
}

class _TimelineListState extends ConsumerState<_TimelineList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(timelineProvider(widget.type).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(timelineProvider(widget.type));
    return async.when(
      loading: () => const Loading(),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            TextButton(
              onPressed: () => ref.invalidate(timelineProvider(widget.type)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (data) {
        if (data.items.isEmpty) {
          return const Center(child: Text('暂无动态'));
        }
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: data.items.length,
          itemBuilder: (context, index) {
            final item = data.items[index];
            return _TimelineItemView(item: item);
          },
        );
      },
    );
  }
}

class _TimelineItemView extends StatelessWidget {
  final TimelineItem item;

  const _TimelineItemView({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = item.user;
    return InkWell(
      onTap: () {
        final sid = item.subject?.id;
        if (sid != null && sid > 0) {
          context.push('/subject/$sid');
        } else if (user != null) {
          context.push('/user/${user.username}');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user != null)
              Avatar(
                url: user.avatarUrl,
                size: 36,
                name: user.displayName,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (user != null)
                        Text(
                          user.displayName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _statusText(item),
                          style: context.ds.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        friendlyTime(item.createdAt),
                        style: context.ds.tiny,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (item.subject != null)
                    Row(
                      children: [
                        Cover(
                          url: item.subject!.images.common,
                          width: 48,
                          height: 64,
                          radius: 4,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.subject!.displayName,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.subject!.rating != null && item.subject!.rating!.score > 0)
                                Text(
                                  '${item.subject!.rating!.score}分',
                                  style: TextStyle(fontSize: 11, color: context.ds.star),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  if (item.status?.text != null && item.status!.text.isNotEmpty)
                    Text(
                      item.status!.text,
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                    ),
                  if (item.content.isNotEmpty)
                    Text(
                      stripHtml(item.content),
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(TimelineItem item) {
    final s = item.status;
    if (s == null || s.text.isEmpty) {
      return switch (item.type) {
        'say' => '发表了吐槽',
        'blog' => '发表了日志',
        'mono' => '更新了人物',
        'group' => '更新了小组',
        'wiki' => '更新了维基',
        'index' => '更新了目录',
        _ => '更新了动态',
      };
    }
    return s.text;
  }
}

class _TimelineLoginGate extends ConsumerWidget {
  const _TimelineLoginGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 48, color: context.ds.textHint),
          const SizedBox(height: 12),
          const Text('登录后查看时间线'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('登录'),
          ),
        ],
      ),
    );
  }
}
