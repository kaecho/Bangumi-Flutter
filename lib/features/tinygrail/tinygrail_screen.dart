import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/storage/settings_store.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/tab_title.dart';
import '../../design_system/design_system.dart';

import 'auction_screen.dart';
import 'bid_screen.dart';
import 'tinygrail_api.dart';

/// 小圣杯角色资产
class TinygrailChara {
  final int monoId;
  final String name;
  final String icon;
  final int level;
  final int current;
  final int total;
  final int state;
  final int users;
  final int lastOrder;

  const TinygrailChara({
    this.monoId = 0,
    this.name = '',
    this.icon = '',
    this.level = 0,
    this.current = 0,
    this.total = 0,
    this.state = 0,
    this.users = 0,
    this.lastOrder = 0,
  });

  factory TinygrailChara.fromJson(Map<String, dynamic> json) => TinygrailChara(
    monoId: (json['monoId'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    icon: json['icon'] as String? ?? '',
    level: (json['level'] as num?)?.toInt() ?? 0,
    current: (json['current'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
    state: (json['state'] as num?)?.toInt() ?? 0,
    users: (json['users'] as num?)?.toInt() ?? 0,
    lastOrder: (json['lastOrder'] as num?)?.toInt() ?? 0,
  );
}

/// 小圣杯用户资产
class TinygrailUser {
  final String hash;
  final String nickname;
  final int balance;
  final int principal;
  final int amount;
  final int total;

  const TinygrailUser({
    this.hash = '',
    this.nickname = '',
    this.balance = 0,
    this.principal = 0,
    this.amount = 0,
    this.total = 0,
  });

  factory TinygrailUser.fromJson(Map<String, dynamic> json) => TinygrailUser(
    hash: json['hash'] as String? ?? '',
    nickname: json['nickname'] as String? ?? '',
    balance: (json['balance'] as num?)?.toInt() ?? 0,
    principal: (json['principal'] as num?)?.toInt() ?? 0,
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
  );
}

/// 小圣杯登录状态 + 资产
final tinygrailStateProvider =
    AsyncNotifierProvider<TinygrailState, TinygrailUser?>(TinygrailState.new);

class TinygrailState extends AsyncNotifier<TinygrailUser?> {
  @override
  Future<TinygrailUser?> build() async {
    return _fetch();
  }

  Future<TinygrailUser?> _fetch() async {
    final client = ref.read(apiClientProvider);
    try {
      final hashData = await client.get(
        apiTinygrailHash(),
        host: kTinygrailHost,
        auth: true,
      );
      final hash = (hashData as Map<String, dynamic>)['hash'] as String?;
      if (hash == null || hash.isEmpty) return null;
      final data = await client.get(
        apiTinygrailAssets(hash),
        host: kTinygrailHost,
      );
      return TinygrailUser.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

/// 小圣杯 Tab (Tab 6, 设置中开启)
class TinygrailScreen extends ConsumerWidget {
  const TinygrailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tinygrailStateProvider);
    final isLogin = ref.watch(isLoggedInProvider);

    return Scaffold(
      appBar: AppBar(
        title: const TabLogoTitle('小圣杯'),

        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () => context.push('/tinygrail/search'),
          ),
          IconButton(
            icon: const Icon(Icons.trending_up),
            tooltip: '排行榜',
            onPressed: () => context.push('/tinygrail/rank'),
          ),
        ],
      ),
      body: !isLogin
          ? const Center(child: Text('登录后使用小圣杯'))
          : state.when(
              loading: () => const Loading(),
              error: (_, _) => const Center(child: Text('加载失败')),
              data: (user) {
                if (user == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('尚未绑定小圣杯账号'),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.push('/tinygrail/login'),
                          child: const Text('去授权'),
                        ),
                      ],
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Avatar(url: '', size: 40, name: user.nickname),
                                const SizedBox(width: 10),
                                Text(
                                  user.nickname,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                _StatItem(
                                  label: '可用资金',
                                  value: SettingsStore.instance.xsbShort
                                      ? tgMoney(user.balance)
                                      : '${user.balance}',
                                ),
                                _StatItem(
                                  label: '持股总值',
                                  value: SettingsStore.instance.xsbShort
                                      ? tgMoney(user.amount)
                                      : '${user.amount}',
                                ),
                                _StatItem(
                                  label: '资产总额',
                                  value: SettingsStore.instance.xsbShort
                                      ? tgMoney(user.total)
                                      : '${user.total}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _MenuGrid(
                      bids: ref.watch(myBidsProvider).valueOrNull?.length ?? 0,
                      asks: ref.watch(myAsksProvider).valueOrNull?.length ?? 0,
                      auction:
                          ref.watch(myAuctionProvider).valueOrNull?.length ?? 0,
                    ),
                    const SizedBox(height: 12),
                    const _TinygrailFooter(),
                  ],
                );
              },
            ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label, style: context.ds.meta),
        ],
      ),
    );
  }
}

/// 小圣杯菜单宫格 (移植自原项目 screens/tinygrail/index MENU_ITEMS)
class _MenuGrid extends StatelessWidget {
  final int bids;
  final int asks;
  final int auction;

  const _MenuGrid({
    required this.bids,
    required this.asks,
    required this.auction,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_Menu>[
      _Menu(Icons.whatshot_outlined, '热门榜单', '/tinygrail/overview'),
      _Menu(Icons.paid_outlined, '番市首富', '/tinygrail/rich'),
      _Menu(Icons.attach_money_outlined, 'ICO 榜单', '/tinygrail/ico'),
      _Menu(Icons.favorite_outline, '每周萌王', '/tinygrail/top-week'),
      _Menu(Icons.account_balance_outlined, '英灵殿', '/tinygrail/valhalla'),
      _Menu(Icons.grid_view_outlined, '最新圣殿', '/tinygrail/temples'),
      _Menu(Icons.change_history_outlined, '通天塔 (β)', '/tinygrail/star'),
      _Menu(Icons.add_circle_outline, '我的买单', '/tinygrail/bid', count: bids),
      _Menu(Icons.remove_circle_outline, '我的卖单', '/tinygrail/bid', count: asks),
      _Menu(Icons.gavel_outlined, '我的拍卖', '/tinygrail/bid', count: auction),
      _Menu(Icons.inbox_outlined, '我的持仓', '/tinygrail/chara-assets'),
      _Menu(Icons.insert_chart_outlined, '资金日志', '/tinygrail/logs'),
      _Menu(Icons.search, '人物搜索', '/tinygrail/search'),
      _Menu(Icons.chrome_reader_mode_outlined, '游戏指南', '/tinygrail/wiki'),
      _Menu(Icons.workspaces_outlined, '我的道具', '/tinygrail/items'),
      _Menu(Icons.swap_horiz, '角色交易', '/tinygrail/trade'),
      _Menu(Icons.account_balance_wallet_outlined, '我的资产', '/tinygrail/assets'),
      _Menu(Icons.temple_buddhist_outlined, '我的圣殿', '/tinygrail/temple'),
      _Menu(Icons.emoji_events_outlined, '拍卖大厅', '/tinygrail/auction'),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppGap.x2,
      crossAxisSpacing: AppGap.x2,
      children: [for (final m in items) _MenuCell(menu: m)],
    );
  }
}

class _Menu {
  final IconData icon;
  final String title;
  final String route;
  final int count;

  const _Menu(this.icon, this.title, this.route, {this.count = 0});
}

class _MenuCell extends StatelessWidget {
  final _Menu menu;

  const _MenuCell({required this.menu});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(menu.route),
      borderRadius: AppRadius.lAll,
      child: Container(
        decoration: BoxDecoration(
          color: context.ds.surfaceCard,
          borderRadius: AppRadius.lAll,
        ),
        padding: const EdgeInsets.symmetric(vertical: AppGap.x5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(menu.icon, size: 22, color: context.ds.accent),
                if (menu.count > 0)
                  Positioned(
                    right: -10,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: context.ds.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${menu.count}',
                        style: context.ds.tiny.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppGap.x2),
            Text(
              menu.title,
              style: context.ds.meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// 首页底部快捷 (对齐原项目 footer + btns: 刮刮乐/高级功能/粘贴板)
class _TinygrailFooter extends StatelessWidget {
  const _TinygrailFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(
            avatar: const Icon(Icons.celebration_outlined, size: 16),
            label: const Text('刮刮乐'),
            onPressed: () => context.push('/tinygrail/lottery-rank'),
          ),
          ActionChip(
            avatar: const Icon(Icons.auto_graph_outlined, size: 16),
            label: const Text('高级功能'),
            onPressed: () => context.push('/tinygrail/advance'),
          ),
          ActionChip(
            avatar: const Icon(Icons.content_paste_outlined, size: 16),
            label: const Text('粘贴板'),
            onPressed: () => context.push('/tinygrail/clipboard'),
          ),
          ActionChip(
            avatar: const Icon(Icons.account_tree_outlined, size: 16),
            label: const Text('资产分析'),
            onPressed: () => context.push('/tinygrail/tree'),
          ),
          ActionChip(
            avatar: const Icon(Icons.event_available_outlined, size: 16),
            label: const Text('签到分红'),
            onPressed: () => context.push('/tinygrail/lottery-rank'),
          ),
        ],
      ),
    );
  }
}
