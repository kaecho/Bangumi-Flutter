import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/widgets/bgm_html.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'rakuen_providers.dart';
import 'rakuen_settings.dart';
import 'widgets/floor_view.dart';

/// 日志详情
/// 路由: /rakuen/blog/:id
class BlogScreen extends ConsumerStatefulWidget {
  final int id;

  const BlogScreen({super.key, required this.id});

  @override
  ConsumerState<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends ConsumerState<BlogScreen> {
  final _replyController = TextEditingController();
  final _expandedSubs = <String>{};
  bool _sending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    if (!ref.read(isLoggedInProvider)) {
      await context.push('/login');
      return;
    }
    setState(() => _sending = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.post(apiBlogNewReply('${widget.id}'), data: {'content': text});
      _replyController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('回复成功')));
      }
      ref.invalidate(blogDetailProvider(widget.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('回复失败: ${apiErrorMessage(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(blogDetailProvider(widget.id));
    final settings = ref.watch(rakuenSettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          async.valueOrNull?.title.isNotEmpty == true ? async.valueOrNull!.title : '日志',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: async.when(
        loading: () => const Loading(height: double.infinity),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('加载失败'),
              TextButton(
                onPressed: () => ref.invalidate(blogDetailProvider(widget.id)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Avatar(url: data.avatar, size: 30, name: data.userName),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.userName.isEmpty ? '匿名' : data.userName,
                              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                            ),
                            if (data.time.isNotEmpty)
                              Text(
                                data.time,
                                style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (data.contentHtml.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    BgmHtml(data: data.contentHtml, showImages: settings.loadImages),
                  ],
                ],
              ),
            ),
            const Divider(height: 12),
            if (data.floors.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('还没有评论', style: TextStyle(color: theme.colorScheme.outline)),
                ),
              ),
            for (final (index, floor) in data.floors.indexed)
              FloorView(
                floor: floor,
                floorLabel: floor.floor.isNotEmpty ? floor.floor : '${index + 1}',
                isAuthor: false,
                settings: settings,
                onReply: (name) {
                  _replyController.text = '@$name ';
                  _replyController.selection =
                      TextSelection.collapsed(offset: _replyController.text.length);
                },
                expanded: _expandedSubs.contains(floor.id),
                onExpand: () => setState(() => _expandedSubs.add(floor.id)),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: ref.watch(isLoggedInProvider)
              ? Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: '评论...',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sending ? null : _sendReply,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      tooltip: '发送',
                      color: theme.colorScheme.primary,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        '登录后评论',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('去登录'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
