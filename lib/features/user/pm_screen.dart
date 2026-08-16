import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/site_cookies.dart';
import '../../core/utils/display.dart';

import '../../core/utils/format.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'user_models.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';

/// 原版 pm headerTitle: 新建「短信」; 详情「全部/线程名 (条数)」
String pmHeaderTitle({
  required bool compose,
  String threadTitle = '',
  int msgCount = 0,
}) {
  var title = compose ? '短信' : (threadTitle.isEmpty ? '全部' : threadTitle);
  if (msgCount > 0) title += ' ($msgCount)';
  return title;
}

/// 原版 headerTitleTextStyle: getVisualLength >= 10 → 15
double pmHeaderTitleSize(String title) =>
    getVisualLength(title) >= 10 ? 15 : 16;

/// 原版 RelatedPM: 线程标题数 > 2 才显示数字
bool pmShowThreadCount(int threadCount) => threadCount > 2;

/// 原版 ScrollNavButtons: 线程 ≥2 或消息 ≥8 才出上下键
bool pmShowScrollNav({required int threadCount, required int messageCount}) =>
    threadCount >= 2 || messageCount >= 8;

/// 原版 onPrevThread: 当前滚动上方最近的线程标签, 没有则到顶
int? pmPrevThreadIndex({
  required List<int> labelIndexes,
  required int currentIndex,
}) {
  for (final i in labelIndexes.reversed) {
    if (i < currentIndex) return i;
  }
  return null;
}

/// 原版 onNextThread: 当前滚动下方最近的线程标签, 没有则到底
int? pmNextThreadIndex({
  required List<int> labelIndexes,
  required int currentIndex,
}) {
  for (final i in labelIndexes) {
    if (i > currentIndex) return i;
  }
  return null;
}

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
      appBar: BgmAppBar(
        title: '短信',
        actions: [
          BgmHeaderMore.browser(() => openExternalUrl(apiPmInboxHtml())),
        ],
      ),

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
          BgmButton(
            'OAuth 登录',
            expand: false,
            onPressed: () => context.push('/login'),
          ),
          const SizedBox(height: 8),
          BgmTextAction(
            '或使用站点 Cookie 登录',
            onPressed: () => context.push('/settings/cookies'),
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
      error: (_, _) => BgmRetry(onRetry: () => ref.invalidate(pmInboxProvider)),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('暂无短信 (需网页端登录后可见)'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const BgmHairline(),
          itemBuilder: (context, index) {
            final item = items[index];
            return BgmTextRow(
              leading: Avatar(url: item.avatar, size: 44, name: item.name),
              title: item.name.isNotEmpty ? item.name : item.title,
              subtitle: item.content,
              trailing: item.time.isEmpty
                  ? null
                  : Text(item.time, style: context.ds.meta),
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
      showBgmToast(context, '已发送');
      final convId = int.tryParse(widget.convId ?? '');
      if (convId != null) {
        ref.invalidate(pmChatProvider((convId: convId, thread: _thread)));
      }
    } catch (e) {
      if (!mounted) return;
      showBgmToast(context, '发送失败: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  ({int convId, String thread})? get _chatQuery {
    final convId = int.tryParse(widget.convId ?? '');
    if (convId == null) return null;
    return (convId: convId, thread: _thread);
  }

  void _scrollToIndex(int index) {
    if (!_scroll.hasClients) return;
    final itemHeight = 72.0;
    _scroll.animateTo(
      (index * itemHeight).clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _onPrevThread(List<PmMessage> list) {
    if (_thread.isNotEmpty) {
      scrollBgmToTop(_scroll);
      return;
    }
    final labels = [
      for (var i = 0; i < list.length; i++)
        if (list[i].type == 'label') i,
    ];
    final current = _scroll.hasClients ? (_scroll.offset / 72).floor() : 0;

    final target = pmPrevThreadIndex(
      labelIndexes: labels,
      currentIndex: current,
    );
    if (target == null) {
      scrollBgmToTop(_scroll);
      return;
    }
    _scrollToIndex(target);
  }

  void _onNextThread(List<PmMessage> list) {
    if (_thread.isNotEmpty) {
      _scrollToBottom();
      return;
    }
    final labels = [
      for (var i = 0; i < list.length; i++)
        if (list[i].type == 'label') i,
    ];
    final current = _scroll.hasClients ? (_scroll.offset / 72).ceil() : 0;
    final target = pmNextThreadIndex(
      labelIndexes: labels,
      currentIndex: current,
    );
    if (target == null) {
      _scrollToBottom();
      return;
    }
    _scrollToIndex(target);
  }

  @override
  Widget build(BuildContext context) {
    final query = _chatQuery;
    final chat = query == null ? null : ref.watch(pmChatProvider(query));
    final form = chat?.valueOrNull?.form;
    final list = chat?.valueOrNull?.list ?? const <PmMessage>[];
    final title = pmHeaderTitle(
      compose: query == null,
      threadTitle:
          form?.threads
              .where((t) => t.$1 == _thread)
              .map((t) => t.$2)
              .firstOrNull ??
          '',
      msgCount: list.where((e) => e.type != 'label').length,
    );
    final threadCount = form?.threads.length ?? 0;
    return Scaffold(
      appBar: BgmAppBar(
        title: title,
        titleWidget: query == null
            ? null
            : Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.ds.section.copyWith(
                  fontSize: pmHeaderTitleSize(title),
                  letterSpacing: getVisualLength(title) >= 10 ? -0.5 : 0,
                  height: 1.2,
                ),
              ),
        actions: [
          if (query != null) ...[
            if (_thread.isNotEmpty)
              BgmHeaderAction(
                tooltip: '回全部',
                icon: const Icon(Icons.subdirectory_arrow_right, size: 18),
                onPressed: () => setState(() => _thread = ''),
              ),
            if (pmShowScrollNav(
              threadCount: threadCount,
              messageCount: list.where((e) => e.type != 'label').length,
            )) ...[
              BgmHeaderAction(
                tooltip: '上一线程',
                icon: const Icon(Icons.keyboard_arrow_up, size: 24),
                onPressed: () => _onPrevThread(list),
                onLongPress: () => scrollBgmToTop(_scroll),
              ),
              BgmHeaderAction(
                tooltip: '下一线程',
                icon: const Icon(Icons.keyboard_arrow_down, size: 24),
                onPressed: () => _onNextThread(list),
                onLongPress: _scrollToBottom,
              ),
            ],
            BgmHeaderMore(
              items: [
                if (form != null) ('new', '新主题'),
                for (final t in form?.threads ?? const <(String, String)>[])
                  ('thread:${t.$1}', t.$2),
                ('browser', '浏览器查看'),
              ],
              onSelected: (v) {
                if (v == 'new') {
                  final peer = form?.peerUserId.isNotEmpty == true
                      ? form!.peerUserId
                      : widget.userId;
                  context.push('/pm/chat/$peer');
                  return;
                }
                if (v == 'browser') {
                  final convId = int.tryParse(widget.convId ?? '');
                  if (convId == null) return;
                  openExternalUrl(
                    apiPmConversationHtml(
                      convId,
                      thread: _thread.isEmpty ? null : _thread,
                    ),
                  );
                  return;
                }
                if (v.startsWith('thread:')) {
                  setState(() => _thread = v.substring(7));
                }
              },
            ),
            if (pmShowThreadCount(threadCount))
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 18),
                child: Text(
                  '$threadCount',
                  style: context.ds.tiny.copyWith(fontWeight: FontWeight.w700),
                ),
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
            child: BgmField(controller: _title, hintText: '标题 (可选, 默认「短信」)'),
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
              child: BgmField(
                controller: _input,
                maxLines: 4,
                minLines: 1,
                hintText: '输入消息…',
              ),
            ),
            const SizedBox(width: 8),
            BgmButton(
              '发送',
              expand: false,
              loading: _sending,
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}
