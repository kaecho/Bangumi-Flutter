import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../core/utils/format.dart';
import '../../shared/models/group.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../user/pm_screen.dart';
import 'rakuen_providers.dart';
import '../../design_system/design_system.dart';

/// 电波提醒
/// 路由: /rakuen/notify
class NotifyScreen extends ConsumerStatefulWidget {
  const NotifyScreen({super.key});

  @override
  ConsumerState<NotifyScreen> createState() => _NotifyScreenState();
}

class _NotifyScreenState extends ConsumerState<NotifyScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(notifyProvider(1).notifier).loadMore();
      }
    });
    // 进入页面自动清除全部未读 (原项目 doClearNotify)
    _clearUnread();
  }

  /// GET /json/notify 取 notify_ignore_url 并访问, 服务端清除未读
  Future<void> _clearUnread() async {
    try {
      final client = ref.read(apiClientProvider);
      final meta = await client.get(apiNotifyMeta());
      if (meta is Map) {
        final url = meta['notify_ignore_url'] as String? ?? '';
        if (url.isNotEmpty) {
          await client.get(url.startsWith('http') ? url : '$kHost$url');
          ref.invalidate(notifyCountProvider);
        }
      }
    } catch (_) {
      // 清除失败不影响列表展示
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tab.dispose();
    super.dispose();
  }

  void _open(Notify item) {
    final url = item.url;
    final topic = RegExp(r'^/rakuen/topic/([^/]+/\d+)').firstMatch(url);
    if (topic != null) {
      context.push('/rakuen/topic/${topic.group(1)}');
      return;
    }
    final blog = RegExp(r'^/blog(?:/entry)?/(\d+)').firstMatch(url);
    if (blog != null) {
      context.push('/rakuen/blog/${blog.group(1)}');
      return;
    }
    final subject = RegExp(r'^/subject/(\d+)').firstMatch(url);
    if (subject != null) {
      context.push('/subject/${subject.group(1)}');
      return;
    }
    if (url.isNotEmpty) {
      openExternalUrl(url.startsWith('http') ? url : 'https://bgm.tv$url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadAsync = ref.watch(notifyCountProvider);
    final title =
        unreadAsync.valueOrNull != null && unreadAsync.valueOrNull! > 0
        ? '电波提醒 (${unreadAsync.valueOrNull})'
        : '电波提醒';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: '浏览器查看',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => openExternalUrl(htmlNotify()),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '提醒'),
            Tab(text: '收件箱'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(notifyProvider(1));
              return async.when(
                loading: () => const Loading(height: double.infinity),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('加载失败, 请确认已登录'),
                      TextButton(
                        onPressed: () => ref.invalidate(notifyProvider(1)),
                        child: const Text('重试'),
                      ),
                      TextButton(
                        onPressed: () => context.push('/settings/cookies'),
                        child: const Text('配置站点 Cookie'),
                      ),
                    ],
                  ),
                ),
                data: (data) {
                  if (data.items.isEmpty) {
                    return const Center(child: Text('暂时没有提醒'));
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(notifyProvider(1));
                      ref.invalidate(notifyCountProvider);
                    },
                    child: ListView.separated(
                      controller: _scrollController,
                      itemCount: data.items.length + (data.hasMore ? 1 : 0),
                      separatorBuilder: (_, _) => const Divider(indent: 56),
                      itemBuilder: (context, index) {
                        if (index >= data.items.length) {
                          return Center(
                            child: TextButton(
                              onPressed: () => ref
                                  .read(notifyProvider(1).notifier)
                                  .loadMore(),
                              child: const Text('加载更多'),
                            ),
                          );
                        }
                        final item = data.items[index] as Notify;
                        return _NotifyRow(item: item, onTap: () => _open(item));
                      },
                    ),
                  );
                },
              );
            },
          ),
          // 收件箱 (原项目 notify 收件箱 tab, 复用 PM 列表)
          const PmInbox(),
        ],
      ),
    );
  }
}

class _NotifyRow extends StatelessWidget {
  final Notify item;
  final VoidCallback onTap;

  const _NotifyRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = item.isRead == 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(url: item.avatar, size: 36, name: item.title),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isEmpty ? item.type : item.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      color: unread
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.outline,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.content.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.content,
                      style: context.ds.caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (item.createdAt.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(friendlyTime(item.createdAt), style: context.ds.tiny),
                  ],
                ],
              ),
            ),
            if (unread)
              Container(
                margin: const EdgeInsets.only(left: 6, top: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
