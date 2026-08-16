import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/site_cookies.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';

import '../../shared/models/timeline.dart';
import '../../shared/models/user.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';


/// 吐槽评论
class SayComment {
  final int id;
  final int userId;
  final User? user;
  final String content;
  final String createdAt;
  final int likes;

  const SayComment({
    this.id = 0,
    this.userId = 0,
    this.user,
    this.content = '',
    this.createdAt = '',
    this.likes = 0,
  });

  factory SayComment.fromJson(Map<String, dynamic> json) => SayComment(
    id: (json['id'] as num?)?.toInt() ?? 0,
    userId: (json['user_id'] as num?)?.toInt() ?? 0,
    user: json['user'] == null
        ? null
        : User.fromJson(json['user'] as Map<String, dynamic>),
    content: json['content'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
    likes: (json['likes'] as num?)?.toInt() ?? 0,
  );
}

/// 吐槽详情数据: 吐槽本体 + 评论列表
class SayDetail {
  final Say say;
  final List<SayComment> comments;

  const SayDetail({required this.say, this.comments = const []});
}

int _sayThreadLength(SayDetail detail) => 1 + detail.comments.length;

String _sayHeaderTitle(SayDetail? detail) {
  if (detail == null) return '吐槽';
  final date = detail.say.createdAt.split(' ').first;
  return '吐槽 (${_sayThreadLength(detail)})${date.isEmpty ? '' : ' · $date'}';
}

/// 吐槽详情 (移植自原项目 screens/timeline/say)
/// 数据: /say/{id} + /timeline/{id}/comments
final sayDetailProvider = FutureProvider.family<SayDetail, int>((
  ref,
  id,
) async {
  final client = ref.read(apiClientProvider);

  Say say;
  try {
    final raw = await client.get(apiSay(id));
    // /say/{id} 返回单个吐槽对象
    say = Say.fromJson(raw as Map<String, dynamic>);
  } catch (_) {
    say = Say(id: id);
  }

  List<SayComment> comments = const [];
  try {
    final raw = await client.get(apiTimelineComments(id));
    comments = (raw as List)
        .whereType<Map<String, dynamic>>()
        .map(SayComment.fromJson)
        .toList();
  } catch (_) {
    // 评论可能因权限不可用, 不阻塞页面
  }

  return SayDetail(say: say, comments: comments);
});

/// 吐槽详情页
/// 路由: /timeline/say/:id
class SayScreen extends ConsumerStatefulWidget {
  final int id;

  const SayScreen({super.key, required this.id});

  @override
  ConsumerState<SayScreen> createState() => _SayScreenState();
}

class _SayScreenState extends ConsumerState<SayScreen> {
  final _reply = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      String gh;
      try {
        gh = await ref.read(formhashProvider.future);
      } catch (_) {
        gh = '';
      }
      if (gh.isEmpty) {
        if (mounted) {
          showBgmToast(context, '回复吐槽需要站点 Cookie 登录');
        }
        return;
      }
      await ref
          .read(apiClientProvider)
          .post(
            htmlTimelineReply(widget.id),
            host: kHost,
            data: {'content': text, 'formhash': gh, 'submit': 'submit'},
          );
      if (!mounted) return;
      _reply.clear();
      ref.invalidate(sayDetailProvider(widget.id));
      showBgmToast(context, '已回复');
    } catch (e) {
      if (mounted) {
        showBgmToast(context, '回复失败: ${apiErrorMessage(e)}');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToTop() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final detail = ref.watch(sayDetailProvider(id));
    final loaded = detail.valueOrNull;
    final threadLen = loaded == null ? 0 : _sayThreadLength(loaded);
    final ds = context.ds;
    return Scaffold(
      appBar: BgmAppBar(
        titleWidget: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _sayHeaderTitle(loaded),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ds.section,
          ),
        ),
        actions: [
          if (threadLen >= 10) ...[
            BgmHeaderAction(
              tooltip: '到顶',
              icon: const Icon(Icons.keyboard_arrow_up, size: 24),
              onPressed: _scrollToTop,
            ),
            BgmHeaderAction(
              tooltip: '到底',
              icon: const Icon(Icons.keyboard_arrow_down, size: 24),
              onPressed: _scrollToBottom,
            ),
          ],
          BgmHeaderMore.browser(() {
            final say = loaded?.say;
            final userId = say?.user?.username.isNotEmpty == true
                ? say!.user!.username
                : '${say?.userId ?? ''}';
            if (userId.isEmpty) return;
            openExternalUrl(htmlSay(userId, id));
          }),
        ],
      ),
      body: detail.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) => BgmRetry(
          onRetry: () => ref.invalidate(sayDetailProvider(id)),
          message: apiErrorMessage(e),
        ),
        data: (value) {
          final me = ref.watch(currentUserProvider);
          final myId = me?.id ?? 0;
          final thread = <({int userId, User? user, String content, String createdAt})>[
            (
              userId: value.say.userId,
              user: value.say.user,
              content: value.say.content,
              createdAt: value.say.createdAt,
            ),
            for (final c in value.comments)
              (
                userId: c.userId,
                user: c.user,
                content: c.content,
                createdAt: c.createdAt,
              ),
          ];
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: thread.length,
                  itemBuilder: (context, index) {
                    final item = thread[thread.length - 1 - index];
                    final prev = index + 1 < thread.length
                        ? thread[thread.length - 2 - index]
                        : null;
                    final showName =
                        prev == null || prev.userId != item.userId;
                    final isLast = index == 0;
                    return _SayBubble(
                      user: item.user,
                      userId: item.userId,
                      content: item.content,
                      isSelf: myId != 0 && item.userId == myId,
                      showName: showName,
                      date: isLast ? item.createdAt : '',
                      onAt: (name) {
                        final next = '@$name ${_reply.text}';
                        _reply.value = TextEditingValue(
                          text: next,
                          selection: TextSelection.collapsed(offset: next.length),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: BgmField(
                          controller: _reply,
                          minLines: 1,
                          maxLines: 4,
                          hintText: '回复吐槽, 长按头像@某人',
                          onSubmitted: (_) => _sendReply(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      BgmButton(
                        '回复',
                        expand: false,
                        loading: _sending,
                        onPressed: _sendReply,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SayBubble extends StatelessWidget {
  final User? user;
  final int userId;
  final String content;
  final bool isSelf;
  final bool showName;
  final String date;
  final ValueChanged<String>? onAt;

  const _SayBubble({
    required this.user,
    required this.userId,
    required this.content,
    required this.isSelf,
    required this.showName,
    this.date = '',
    this.onAt,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final name = user?.displayName ?? '用户$userId';
    final avatar = GestureDetector(
      onLongPress: onAt == null ? null : () => onAt!(name),
      child: Avatar(
        url: user?.avatarUrl ?? '',
        size: 36,
        name: name,
      ),
    );
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelf ? ds.accentSoft : ds.surfaceCard,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(content, style: ds.body),
    );
    final nameText = showName
        ? Padding(
            padding: EdgeInsets.only(
              left: isSelf ? 0 : 8,
              right: isSelf ? 8 : 0,
              bottom: 4,
            ),
            child: Text(name, style: ds.tiny),
          )
        : const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: isSelf
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: isSelf
                ? [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [nameText, bubble],
                      ),
                    ),
                    const SizedBox(width: 8),
                    avatar,
                  ]
                : [
                    avatar,
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [nameText, bubble],
                      ),
                    ),
                  ],
          ),
          if (date.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                date,
                textAlign: TextAlign.center,
                style: ds.caption,
              ),
            ),
        ],
      ),
    );
  }
}

/// 发表吐槽 (原项目 header '+' → Say 新发模式)
/// 路由: /timeline/say/new
class SayComposeScreen extends ConsumerStatefulWidget {
  const SayComposeScreen({super.key});

  @override
  ConsumerState<SayComposeScreen> createState() => _SayComposeScreenState();
}

class _SayComposeScreenState extends ConsumerState<SayComposeScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      String gh;
      try {
        gh = await ref.read(formhashProvider.future);
      } catch (_) {
        gh = '';
      }
      if (gh.isEmpty) {
        if (mounted) {
          showBgmToast(context, '发表吐槽需要站点 Cookie 登录');
        }
        return;
      }
      final client = ref.read(apiClientProvider);
      await client.post(
        htmlUpdateSay(),
        host: kHost,
        data: {'say_input': text, 'formhash': gh, 'submit': '提交'},
      );
      if (mounted) {
        showBgmToast(context, '已发表');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showBgmToast(context, '发表失败: ${apiErrorMessage(e)}');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Scaffold(
      appBar: BgmAppBar(
        titleWidget: Align(
          alignment: Alignment.centerLeft,
          child: Text('新吐槽', style: ds.section),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('点击底部输入框录入吐槽内容', style: ds.caption),
          ),
          const Spacer(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: BgmField(
                controller: _controller,
                autofocus: true,
                maxLength: 500,
                minLines: 1,
                maxLines: 4,
                hintText: '新吐槽',
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
