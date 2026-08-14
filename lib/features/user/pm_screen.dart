import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/site_cookies.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'user_models.dart';
import '../../design_system/design_system.dart';

/// 收件箱 (bgm.tv/pm/inbox.chii, 主站 HTML)
final pmInboxProvider = FutureProvider<List<PmItem>>((ref) async {
  final client = ref.read(apiClientProvider);
  final html = await client.get(apiPmInboxHtml(), host: kHost);
  return parsePmInbox(html as String);
});

/// 短信详情 (bgm.tv/pm/conversation/ID.chii?thread=)
final pmChatProvider =
    FutureProvider.family<
      ({List<PmMessage> list, PmForm form}),
      ({int convId, String thread})
    >((ref, arg) async {
      final client = ref.read(apiClientProvider);
      final html = await client.get(
        apiPmConversationHtml(
          arg.convId,
          thread: arg.thread.isEmpty ? null : arg.thread,
        ),
        host: kHost,
      );
      return parsePmChat(html as String);
    });

/// 新短信表单 (bgm.tv/pm/compose/{uid}.chii)
final pmComposeProvider = FutureProvider.family<PmForm, String>((
  ref,
  userId,
) async {
  final client = ref.read(apiClientProvider);
  final html = await client.get(apiPmComposeParamsHtml(userId), host: kHost);
  return parsePmCompose(html as String);
});

/// 短信 (收件箱)
class PmScreen extends ConsumerWidget {
  const PmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLogin = ref.watch(isLoggedInProvider);
    final hasSiteCookies = ref.watch(siteCookiesProvider).hasCookies;
    return Scaffold(
      appBar: AppBar(title: const Text('短信')),
      body: isLogin || hasSiteCookies ? const PmInbox() : const _PmLoginGate(),
    );
  }
}

class _PmLoginGate extends StatelessWidget {
  const _PmLoginGate();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mail_outline, size: 48, color: context.ds.textHint),
          const SizedBox(height: 12),
          const Text('短信需要登录后才能查看'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('OAuth 登录'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.push('/settings/cookies'),
            child: const Text('或使用站点 Cookie 登录'),
          ),
        ],
      ),
    );
  }
}

class PmInbox extends ConsumerWidget {
  const PmInbox({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pmInboxProvider);
    return async.when(
      loading: () => const Loading(),
      error: (_, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('加载失败'),
            TextButton(
              onPressed: () => ref.invalidate(pmInboxProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('暂无短信 (需网页端登录后可见)'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(indent: 72),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: Avatar(url: item.avatar, size: 44, name: item.name),
              title: Row(
                children: [
                  if (item.isNew)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      item.name.isNotEmpty ? item.name : item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.time.isNotEmpty)
                    Text(
                      item.time,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                item.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              onTap: () =>
                  context.push('/pm/chat/${item.userId}?conv=${item.id}'),
            );
          },
        );
      },
    );
  }
}

/// 短信详情 (聊天)
class PmChatScreen extends ConsumerStatefulWidget {
  final String userId;
  final String? convId;

  const PmChatScreen({super.key, required this.userId, this.convId});

  @override
  ConsumerState<PmChatScreen> createState() => _PmChatScreenState();
}

class _PmChatScreenState extends ConsumerState<PmChatScreen> {
  final _input = TextEditingController();
  final _title = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String _thread = '';

  @override
  void dispose() {
    _input.dispose();
    _title.dispose();
    _scroll.dispose();
    super.dispose();
  }


  Future<void> _send(PmForm form, {bool compose = false}) async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.post(
        apiPmCreateHtml(),
        data: {
          'related': form.related,
          'msg_receivers': form.msgReceivers.isEmpty
              ? widget.userId
              : form.msgReceivers,
          'current_msg_id': form.currentMsgId,
          'formhash': form.formhash,
          'msg_title': () {
            final typed = _title.text.trim();
            if (typed.isNotEmpty) return typed;
            if (form.msgTitle.isNotEmpty) return form.msgTitle;
            return '短信';
          }(),

          'msg_body': text,
          if (!compose) 'chat': 'on',
          'submit': compose ? '发送' : '回复',
        },
        host: kHost,
      );
      if (!mounted) return;
      _input.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已发送')));
      final convId = int.tryParse(widget.convId ?? '');
      if (convId != null) {
        ref.invalidate(pmChatProvider((convId: convId, thread: _thread)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发送失败: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  ({int convId, String thread})? get _chatQuery {
    final convId = int.tryParse(widget.convId ?? '');
    if (convId == null) return null;
    return (convId: convId, thread: _thread);
  }

  @override
  Widget build(BuildContext context) {
    final query = _chatQuery;
    final chat = query == null ? null : ref.watch(pmChatProvider(query));
    final form = chat?.valueOrNull?.form;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          form != null && form.peerUserName.isNotEmpty
              ? form.peerUserName
              : widget.userId,
        ),
        actions: [
          if (query != null) ...[
            IconButton(
              tooltip: '回全部',
              icon: const Icon(Icons.list_alt_outlined),
              onPressed: () => context.go('/pm'),
            ),
            IconButton(
              tooltip: '顶部',
              icon: const Icon(Icons.vertical_align_top),
              onPressed: () {
                if (!_scroll.hasClients) return;
                _scroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                );
              },
            ),
            IconButton(
              tooltip: '底部',
              icon: const Icon(Icons.vertical_align_bottom),
              onPressed: () {
                if (!_scroll.hasClients) return;

                _scroll.animateTo(
                  _scroll.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                );
              },
            ),
            PopupMenuButton<String>(
              tooltip: '相关短信',
              icon: const Icon(Icons.more_horiz),
              onSelected: (v) {
                if (v == 'new') {
                  final peer = form?.peerUserId.isNotEmpty == true
                      ? form!.peerUserId
                      : widget.userId;
                  context.push('/pm/chat/$peer');
                  return;
                }
                if (v.startsWith('thread:')) {
                  setState(() => _thread = v.substring(7));
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'new', child: Text('新短信')),

                if (form != null)
                  for (final t in form.threads)
                    PopupMenuItem(value: 'thread:${t.$1}', child: Text(t.$2)),
              ],
            ),
          ],
        ],
      ),
      body: query == null ? _composeBody() : _conversationBody(query),
    );
  }

  Widget _composeBody() {
    final async = ref.watch(pmComposeProvider(widget.userId));
    return async.when(
      loading: () => const Loading(),
      error: (_, _) => const Center(child: Text('加载发信表单失败')),
      data: (form) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _title,
              decoration: const InputDecoration(
                hintText: '标题 (可选, 默认「短信」)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Expanded(child: Center(child: Text('给 TA 发一条新短信'))),
          _composer(onSend: () => unawaited(_send(form, compose: true))),
        ],
      ),
    );
  }


  Widget _conversationBody(({int convId, String thread}) query) {
    return Column(
      children: [
        Expanded(
          child: ref
              .watch(pmChatProvider(query))
              .when(
                loading: () => const Loading(),
                error: (_, _) => const Center(child: Text('加载失败')),
                data: (data) {
                  if (data.list.isEmpty) {
                    return const Center(child: Text('暂无消息 (需网页端登录后可见)'));
                  }
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: data.list.length,
                    itemBuilder: (context, index) {
                      final msg = data.list[index];
                      if (msg.type == 'label') {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Text(
                              msg.threadTitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      }
                      final isSelf = msg.name == '我';
                      return Align(
                        alignment: isSelf
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isSelf
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isSelf)
                                Text(
                                  msg.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Text(
                                stripHtml(msg.content),
                                style: const TextStyle(fontSize: 14),
                              ),
                              if (msg.time.isNotEmpty)
                                Text(
                                  msg.time,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
        ),
        _composer(
          onSend: () {
            final form =
                ref.read(pmChatProvider(query)).valueOrNull?.form ??
                const PmForm();
            unawaited(_send(form));
          },
        ),
      ],
    );
  }

  Widget _composer({required VoidCallback onSend}) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                maxLines: 4,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: '输入消息…',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _sending ? null : onSend,
              child: const Text('发送'),
            ),
          ],
        ),
      ),
    );
  }
}
