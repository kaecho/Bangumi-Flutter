import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/bgm_button.dart';
import '../user/mono_screen.dart';
import 'widgets/discovery_html.dart';

/// 原版 HeaderV2: 有 userName → TA的人物, 否则 我的人物
String characterTitle(String? userName) {
  final name = userName?.trim() ?? '';
  return name.isEmpty ? '我的人物' : 'TA的人物';
}

/// 原版 tabs: 自己 (含从空间打开) 才有人物近况
bool characterShowRecents(String? userName, {String? meId}) {
  final name = userName?.trim() ?? '';
  if (name.isEmpty) return true;
  final me = meId?.trim() ?? '';
  return me.isNotEmpty && name == me;
}

/// 我的人物 / TA的人物
///
/// 收藏列表走主站 HTML /user/{uid}/mono/{kind} 分页; 自己才有人物近况。

class MonoRecentsData {
  final List<MonoRecentItem> items;
  final int page;
  final bool hasMore;

  const MonoRecentsData({
    this.items = const [],
    this.page = 1,
    this.hasMore = true,
  });
}

/// 收藏人物的最近作品 (bgm.tv/mono/update, 对齐原版 LIMIT=20)
final monoRecentsProvider =
    AsyncNotifierProvider<MonoRecentsNotifier, MonoRecentsData>(
      MonoRecentsNotifier.new,
    );

class MonoRecentsNotifier extends AsyncNotifier<MonoRecentsData> {
  static const _limit = 20;

  @override
  Future<MonoRecentsData> build() => _fetch(1);

  Future<MonoRecentsData> _fetch(int page) async {
    final client = ref.read(apiClientProvider);
    final html = await client.get(htmlUserMonoRecents(page: page), host: kHost);
    final items = parseMonoRecents(html as String);
    return MonoRecentsData(
      items: items,
      page: page,
      hasMore: items.length >= _limit,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(current.page + 1);
      state = AsyncData(
        MonoRecentsData(
          items: [...current.items, ...next.items],
          page: next.page,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {}
  }
}

/// 原版 isFutureDate: info 里的日期晚于今天
bool isRecentFutureDate(String info, [DateTime? now]) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final cn = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(info);
  final iso = cn ?? RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(info);
  if (iso == null) return false;
  final date = DateTime(
    int.parse(iso.group(1)!),
    int.parse(iso.group(2)!),
    int.parse(iso.group(3)!),
  );
  return date.isAfter(today);
}

/// 原版 getDividerIndex: 最后一个未来日期之后插入分割线
int recentDividerIndex(List<MonoRecentItem> items, [DateTime? now]) {
  var lastFuture = -1;
  for (var i = 0; i < items.length; i++) {
    if (isRecentFutureDate(items[i].info, now)) lastFuture = i;
  }
  return lastFuture + 1;
}

/// 原版近况封面高 + 上下间距, 用于跳到分割线
const kRecentItemHeight = 86.0 + 16.0;

double recentDividerOffset(int dividerIndex) {
  if (dividerIndex <= 0) return 0;
  return (dividerIndex - 1) * kRecentItemHeight;
}

/// 原版 date('y-m-d')
String recentDividerLabel([DateTime? now]) {
  final d = now ?? DateTime.now();
  final y = (d.year % 100).toString().padLeft(2, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// 原版人物浏览器: 近况走 /mono/update, 其余走 /user/{id}/mono
String characterBrowserUrl({required bool recents, required String userId}) {
  if (recents || userId.isEmpty) return htmlUserMonoRecents();
  return htmlUserMonoPage(userId);
}

/// 用户人物 (原项目 tabs: 自己 人物近况/虚拟角色/现实人物, TA 仅后两项)
class CharacterScreen extends ConsumerStatefulWidget {
  final String userName;

  const CharacterScreen({super.key, this.userName = ''});

  @override
  ConsumerState<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends ConsumerState<CharacterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _recentsScroll = ScrollController();

  bool _self = true;

  String _meId(WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    if (user == null) return '';
    return user.username.isEmpty ? '${user.id}' : user.username;
  }

  String _username(WidgetRef ref) {
    final name = widget.userName.trim();
    if (name.isNotEmpty) return name;
    return _meId(ref);
  }

  @override
  void initState() {
    super.initState();
    _self = characterShowRecents(widget.userName, meId: _meId(ref));
    _tab = TabController(length: _self ? 3 : 2, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _tab.dispose();
    _recentsScroll.dispose();
    super.dispose();
  }

  void _jumpRecentsDivider() {
    final items = ref.read(monoRecentsProvider).valueOrNull?.items ?? const [];
    final divider = recentDividerIndex(items);
    if (divider <= 0 || !_recentsScroll.hasClients) return;
    _recentsScroll.animateTo(
      recentDividerOffset(divider),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(isLoggedInProvider);
    final username = _username(ref);
    final needLogin = _self && !loggedIn;

    return Scaffold(
      appBar: BgmAppBar(
        title: characterTitle(widget.userName),
        showBackButton: true,
        actions: [
          if (_self && _tab.index == 0)
            BgmHeaderAction(
              tooltip: '跳到今天',
              icon: const Icon(Icons.radio_button_checked, size: 16),
              onPressed: _jumpRecentsDivider,
            ),
          BgmHeaderMore.browser(() {
            openExternalUrl(
              characterBrowserUrl(
                recents: _self && _tab.index == 0,
                userId: username,
              ),
            );
          }),
        ],
      ),

      body: needLogin
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('登录后查看收藏的角色'),
                  const SizedBox(height: 12),
                  BgmButton(
                    '去登录',
                    expand: false,
                    onPressed: () => context.push('/login'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                BgmControlledTabStrip(
                  controller: _tab,
                  tabs: [
                    if (_self) const Text('人物近况'),
                    const Text('虚拟角色'),
                    const Text('现实人物'),
                  ],
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      if (_self) _RecentsList(scroll: _recentsScroll),

                      UserMonoList(userId: username, kind: 'character'),
                      UserMonoList(userId: username, kind: 'person'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _RecentsList extends ConsumerStatefulWidget {
  final ScrollController scroll;

  const _RecentsList({required this.scroll});

  @override
  ConsumerState<_RecentsList> createState() => _RecentsListState();
}

class _RecentsListState extends ConsumerState<_RecentsList> {
  ScrollController get _scroll => widget.scroll;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        unawaited(ref.read(monoRecentsProvider.notifier).loadMore());
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final async = ref.watch(monoRecentsProvider);
    return async.when(
      loading: () => const Center(child: Loading()),
      error: (_, _) =>
          BgmRetry(onRetry: () => ref.invalidate(monoRecentsProvider)),
      data: (data) {
        if (data.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(monoRecentsProvider),
            child: ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('收藏你喜欢的角色/声优/团体\n追踪最新相关作品动态')),
              ],
            ),
          );
        }
        final divider = recentDividerIndex(data.items);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(monoRecentsProvider),
          child: ListView.separated(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: data.items.length + (data.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const BgmHairline(height: 16),
            itemBuilder: (context, index) {
              if (index >= data.items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: BgmSpinner(size: 20)),
                );
              }
              final item = data.items[index];
              final row = InkWell(
                onTap: item.id == 0
                    ? null
                    : () => context.push('/subject/${item.id}'),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Cover(url: item.cover, width: 64, height: 86, radius: 4),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name.isEmpty ? item.nameJp : item.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.name.isNotEmpty && item.nameJp.isNotEmpty)
                            Text(
                              item.nameJp,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (item.info.isNotEmpty)
                            Text(
                              item.info,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (item.star > 0)
                            Text(
                              '${item.star} 分 ${item.starInfo}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          if (item.actors.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  for (final actor in item.actors.take(4))
                                    InkWell(
                                      onTap: actor.$1.isEmpty
                                          ? null
                                          : () => context.push(
                                              '/mono/${actor.$1}',
                                            ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Cover(
                                            url: actor.$2,
                                            width: 22,
                                            height: 22,
                                            radius: 11,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            actor.$3,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              if (index != divider) return row;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Expanded(child: BgmHairline()),
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          recentDividerLabel(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const Expanded(child: BgmHairline()),
                      ],
                    ),
                  ),
                  row,
                ],
              );
            },
          ),
        );
      },
    );
  }
}
