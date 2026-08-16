import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';

import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../design_system/design_system.dart';

import 'auction_screen.dart';
import 'bid_screen.dart';
import 'tinygrail_api.dart';
import '../../shared/widgets/bgm_button.dart';

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
      body: SafeArea(
        bottom: false,
        child: !isLogin
            ? const Center(child: Text('登录后使用小圣杯'))
            : state.when(
                loading: () => const Loading(),
                error: (_, _) => BgmRetry(
                  onRetry: () => ref.invalidate(tinygrailStateProvider),
                ),
                data: (user) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _AuthRow(user: user),
                    const SizedBox(height: 8),
                    _MenuGrid(
                      bids: ref.watch(myBidsProvider).valueOrNull?.length ?? 0,
                      asks: ref.watch(myAsksProvider).valueOrNull?.length ?? 0,
                      auction:
                          ref
                              .watch(myAuctionProvider)
                              .valueOrNull
                              ?.where((e) => e.state == 0)
                              .length ??
                          0,
                      assets: user,
                    ),
                    const SizedBox(height: 8),
                    const _TinygrailFooter(),
                  ],
                ),
              ),
      ),
    );
  }
}

class _AuthRow extends ConsumerWidget {
  final TinygrailUser? user;

  const _AuthRow({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = context.ds;
    final me = ref.watch(currentUserProvider);
    return Row(
      children: [
        Avatar(
          url: me?.avatarUrl ?? '',
          size: 36,
          name: user?.nickname ?? me?.displayName,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.nickname.isNotEmpty == true
                    ? user!.nickname
                    : (me?.displayName ?? '小圣杯'),
                style: ds.bodyStrong,
              ),
              GestureDetector(
                onTap: () => context.push('/settings/qiafan'),
                child: Text(
                  user == null ? '未授权' : '普通会员',
                  style: ds.caption.copyWith(color: ds.textSecondary),
                ),
              ),
            ],
          ),
        ),
        BgmHeaderAction(
          tooltip: '切换主题',
          icon: Icon(
            Theme.of(context).brightness == Brightness.dark
                ? Icons.brightness_2
                : Icons.wb_sunny,
            size: 18,
          ),
          onPressed: () => ref.read(settingsStoreProvider).toggleThemeMode(),
        ),
        if (user == null)
          BgmButton(
            '授权',
            expand: false,
            onPressed: () => context.push('/tinygrail/login'),
          )
        else
          PopupMenuButton<String>(
            tooltip: '刮刮乐 / 分红',
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.menu, size: 20),
            onSelected: (v) async {
              final api = ref.read(tinygrailApiProvider);
              switch (v) {
                case 'lottery':
                  await api.doScratch();
                case 'fantasy':
                  await api.doScratch(fantasy: true);
                case 'bonus':
                  final ok = await showBgmConfirm(
                    context,
                    title: '小圣杯助手',
                    message: '确定领取每周分红? (每周日0点刷新)',
                  );
                  if (ok == true) await api.doBonus();
                case 'daily':
                  await api.doBonusDaily();
                case 'holiday':
                  await api.doBonusHoliday();
                case 'auth':
                  if (context.mounted) await context.push('/tinygrail/login');
              }
            },
            itemBuilder: (_) {
              final count = 0;
              final price = 2000 * (1 << count);
              return [
                const PopupMenuItem(value: 'lottery', child: Text('刮刮乐')),
                PopupMenuItem(value: 'fantasy', child: Text('幻想乡刮刮乐($price)')),
                const PopupMenuItem(value: 'bonus', child: Text('每周分红')),
                const PopupMenuItem(value: 'daily', child: Text('每日签到')),
                const PopupMenuItem(value: 'holiday', child: Text('节日福利')),
                const PopupMenuItem(value: 'auth', child: Text('重新授权')),
              ];
            },
          ),
        BgmHeaderAction(
          tooltip: '圣星记录',
          icon: const Icon(Icons.menu_open, size: 20),
          onPressed: () => context.push('/tinygrail/star-logs'),
        ),
      ],
    );
  }
}

class _AssetsBar extends ConsumerWidget {
  final TinygrailUser user;

  const _AssetsBar({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(settingsStoreProvider);
    final ds = context.ds;
    final short = store.xsbShort;
    String money(int v) => short ? tgMoney(v) : '$v';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => store.setXsbShort(!short),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${money(user.balance)} / ${money(user.total)} ${short ? '[-]' : '[+]'}',
              style: ds.bodyStrong.copyWith(fontSize: 13),
            ),
          ),
          BgmHeaderAction(
            tooltip: '资产分析',
            icon: const Icon(Icons.calculate_outlined, size: 20),
            onPressed: () => context.push('/tinygrail/tree'),
          ),
        ],
      ),
    );
  }
}

/// 小圣杯菜单 (移植自原项目 menus/ds MENU_ITEMS)
class _MenuGrid extends StatelessWidget {
  final int bids;
  final int asks;
  final int auction;
  final TinygrailUser? assets;

  const _MenuGrid({
    required this.bids,
    required this.asks,
    required this.auction,
    this.assets,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = AppGap.x4;
        final width = (constraints.maxWidth - gap) / 2;
        Widget cell(_Menu menu) => SizedBox(
          width: width,
          child: _MenuCell(menu: menu, width: width),
        );
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            cell(const _Menu(Icons.whatshot, '热门榜单', '/tinygrail/overview')),
            cell(const _Menu(Icons.attach_money, '番市首富', '/tinygrail/rich')),
            cell(const _Menu(Icons.attach_money, 'ICO 榜单', '/tinygrail/ico')),
            cell(
              const _Menu(
                Icons.favorite_outline,
                '每周萌王',
                '/tinygrail/top-week',
              ),
            ),
            cell(const _Menu(Icons.looks, '英灵殿', '/tinygrail/valhalla')),
            cell(
              const _Menu(
                Icons.image_aspect_ratio,
                '最新圣殿',
                '/tinygrail/temples',
              ),
            ),
            cell(
              const _Menu(Icons.change_history, '通天塔 (β)', '/tinygrail/star'),
            ),
            if (assets != null)
              SizedBox(
                width: width,
                child: _AssetsBar(user: assets!),
              ),
            cell(
              _Menu(
                Icons.add_circle_outline,
                '我的买单',
                '/tinygrail/bid?type=bid',
                count: bids,
              ),
            ),
            cell(
              _Menu(
                Icons.remove_circle_outline,
                '我的卖单',
                '/tinygrail/bid?type=asks',
                count: asks,
              ),
            ),
            cell(
              _Menu(
                Icons.gavel,
                '我的拍卖',
                '/tinygrail/bid?type=auction',
                count: auction,
              ),
            ),
            cell(const _Menu(Icons.inbox, '我的持仓', '/tinygrail/chara-assets')),
            cell(
              const _Menu(
                Icons.insert_chart_outlined,
                '资金日志',
                '/tinygrail/logs',
              ),
            ),
            cell(const _Menu(Icons.search, '人物搜索', '/tinygrail/search')),
            cell(
              const _Menu(
                Icons.chrome_reader_mode_outlined,
                '游戏指南',
                '/tinygrail/wiki',
              ),
            ),
            cell(
              const _Menu(Icons.workspaces_outline, '我的道具', '/tinygrail/items'),
            ),
          ],
        );
      },
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
  final double width;

  const _MenuCell({required this.menu, required this.width});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final title = menu.count > 0 ? '${menu.title}  ${menu.count}' : menu.title;
    return GestureDetector(
      onTap: () => context.push(menu.route),
      child: Container(
        width: width,
        height: width * 0.38,
        padding: const EdgeInsets.only(left: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: ds.surfaceCard,
          borderRadius: AppRadius.sAll,
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: ds.title.copyWith(fontSize: 18)),
            ),
            Positioned(
              right: -10,
              top: 0,
              bottom: 0,
              child: Icon(
                menu.icon,
                size: 46,
                color: ds.textHint.withValues(alpha: 0.24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 原版 footer: 刮刮乐日榜 · fuyuake · 常驻 · 更多功能
class _TinygrailFooter extends StatelessWidget {
  const _TinygrailFooter();

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final style = ds.caption.copyWith(color: ds.textSecondary);
    Widget link(String label, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Text(label, style: style),
        ),
      );
    }

    final store = SettingsStore.instance;
    final pinned = store.tinygrailEnabled;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        link('刮刮乐日榜', () => context.push('/tinygrail/lottery-rank')),
        Text('·', style: style),
        link(
          'fuyuake',
          () => openExternalUrl('https://fuyuake.top/xsb/chara/all'),
        ),
        Text('·', style: style),
        link(pinned ? '已常驻' : '启用常驻', () {
          store.setTinygrailEnabled(!pinned);
        }),
        Text('·', style: style),
        PopupMenuButton<String>(
          tooltip: '更多功能',
          onSelected: (v) {
            switch (v) {
              case 'advance':
                context.push('/tinygrail/advance');
              case 'group':
                context.push('/rakuen/group/tinygrail');
              case 'clipboard':
                context.push('/tinygrail/clipboard');
              case 'feedback':
                context.push('/timeline/say/19820034');
              case 'qq':
                showBgmToast(context, '1038257138');
              case 'setting':
                context.push('/settings');
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'advance', child: Text('高级功能')),
            PopupMenuItem(value: 'group', child: Text('小组讨论')),
            PopupMenuItem(value: 'clipboard', child: Text('粘贴板')),
            PopupMenuItem(value: 'feedback', child: Text('意见反馈')),
            PopupMenuItem(value: 'qq', child: Text('QQ群')),
            PopupMenuItem(value: 'setting', child: Text('设置')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Text('更多功能', style: style),
          ),
        ),
      ],
    );
  }
}
