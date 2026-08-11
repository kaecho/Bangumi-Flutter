import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'user_models.dart';

/// 收件箱 (bgm.tv/pm/inbox.chii, 主站 HTML)
final pmInboxProvider = FutureProvider<List<PmItem>>((ref) async {
  final client = ref.read(apiClientProvider);
  final html = await client.get(apiPmInboxHtml(), host: kHost);
  return parsePmInbox(html as String);
});

/// 短信详情 (bgm.tv/pm/conversation/ID.chii)
final pmChatProvider =
    FutureProvider.family<({List<PmMessage> list, PmForm form}), int>((ref, convId) async {
  final client = ref.read(apiClientProvider);
  final html = await client.get(apiPmConversationHtml(convId), host: kHost);
  return parsePmChat(html as String);
});

/// 短信 (收件箱)
class PmScreen extends ConsumerWidget {
  const PmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLogin = ref.watch(isLoggedInProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('短信')),
      body: isLogin ? const _PmInbox() : const _PmLoginGate(),
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
          const Icon(Icons.mail_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('登录后查看短信'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('登录'),
          ),
        ],
      ),
    );
  }
}

class _PmInbox extends ConsumerWidget {
  const _PmInbox();

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
              onTap: () => context.push('/pm/chat/${item.userId}?conv=${item.id}'),
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
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(PmForm form) async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.post(
        apiPmCreateHtml(),
        data: {
          'related': form.related,
          'msg_receivers': form.msgReceivers.isEmpty ? widget.userId : form.msgReceivers,
          'current_msg_id': form.currentMsgId,
          'formhash': form.formhash,
          'msg_title': form.msgTitle.isEmpty ? 'Re: ${form.msgTitle}' : form.msgTitle,
          'msg_body': text,
          'chat': 'on',
          'submit': '回复',
        },
        host: kHost,
      );
      if (!mounted) return;
      _input.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已发送')));
      final convId = int.tryParse(widget.convId ?? '');
      if (convId != null) ref.invalidate(pmChatProvider(convId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发送失败: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final convId = int.tryParse(widget.convId ?? '');
    return Scaffold(
      appBar: AppBar(title: Text(widget.userId)),
      body: convId == null
          ? const Center(child: Text('请从短信列表进入会话'))
          : Column(
              children: [
                Expanded(
                  child: ref.watch(pmChatProvider(convId)).when(
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
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                            color: Theme.of(context).colorScheme.outline,
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
                // 输入栏
                SafeArea(
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
                          onPressed: _sending
                              ? null
                              : () {
                                  final form = ref.read(pmChatProvider(convId)).valueOrNull?.form ??
                                      const PmForm();
                                  _send(form);
                                },
                          child: const Text('发送'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
