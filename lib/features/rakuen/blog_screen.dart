import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/site_cookies.dart';
import '../../core/utils/display.dart';

import '../../shared/widgets/bgm_html.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import 'html_parse.dart';
import 'rakuen_models.dart';

import 'rakuen_providers.dart';
import 'rakuen_settings.dart';
import 'widgets/fixed_textarea.dart';
import 'widgets/floor_view.dart';
import '../../design_system/design_system.dart';

/// 原版日志 Menu DATA
const kBlogMoreItems = <(String, String)>[
  ('browser', '浏览器查看'),
  ('copy', '复制链接'),
  ('share', '复制分享'),
];

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
  ReplyTarget? _replyTarget;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    var text = _replyController.text.trim();
    if (text.isEmpty) return;
    if (!ref.read(canActAsLoggedInProvider)) {
      await context.push('/login');
      return;
    }
    final page = ref.read(blogDetailProvider(widget.id)).valueOrNull;
    setState(() => _sending = true);
    try {
      var gh = page?.formhash ?? '';
      if (gh.isEmpty) {
        try {
          gh = await ref.read(formhashProvider.future);
        } catch (_) {}
      }
      if (gh.isEmpty) {
        if (mounted) {
          showBgmToast(context, '评论需要站点 Cookie 登录');
        }
        return;
      }
      final target = _replyTarget;
      if (target != null && target.messageHtml.isNotEmpty) {
        text = quoteReplyContent(
          userName: target.userName,
          messageHtml: target.messageHtml,
          content: text,
        );
      }
      final parsed = target == null ? null : parseReplySub(target.replySub);
      final lastview = page?.lastview.isNotEmpty == true
          ? page!.lastview
          : '${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
      await ref
          .read(apiClientProvider)
          .post(
            htmlBlogReply(widget.id),
            host: kHost,
            form: true,
            data: {
              'content': text,
              'formhash': gh,
              'related_photo': 0,
              'lastview': lastview,
              'submit': 'submit',
              if (parsed != null) ...{
                'related': parsed.related,
                'sub_reply_uid': parsed.subReplyUid,
                'post_uid': parsed.postUid,
              },
            },
          );
      _replyController.clear();
      _replyTarget = null;
      if (mounted) {
        showBgmToast(context, '回复成功');
      }
      ref.invalidate(blogDetailProvider(widget.id));
    } catch (e) {
      if (mounted) {
        showBgmToast(context, '回复失败: ${apiErrorMessage(e)}');
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
      appBar: BgmAppBar(
        title: async.valueOrNull?.title.isNotEmpty == true
            ? async.valueOrNull!.title
            : '日志',
        actions: [
          if (async.valueOrNull != null)
            BgmHeaderAction(
              tooltip:
                  ref
                      .watch(topicFavorProvider)
                      .any((e) => e.topicId == blogFavorTopicId(widget.id))
                  ? '取消收藏'
                  : '收藏日志',
              icon: Icon(
                ref
                        .watch(topicFavorProvider)
                        .any((e) => e.topicId == blogFavorTopicId(widget.id))
                    ? Icons.star
                    : Icons.star_border,
                size: 20,
              ),
              onPressed: () {
                final data = async.valueOrNull;
                if (data == null) return;
                unawaited(
                  ref
                      .read(topicFavorProvider.notifier)
                      .toggle(
                        HistoryItem(
                          topicId: blogFavorTopicId(widget.id),
                          title: data.title,
                          group: '日志',
                          userName: data.userName,
                          replies: commentFloorCount(data.floors),
                          time: DateTime.now().millisecondsSinceEpoch,
                        ),
                      ),
                );
              },
            ),
          BgmHeaderMore(
            items: kBlogMoreItems,
            onSelected: (v) {
              final url = htmlBlogPage(widget.id);
              final title = async.valueOrNull?.title ?? '日志';
              if (v == 'browser') {
                openExternalUrl(url);
                return;
              }
              if (v == 'copy') {
                Clipboard.setData(ClipboardData(text: url));
                showBgmToast(context, '已复制链接');
                return;
              }
              if (v == 'share') {
                Clipboard.setData(
                  ClipboardData(text: '【链接】$title | Bangumi番组计划\n$url'),
                );
                showBgmToast(context, '已复制分享文案');
              }
            },
          ),
        ],
      ),
      body: async.when(
        loading: () => const Loading(height: double.infinity),
        error: (e, _) => BgmRetry(
          onRetry: () => ref.invalidate(blogDetailProvider(widget.id)),
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
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
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            if (data.time.isNotEmpty)
                              Text(data.time, style: context.ds.tiny),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (data.contentHtml.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    BgmHtml(
                      data: data.contentHtml,
                      showImages: settings.loadImages,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Text(
                commentSectionTitle(commentFloorCount(data.floors)),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const BgmHairline(),

            if (data.floors.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    '还没有评论',
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                ),
              ),
            for (final (index, floor) in data.floors.indexed)
              FloorView(
                floor: floor,
                floorLabel: floor.floor.isNotEmpty
                    ? floor.floor
                    : '#${index + 1}',
                isAuthor: data.userId.isNotEmpty && floor.userId == data.userId,
                settings: settings,
                onReply: (target) => setState(() {
                  _replyTarget = target;
                  final prefix = '@${target.userName} ';
                  if (!_replyController.text.startsWith(prefix)) {
                    _replyController.text = prefix + _replyController.text;
                  }
                }),
                topicId: 'blog/${widget.id}',
                expanded: _expandedSubs.contains(floor.id),
                onExpand: () => setState(() {
                  if (!_expandedSubs.remove(floor.id)) {
                    _expandedSubs.add(floor.id);
                  }
                }),
              ),
          ],
        ),
      ),
      bottomNavigationBar: FixedTextarea(
        controller: _replyController,
        sending: _sending,
        loggedIn: ref.watch(canActAsLoggedInProvider),
        hint: '评论...',
        target: _replyTarget,
        historyKey: 'blog_reply_${widget.id}',
        onSend: _sendReply,
        onLogin: () => context.push('/login'),
        onClearTarget: () => setState(() => _replyTarget = null),
      ),
    );
  }
}
