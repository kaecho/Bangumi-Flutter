import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';

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
final tinygrailStateProvider = AsyncNotifierProvider<TinygrailState, TinygrailUser?>(
  TinygrailState.new,
);

class TinygrailState extends AsyncNotifier<TinygrailUser?> {
  @override
  Future<TinygrailUser?> build() async {
    return _fetch();
  }

  Future<TinygrailUser?> _fetch() async {
    final client = ref.read(apiClientProvider);
    try {
      final hashData = await client.get(apiTinygrailHash(), host: kTinygrailHost, auth: true);
      final hash = (hashData as Map<String, dynamic>)['hash'] as String?;
      if (hash == null || hash.isEmpty) return null;
      final data = await client.get(apiTinygrailAssets(hash), host: kTinygrailHost);
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
        title: const Text('小圣杯'),
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
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                _StatItem(label: '可用资金', value: '${user.balance}'),
                                _StatItem(label: '持股总值', value: '${user.amount}'),
                                _StatItem(label: '资产总额', value: '${user.total}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _MenuTile(icon: Icons.emoji_events_outlined, title: '角色交易', route: '/tinygrail/trade'),
                    _MenuTile(icon: Icons.trending_up, title: '排行榜', route: '/tinygrail/rank'),
                    _MenuTile(icon: Icons.account_balance_outlined, title: '英灵殿', route: '/tinygrail/valhalla'),
                    _MenuTile(icon: Icons.military_tech_outlined, title: '圣殿', route: '/tinygrail/temple'),
                    _MenuTile(icon: Icons.gavel_outlined, title: '拍卖', route: '/tinygrail/auction'),
                    _MenuTile(icon: Icons.history, title: '我的持仓', route: '/tinygrail/assets'),
                    _MenuTile(icon: Icons.receipt_long_outlined, title: '交易记录', route: '/tinygrail/logs'),
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
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;

  const _MenuTile({required this.icon, required this.title, required this.route});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => context.push(route),
      ),
    );
  }
}
