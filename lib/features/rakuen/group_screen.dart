import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';

import 'html_parse.dart';
import 'rakuen_providers.dart';
import 'widgets/topic_row.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';

/// 原版小组 Header DATA: 浏览器查看 / 小组成员 / 加入或退出 / 时间格式
List<(String, String)> groupMoreItems({
  required bool joined,
  required bool canJoin,
  required bool canQuit,
  required bool lastDate,
}) => [
  ('browser', '浏览器查看'),
  ('members', '小组成员'),
  if (!joined && canJoin) ('join', '加入小组'),
  if (joined && canQuit) ('quit', '退出小组'),
  ('time', '时间格式〔${lastDate ? '最近' : '日期'}〕'),
];

/// 小组 (小组信息 + 讨论/成员)
/// 路由: /rakuen/group/:name
class GroupScreen extends ConsumerStatefulWidget {
  final String name;

  const GroupScreen({super.key, required this.name});

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _forumScroll = ScrollController();
  bool _joining = false;
  bool _lastDate = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _forumScroll.addListener(() {
      if (_forumScroll.position.pixels >=
          _forumScroll.position.maxScrollExtent - 200) {
        ref.read(groupForumProvider(widget.name).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _forumScroll.dispose();
    super.dispose();
  }

  Future<void> _joinOrBye(GroupInfoData info, {required bool quit}) async {
    if (!ref.read(isLoggedInProvider)) {
      await context.push('/login');
      return;
    }
    final href = quit ? info.byeUrl : info.joinUrl;
    if (href.isEmpty) return;
    setState(() => _joining = true);
    try {
      final client = ref.read(apiClientProvider);
      var url = href;
      if (url.startsWith('/')) url = '$kHost$url';
      await client.post(url, data: {'action': 'join-bye'}, host: kHost);
      ref.invalidate(groupInfoProvider(widget.name));
      if (mounted) {
        showBgmToast(context, quit ? '已退出小组' : '已加入小组');
      }
    } catch (e) {
      if (mounted) {
        showBgmToast(context, quit ? '退出失败' : '加入失败, 请稍后重试');
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final infoAsync = ref.watch(groupInfoProvider(widget.name));

    return Scaffold(
      appBar: BgmAppBar(
        title: infoAsync.valueOrNull?.title.isNotEmpty == true
            ? infoAsync.valueOrNull!.title
            : widget.name,
        actions: [
          BgmHeaderAction(
            tooltip: '添加新讨论',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(
              '/web/${Uri.encodeComponent(htmlNewTopic(group: widget.name))}',
            ),
          ),
          BgmHeaderMore(
            items: groupMoreItems(
              joined: infoAsync.valueOrNull?.joined == true,
              canJoin: infoAsync.valueOrNull?.joinUrl.isNotEmpty == true,
              canQuit: infoAsync.valueOrNull?.byeUrl.isNotEmpty == true,
              lastDate: _lastDate,
            ),
            onSelected: (v) {
              final info = infoAsync.valueOrNull;
              if (v == 'browser') {
                openExternalUrl(htmlGroupPage(widget.name));
                return;
              }
              if (v == 'members') {
                openExternalUrl(htmlGroupMembers(widget.name));
                return;
              }
              if (v == 'join' && info != null) {
                if (!_joining) unawaited(_joinOrBye(info, quit: false));
                return;
              }
              if (v == 'quit' && info != null) {
                if (!_joining) unawaited(_joinOrBye(info, quit: true));
                return;
              }

              if (v == 'time') {
                setState(() => _lastDate = !_lastDate);
              }
            },
          ),
        ],
        bottom: BgmControlledTabStrip(
          controller: _tabController,
          tabs: const [Text('讨论'), Text('成员')],
        ),
      ),
      body: Column(
        children: [
          infoAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: Loading(height: 48),
            ),
            error: (e, _) => const SizedBox.shrink(),
            data: (info) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: theme.colorScheme.surface,
              child: Row(
                children: [
                  Cover(
                    url: info.icon,
                    width: 44,
                    height: 44,
                    radius: 22,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.title.isEmpty ? widget.name : info.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (info.members > 0)
                          Text('${info.members} 位成员', style: context.ds.meta),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const BgmHairline(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ForumTab(
                  name: widget.name,
                  scrollController: _forumScroll,
                  lastDate: _lastDate,
                ),

                _MembersTab(name: widget.name),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForumTab extends ConsumerWidget {
  final String name;
  final ScrollController scrollController;
  final bool lastDate;

  const _ForumTab({
    required this.name,
    required this.scrollController,
    required this.lastDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupForumProvider(name));
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (e, _) =>
          BgmRetry(onRetry: () => ref.invalidate(groupForumProvider(name))),
      data: (data) {
        if (data.items.isEmpty) {
          return const Center(child: Text('暂无帖子'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(groupForumProvider(name)),
          child: ListView.separated(
            controller: scrollController,
            itemCount: data.items.length + (data.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const BgmHairline(indent: 56),
            itemBuilder: (context, index) {
              if (index >= data.items.length) {
                return Center(
                  child: BgmTextAction(
                    '加载更多',
                    onPressed: () =>
                        ref.read(groupForumProvider(name).notifier).loadMore(),
                  ),
                );
              }
              return RakuenTopicRow(
                topic: data.items[index],
                showGroup: false,
                lastDate: lastDate,
              );
            },
          ),
        );
      },
    );
  }
}

class _MembersTab extends ConsumerWidget {
  final String name;

  const _MembersTab({required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupMembersProvider(name));
    final theme = Theme.of(context);
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (e, _) =>
          BgmRetry(onRetry: () => ref.invalidate(groupMembersProvider(name))),
      data: (members) {
        if (members.isEmpty) {
          return const Center(child: Text('暂无成员'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(groupMembersProvider(name)),
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return InkWell(
                onTap: () {
                  if (member.userId.isNotEmpty) {
                    context.push('/user/${member.userId}');
                  }
                },
                child: Column(
                  children: [
                    Avatar(url: member.avatar, size: 52, name: member.userName),
                    const SizedBox(height: 6),
                    Text(
                      member.userName,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
