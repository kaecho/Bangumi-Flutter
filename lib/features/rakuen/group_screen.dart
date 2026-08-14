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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(quit ? '已退出小组' : '已加入小组')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(quit ? '退出失败' : '加入失败, 请稍后重试')));
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
      appBar: AppBar(
        title: Text(
          infoAsync.valueOrNull?.title.isNotEmpty == true
              ? infoAsync.valueOrNull!.title
              : widget.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: '添加新讨论',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(
              '/web/${Uri.encodeComponent(htmlNewTopic(group: widget.name))}',
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (v) {
              if (v == 'browser') {
                openExternalUrl(htmlGroupPage(widget.name));
                return;
              }
              if (v == 'members') {
                openExternalUrl(htmlGroupMembers(widget.name));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'browser', child: Text('浏览器查看')),

              PopupMenuItem(value: 'members', child: Text('小组成员')),
            ],
          ),
        ],

        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '讨论'),
            Tab(text: '成员'),
          ],
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
                  if (info.joinUrl.isNotEmpty || info.byeUrl.isNotEmpty)
                    FilledButton(
                      onPressed: _joining
                          ? null
                          : () => _joinOrBye(info, quit: info.joined),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: _joining
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(info.joined ? '退出' : '加入'),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ForumTab(name: widget.name, scrollController: _forumScroll),
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

  const _ForumTab({required this.name, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupForumProvider(name));
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('加载失败'),
            TextButton(
              onPressed: () => ref.invalidate(groupForumProvider(name)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (data) {
        if (data.items.isEmpty) {
          return const Center(child: Text('暂无帖子'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(groupForumProvider(name)),
          child: ListView.separated(
            controller: scrollController,
            itemCount: data.items.length + (data.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(indent: 56),
            itemBuilder: (context, index) {
              if (index >= data.items.length) {
                return Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.read(groupForumProvider(name).notifier).loadMore(),
                    child: const Text('加载更多'),
                  ),
                );
              }
              return RakuenTopicRow(topic: data.items[index], showGroup: false);
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
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('加载失败'),
            TextButton(
              onPressed: () => ref.invalidate(groupMembersProvider(name)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
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
