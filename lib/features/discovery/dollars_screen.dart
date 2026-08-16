import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'widgets/discovery_html.dart';
import '../../design_system/design_system.dart';

import '../../shared/widgets/bgm_button.dart';
import '../../core/storage/settings_store.dart';

/// 原版 Dollars HeaderV2: ONLINE：N / DOLLARS
String dollarsTitle(String? online) {
  final o = online?.trim() ?? '';
  return o.isEmpty ? 'DOLLARS' : 'ONLINE：$o';
}

/// 原版: 输入收起且下滑超过两屏才出回顶
bool dollarsShowScrollTop({
  required bool compose,
  required double pixels,
  required double windowHeight,
}) => !compose && pixels >= windowHeight * 2;

class DollarsData {
  final List<DollarsChatItem> items;
  final String online;

  const DollarsData({this.items = const [], this.online = ''});
}

/// Dollars 聊天室 (bgm.tv/dollars, 对齐原版 fetchDollars / updateDollars)
final dollarsChatProvider =
    AsyncNotifierProvider<DollarsChatNotifier, DollarsData>(
      DollarsChatNotifier.new,
    );

class DollarsChatNotifier extends AsyncNotifier<DollarsData> {
  @override
  Future<DollarsData> build() => _fetch();

  Future<DollarsData> _fetch() async {
    final client = ref.read(apiClientProvider);
    final html = await client.get(htmlDollars(), host: kHost);
    final parsed = parseDollars(html as String);
    return DollarsData(items: parsed.list, online: parsed.online);
  }

  Future<void> poll() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final since = current.items.isEmpty ? '' : current.items.first.id;
    try {
      final client = ref.read(apiClientProvider);
      final raw = await client.get(
        htmlDollars(
          sinceId: since,
          ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        ),
        host: kHost,
      );
      final text = raw.toString().trim();
      if (text.isEmpty || text == 'null') return;
      final decoded = jsonDecode(text);
      if (decoded is! List) return;
      final fresh = [
        for (final e in decoded.reversed)
          if (e is Map) DollarsChatItem.fromJson(Map<String, dynamic>.from(e)),
      ];
      if (fresh.isEmpty) return;
      state = AsyncData(
        DollarsData(
          items: [...fresh, ...current.items].take(80).toList(),
          online: current.online,
        ),
      );
    } catch (_) {}
  }

  Future<void> send(String message) async {
    final client = ref.read(apiClientProvider);
    await client.post(
      htmlDollarsSend(),
      data: {'message': message},
      host: kHost,
    );
    await poll();
  }
}

/// Dollars 聊天室
class DollarsScreen extends ConsumerStatefulWidget {
  const DollarsScreen({super.key});

  @override
  ConsumerState<DollarsScreen> createState() => _DollarsScreenState();
}

class _DollarsScreenState extends ConsumerState<DollarsScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  bool _sending = false;
  bool _compose = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (mounted) setState(() {});
    });
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (ref.read(settingsStoreProvider).dollarsAutoRefresh) {
        unawaited(ref.read(dollarsChatProvider.notifier).poll());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(dollarsChatProvider.notifier).send(text);
      _input.clear();
    } catch (_) {
      if (mounted) {
        showBgmToast(context, '发送失败, 可能需要重新登录');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(isLoggedInProvider);
    final async = ref.watch(dollarsChatProvider);
    final auto = ref.watch(settingsStoreProvider).dollarsAutoRefresh;
    final showTop = dollarsShowScrollTop(
      compose: _compose,
      pixels: _scroll.hasClients ? _scroll.position.pixels : 0,
      windowHeight: MediaQuery.sizeOf(context).height,
    );
    return Scaffold(
      appBar: BgmAppBar(
        title: dollarsTitle(async.valueOrNull?.online),
        showBackButton: true,
        actions: [
          if (showTop)
            BgmHeaderAction(
              tooltip: '到顶',
              icon: const Icon(Icons.keyboard_arrow_up, size: 28),
              onPressed: () {
                if (!_scroll.hasClients) return;
                _scroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                );
              },
            ),
          BgmHeaderAction(
            tooltip: auto ? '自动刷新 AUTO' : '自动刷新 OFF',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.refresh, size: 20),
                Positioned(
                  right: -10,
                  bottom: -6,
                  child: Text(
                    auto ? 'AUTO' : 'OFF',
                    style: context.ds.tiny.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 8,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () =>
                ref.read(settingsStoreProvider).setDollarsAutoRefresh(!auto),
          ),
          BgmHeaderAction(
            tooltip: _compose ? '关闭输入' : '编辑',
            icon: Icon(_compose ? Icons.close : Icons.edit),
            onPressed: () => setState(() => _compose = !_compose),
          ),
        ],
      ),

      body: async.when(
        loading: () => const Center(child: Loading()),
        error: (_, _) =>
            BgmRetry(onRetry: () => ref.invalidate(dollarsChatProvider)),
        data: (data) => Column(
          children: [
            Expanded(
              child: data.items.isEmpty
                  ? const Center(child: Text('暂无消息'))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: data.items.length,

                      itemBuilder: (context, index) {
                        final item = data.items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Cover(
                                url: item.avatar,
                                width: 32,
                                height: 32,
                                radius: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.nickname,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.msg,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (_compose)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: BgmField(
                          controller: _input,
                          enabled: loggedIn && !_sending,
                          hintText: loggedIn ? '说点什么…' : '登录后才能发送',
                          onSubmitted: (_) => unawaited(_send()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!loggedIn)
                        BgmTextAction(
                          '登录',
                          onPressed: () => context.push('/login'),
                        )
                      else
                        BgmHeaderAction(
                          onPressed: _sending ? null : () => unawaited(_send()),
                          icon: _sending
                              ? const BgmSpinner(size: 18)
                              : const Icon(Icons.send),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
