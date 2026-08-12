import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/html/bgm_html_parser.dart' as core;
import '../../shared/widgets/bgm_html.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'html_parse.dart';
import 'rakuen_providers.dart';
import 'rakuen_settings.dart';
import 'widgets/floor_view.dart';
import '../../design_system/design_system.dart';

/// 帖子详情 (超展开核心页面)
/// 路由: /rakuen/topic/:type/:id  (type: group|subject|ep|prsn|crt)
class TopicScreen extends ConsumerStatefulWidget {
  final String type;
  final String id;

  const TopicScreen({super.key, required this.type, required this.id});

  String get topicId => '$type/$id';

  @override
  ConsumerState<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends ConsumerState<TopicScreen> {
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();
  final _expandedSubs = <String>{};
  bool _showOnlyAuthor = false;
  bool _reverse = false;
  bool _sending = false;

  String get _topicId => widget.topicId;

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    if (!ref.read(canActAsLoggedInProvider)) {
      await context.push('/login');
      return;
    }
    setState(() => _sending = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.post(apiTopicNewReply(_topicId), data: {'content': text});
      _replyController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('回复成功')));
      }
      ref.invalidate(topicDetailProvider(_topicId));
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
    final async = ref.watch(topicDetailProvider(_topicId));
    final settings = ref.watch(rakuenSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          async.valueOrNull?.title.isNotEmpty == true
              ? async.valueOrNull!.title
              : '帖子详情',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _reverse ? Icons.vertical_align_bottom : Icons.vertical_align_top,
              size: 20,
            ),
            tooltip: '最新回复',
            onPressed: () => setState(() => _reverse = !_reverse),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Loading(height: double.infinity),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('加载失败'),
              TextButton(
                onPressed: () => ref.invalidate(topicDetailProvider(_topicId)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (data) => _TopicBody(
          data: data,
          settings: settings,
          showOnlyAuthor: _showOnlyAuthor,
          reverse: _reverse,
          expandedSubs: _expandedSubs,
          scrollController: _scrollController,
          onToggleAuthor: () => setState(() => _showOnlyAuthor = !_showOnlyAuthor),
          onExpandFloor: (id) => setState(() => _expandedSubs.add(id)),
          onReply: (name) {
            _replyController.text = '@$name ';
            _replyController.selection =
                TextSelection.collapsed(offset: _replyController.text.length);
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          },
          onLoadMore: () => ref.read(topicDetailProvider(_topicId).notifier).loadMore(),
        ),
      ),
      bottomNavigationBar: _ReplyBar(
        controller: _replyController,
        sending: _sending,
        onSend: _sendReply,
      ),
    );
  }
}

class _TopicBody extends StatelessWidget {
  final TopicPageData data;
  final RakuenSettingsState settings;
  final bool showOnlyAuthor;
  final bool reverse;
  final Set<String> expandedSubs;
  final ScrollController scrollController;
  final VoidCallback onToggleAuthor;
  final ValueChanged<String> onExpandFloor;
  final ValueChanged<String> onReply;
  final VoidCallback onLoadMore;

  const _TopicBody({
    required this.data,
    required this.settings,
    required this.showOnlyAuthor,
    required this.reverse,
    required this.expandedSubs,
    required this.scrollController,
    required this.onToggleAuthor,
    required this.onExpandFloor,
    required this.onReply,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    var floors = List<core.RakuenFloor>.from(data.floors);
    if (showOnlyAuthor && data.userId.isNotEmpty) {
      floors = floors.where((f) => f.userId == data.userId).toList();
    }
    if (reverse) floors = floors.reversed.toList();

    final oldTopic = settings.markOldTopic && _isOld(data.time);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        // 标题 + 元信息 + 主楼
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.group.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    final name = data.groupHref.replaceAll('/group/', '');
                    if (name.isNotEmpty) context.push('/rakuen/group/$name');
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      data.group,
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
                    ),
                  ),
                ),
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
                            style: context.ds.tiny,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${data.floors.length + 1} 楼',
                    style: context.ds.meta,
                  ),
                ],
              ),
              if (oldTopic)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '坟贴提醒: 该主题已经很久没有新回复',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              if (data.contentHtml.isNotEmpty) ...[
                const SizedBox(height: 10),
                BgmHtml(data: data.contentHtml, showImages: settings.loadImages),
              ],
            ],
          ),
        ),
        // 过滤栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('只看楼主'),
                selected: showOnlyAuthor,
                onSelected: (_) => onToggleAuthor(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (floors.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                showOnlyAuthor ? '楼主还没有回复' : '还没有回复',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ),
          ),
        for (final (index, floor) in floors.indexed)
          FloorView(
            floor: floor,
            floorLabel: floor.floor.isNotEmpty ? floor.floor : '${index + 2}',
            isAuthor: data.userId.isNotEmpty && floor.userId == data.userId,
            settings: settings,
            onReply: onReply,
            expanded: expandedSubs.contains(floor.id),
            onExpand: () => onExpandFloor(floor.id),
          ),
        if (data.pageTotal > 1)
          Center(
            child: TextButton(
              onPressed: onLoadMore,
              child: const Text('加载更多楼层'),
            ),
          ),
      ],
    );
  }

  bool _isOld(String time) {
    if (time.isEmpty) return false;
    final dt = DateTime.tryParse(time.replaceFirst(' ', 'T'));
    if (dt == null) return false;
    return DateTime.now().difference(dt) > const Duration(days: 90);
  }
}

/// 底部回复框
class _ReplyBar extends ConsumerWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _ReplyBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLogin = ref.watch(canActAsLoggedInProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: isLogin
            ? Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '回复楼主...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: sending ? null : onSend,
                    icon: sending
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
                      '登录后回复',
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
    );
  }
}
