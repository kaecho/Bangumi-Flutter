import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/models/collection.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../design_system/design_system.dart';

/// 首页 Tab 类型 (与原项目 TABS_ITEM 一致)
const kProgressTabs = [
  ('全部', 'all'),
  ('动画', 'anime'),
  ('书籍', 'book'),
  ('三次元', 'real'),
  ('游戏', 'game'),
];

/// 收藏列表数据
class ProgressData {
  final List<CollectionItem> items;
  final int page;
  final bool hasMore;

  const ProgressData({this.items = const [], this.page = 1, this.hasMore = true});
}

final progressProvider = AsyncNotifierProvider.family<ProgressNotifier, ProgressData, String>(
  ProgressNotifier.new,
);

class ProgressNotifier extends FamilyAsyncNotifier<ProgressData, String> {
  @override
  Future<ProgressData> build(String type) async {
    return _fetch(1, type);
  }

  Future<ProgressData> _fetch(int page, String type) async {
    final client = ref.read(apiClientProvider);
    final me = ref.read(currentUserProvider);
    if (me == null) return const ProgressData(items: [], hasMore: false);
    final userId = me.username.isEmpty ? '${me.id}' : me.username;
    final subjectType = type == 'all' ? 'anime' : type;
    final data = await client.get(
      apiV0UsersCollections(userId, subjectType, 100, (page - 1) * 100, '3'),
    );
    final uc = UserCollection.fromJson(data as Map<String, dynamic>);

    // 全部 tab: 需合并 anime/book/real/game
    if (type == 'all') {
      final all = [...uc.data];
      for (final t in ['book', 'real', 'game']) {
        try {
          final d2 = await client.get(apiV0UsersCollections(userId, t, 100, (page - 1) * 100, '3'));
          all.addAll(UserCollection.fromJson(d2 as Map<String, dynamic>).data);
        } catch (_) {}
      }
      return ProgressData(items: all, page: page, hasMore: false);
    }
    return ProgressData(items: uc.data, page: page, hasMore: uc.data.length >= 100);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(current.page + 1, arg);
      state = AsyncData(ProgressData(
        items: [...current.items, ...next.items],
        page: next.page,
        hasMore: next.hasMore,
      ));
    } catch (_) {}
  }

  /// 看过下一话
  Future<bool> updateProgress(CollectionItem item) async {
    final client = ref.read(apiClientProvider);
    final subject = item.subject;
    if (subject.id <= 0) return false;
    try {
      await client.post(apiSubjectUpdateWatched(subject.id), data: {'watched_eps': item.epStatus + 1});
      ref.invalidate(progressProvider(arg));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 变更收藏状态
  Future<bool> changeStatus(CollectionItem item, int status) async {
    final client = ref.read(apiClientProvider);
    final subject = item.subject;
    if (subject.id <= 0) return false;
    try {
      await client.post(
        apiCollectionAction(subject.id, 'update'),
        data: {'type': status},
      );
      ref.invalidate(progressProvider(arg));
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// 首页 (Tab 3): 收藏进度管理
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: kProgressTabs.length, vsync: this);

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
        title: const Text('进度'),
        bottom: isLogin
            ? TabBar(
                controller: _tabController,
                tabs: [for (final t in kProgressTabs) Tab(text: t.$1)],
              )
            : null,
      ),
      body: isLogin
          ? TabBarView(
              controller: _tabController,
              children: [
                for (final t in kProgressTabs) _ProgressList(type: t.$2),
              ],
            )
          : const _ProgressLoginGate(),
    );
  }
}

class _ProgressList extends ConsumerStatefulWidget {
  final String type;

  const _ProgressList({required this.type});

  @override
  ConsumerState<_ProgressList> createState() => _ProgressListState();
}

class _ProgressListState extends ConsumerState<_ProgressList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(progressProvider(widget.type).notifier).loadMore();
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
    final async = ref.watch(progressProvider(widget.type));
    return async.when(
      loading: () => const Loading(),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('加载失败'),
            TextButton(
              onPressed: () => ref.invalidate(progressProvider(widget.type)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (data) {
        if (data.items.isEmpty) {
          return const Center(child: Text('还没有在看的内容, 去发现页找找吧'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(progressProvider(widget.type)),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: data.items.length,
            itemBuilder: (context, index) {
              final item = data.items[index];
              return _ProgressItemView(
                item: item,
                onNext: () => ref.read(progressProvider(widget.type).notifier).updateProgress(item),
                onStatusChanged: (status) =>
                    ref.read(progressProvider(widget.type).notifier).changeStatus(item, status),
              );
            },
          ),
        );
      },
    );
  }
}

class _ProgressItemView extends StatelessWidget {
  final CollectionItem item;
  final Future<bool> Function() onNext;
  final Future<bool> Function(int status) onStatusChanged;

  const _ProgressItemView({required this.item, required this.onNext, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    final subject = item.subject;
    final isBook = subject.type == 'book';

    return InkWell(
      onTap: () => context.push('/subject/${subject.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Cover(url: subject.images.common, width: 60, height: 80, radius: 4),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.displayName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (subject.rating != null && subject.rating!.score > 0)
                    Row(
                      children: [
                        Icon(Icons.star, size: 13, color: context.ds.star),
                        const SizedBox(width: 2),
                        Text(
                          subject.rating!.score.toStringAsFixed(1),
                          style: TextStyle(fontSize: 12, color: context.ds.star),
                        ),
                      ],
                    ),
                  const SizedBox(height: 2),
                  Text(
                    isBook
                        ? '看到第 ${item.epStatus} 话 / 共 ${subject.eps} 话'
                        : '看到第 ${item.epStatus} 话 / 共 ${subject.eps} 话',
                    style: context.ds.caption,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _StatusChip(
                        text: CollectionStatus.text(item.type),
                        onTap: () => _showStatusDialog(context),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: () async {
                          final ok = await onNext();
                          if (context.mounted && !ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('更新进度失败')),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: Text('+1 ${isBook ? '话' : '话'}', style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final status in [1, 3, 2, 4, 5])
              ListTile(
                title: Text(
                  CollectionStatus.actionText(status),
                  style: TextStyle(
                    color: status == item.type ? Theme.of(ctx).colorScheme.primary : null,
                  ),
                ),
                trailing: status == item.type ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  if (status != item.type) onStatusChanged(status);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _StatusChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: context.ds.accentSoft,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: context.ds.meta.copyWith(color: context.ds.accent),
            ),
            Icon(Icons.arrow_drop_down, size: 14, color: context.ds.accent),
          ],
        ),
      ),
    );
  }
}

class _ProgressLoginGate extends ConsumerWidget {
  const _ProgressLoginGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.manage_search, size: 48, color: context.ds.textHint),
          const SizedBox(height: 12),
          const Text('登录后管理你的追番进度'),
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
