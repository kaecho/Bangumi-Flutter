import 'dart:async';

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
import 'user_models.dart';
import 'zone_screen.dart';

import '../../design_system/design_system.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';

/// 原版用户时间线标题: `{用户名}的时间线`
String userTimelineTitle(String? name) =>
    name == null || name.isEmpty ? '时间线' : '$name的时间线';

/// 用户时光机数据 (按日期分组 + 分页)
class UserTimelineData {
  final List<UserTimelineGroup> groups;
  final int page;
  final bool hasMore;

  const UserTimelineData({
    this.groups = const [],
    this.page = 1,
    this.hasMore = true,
  });
}

/// 用户时光机 (bgm.tv/user/{uid}/timeline, 主站 HTML)
final userTimelineProvider =
    AsyncNotifierProvider.family<
      UserTimelineNotifier,
      UserTimelineData,
      String
    >(UserTimelineNotifier.new);

class UserTimelineNotifier
    extends FamilyAsyncNotifier<UserTimelineData, String> {
  @override
  Future<UserTimelineData> build(String userId) async {
    return _fetch(1, userId);
  }

  Future<UserTimelineData> _fetch(int page, String userId) async {
    final client = ref.read(apiClientProvider);
    final html = await client.get(
      apiUserTimelineHtml(userId, page: page),
      host: kHost,
    );
    final groups = parseUserTimeline(html as String);
    final count = groups.fold<int>(0, (a, g) => a + g.items.length);
    return UserTimelineData(groups: groups, page: page, hasMore: count >= 30);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(current.page + 1, arg);
      state = AsyncData(
        UserTimelineData(
          groups: [...current.groups, ...next.groups],
          page: next.page,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {}
  }
}

/// 时光机 (用户空间独立页)
/// 我的时光机 (发现页菜单入口, 原项目 UserTimeline)
class MyUserTimelineScreen extends ConsumerWidget {
  const MyUserTimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    return me == null
        ? const Scaffold(body: Center(child: Text('请先登录')))
        : UserTimelineScreen(userId: userPathId(me));
  }
}

class UserTimelineScreen extends ConsumerWidget {
  final String userId;

  const UserTimelineScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final isMe = me != null && userPathId(me) == userId;
    final user = isMe ? me : ref.watch(zoneUserProvider(userId)).valueOrNull;
    return Scaffold(
      appBar: BgmAppBar(
        title: userTimelineTitle(user?.displayName),
        actions: [
          BgmHeaderAction(
            tooltip: '说明',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showBgmToast(context, '进度瓷砖会有延迟, 若无数据可过段时间再来');
            },
          ),
        ],
      ),

      body: UserTimelineBody(userId: userId, enablePagination: true),
    );
  }
}

/// 时光机列表 (zone tab 与独立页共用)
class UserTimelineBody extends ConsumerStatefulWidget {
  final String userId;
  final bool enablePagination;

  const UserTimelineBody({
    super.key,
    required this.userId,
    this.enablePagination = false,
  });

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
          unawaited(
            ref.read(userTimelineProvider(widget.userId).notifier).loadMore(),
          );
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
      error: (_, _) => BgmRetry(
        onRetry: () => ref.invalidate(userTimelineProvider(widget.userId)),
      ),
      data: (data) {
        if (data.groups.isEmpty) {
          return const Center(child: Text('暂无动态'));
        }
        final rows = <Widget>[];
        for (final group in data.groups) {
          rows.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
              child: Text(
                group.date,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
          for (final item in group.items) {
            rows.add(_UserTimelineRow(item: item, userId: widget.userId));
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

class _UserTimelineRow extends ConsumerWidget {
  final TimelineItem item;
  final String userId;

  const _UserTimelineRow({required this.item, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = item.subject;
    final me = ref.watch(currentUserProvider);
    final isMe =
        me != null && (userPathId(me) == userId || '${me.id}' == userId);
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
              Cover(
                url: subject.images.common,
                width: 44,
                height: 60,
                radius: 4,
              ),
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
                          style: context.ds.tiny,
                        ),
                      if (isMe && item.clearHref.isNotEmpty)
                        BgmHeaderAction(
                          tooltip: '删除',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _delete(context, ref),
                        ),
                    ],
                  ),
                  if (subject != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subject.displayName,
                      style: context.ds.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subject.rating?.score != null &&
                        subject.rating!.score > 0)
                      Text(
                        '${subject.rating!.score}分',
                        style: TextStyle(fontSize: 11, color: context.ds.star),
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

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showBgmConfirm(
      context,
      title: '删除时间线',
      message: '确定删除这条动态?',
      confirmLabel: '删除',
    );
    if (ok != true) return;
    try {
      final client = ref.read(apiClientProvider);
      var href = item.clearHref;
      if (href.startsWith('/')) href = '$kHost$href';
      if (!href.contains('ajax=1')) {
        href = href.contains('?') ? '$href&ajax=1' : '$href?ajax=1';
      }
      await client.post(href, host: kHost);
      ref.invalidate(userTimelineProvider(userId));
      if (context.mounted) {
        showBgmToast(context, '已删除');
      }
    } catch (e) {
      if (context.mounted) {
        showBgmToast(context, '删除失败: $e');
      }
    }
  }
}
