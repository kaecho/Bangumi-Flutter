import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/display.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';

/// 角色详情 (K线 + 深度 + 买卖 + 奖池 + 交易记录)
class TinygrailCharaScreen extends ConsumerWidget {
  final int monoId;

  const TinygrailCharaScreen({super.key, required this.monoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charaAsync = ref.watch(_charaProvider(monoId));
    return Scaffold(
      appBar: BgmAppBar(
        title: '角色详情',
        actions: [
          BgmHeaderAction(
            tooltip: '成交记录',
            icon: const Icon(Icons.attach_money),
            onPressed: () => context.push('/tinygrail/deal/$monoId'),
          ),
          BgmHeaderAction(
            tooltip: '交易大厅',
            icon: const Icon(Icons.waterfall_chart),
            onPressed: () => context.push('/tinygrail/trade'),
          ),
          BgmHeaderAction(
            tooltip: '外部查看',
            icon: const Icon(Icons.link),
            onPressed: () =>
                openExternalUrl('https://fuyuake.top/xsb/chara/$monoId'),
          ),
          BgmHeaderAction(
            tooltip: '图集',
            icon: const Icon(Icons.image_outlined),
            onPressed: () => context.push('/pic'),
          ),
        ],
      ),

      body: charaAsync.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) =>
            BgmRetry(onRetry: () => ref.invalidate(_charaProvider(monoId))),
        data: (data) {
          final chara = data.chara;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_charaProvider(monoId)),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _Header(chara: chara),
                const SizedBox(height: 8),
                _ActionBar(monoId: monoId, chara: chara),
                const SizedBox(height: 8),
                _PriceChart(monoId: monoId),
                const SizedBox(height: 8),
                _DepthView(monoId: monoId),
                const SizedBox(height: 8),
                _PoolView(monoId: monoId),
                const SizedBox(height: 8),
                _TempleLink(monoId: monoId),
                const SizedBox(height: 8),
                _LogsView(monoId: monoId),
              ],
            ),
          );
        },
      ),
    );
  }
}

final _charaProvider =
    FutureProvider.family<({TinygrailChara chara, int pool}), int>((
      ref,
      monoId,
    ) async {
      final api = ref.read(tinygrailApiProvider);
      final chara = await api.fetchChara(monoId);
      final pool = await api.fetchPool(monoId);
      return (chara: chara, pool: pool);
    });

class _Header extends StatelessWidget {
  final TinygrailChara chara;

  const _Header({required this.chara});

  @override
  Widget build(BuildContext context) {
    final color = chara.fluctuation < 0
        ? context.ds.fall
        : chara.fluctuation > 0
        ? context.ds.rise
        : context.ds.textPrimary;
    final icon = chara.icon.replaceFirst('//', 'https://');
    return BgmCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Cover(
            url: icon,
            width: 56,
            height: 56,
            radius: 8,
            placeholder: Container(
              width: 56,
              height: 56,
              color: context.ds.textHint.withValues(alpha: 0.12),
              alignment: Alignment.center,
              child: Text(
                chara.name.isEmpty ? '?' : chara.name.characters.first,
                style: TextStyle(color: context.ds.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chara.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lv.${chara.level} · 发行 ${tgAmount(chara.total)} · 股东 ${chara.users}',
                  style: context.ds.caption,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${tgPrice(chara.current)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                tgFluctuation(chara.fluctuation),
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final int monoId;
  final TinygrailChara chara;

  const _ActionBar({required this.monoId, required this.chara});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        BgmButton(
          '买入',
          expand: false,
          onPressed: () => _showTradeSheet(context, isBid: true),
        ),
        BgmButton(
          '卖出',
          type: BgmButtonType.ghost,
          expand: false,
          onPressed: () => _showTradeSheet(context, isBid: false),
        ),
        BgmButton(
          '董事会',
          type: BgmButtonType.plain,
          expand: false,
          onPressed: () =>
              context.push('/tinygrail/initial?icoId=${chara.icoId}'),
        ),
        BgmButton(
          '献祭',
          type: BgmButtonType.plain,
          expand: false,
          onPressed: () => _SacrificeSheet.show(context, monoId),
        ),
      ],
    );
  }

  void _showTradeSheet(BuildContext context, {required bool isBid}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _TradeSheet(monoId: monoId, isBid: isBid, current: chara.current),
    );
  }
}

/// 买卖弹层
class _TradeSheet extends ConsumerStatefulWidget {
  final int monoId;
  final bool isBid;
  final int current;

  const _TradeSheet({
    required this.monoId,
    required this.isBid,
    required this.current,
  });

  @override
  ConsumerState<_TradeSheet> createState() => _TradeSheetState();
}

class _TradeSheetState extends ConsumerState<_TradeSheet> {
  late int _price;
  int _amount = 100;
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _price = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isBid ? '买入挂单' : '卖出挂单',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '价格',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              BgmHeaderAction(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () =>
                    setState(() => _price = (_price - 1).clamp(0, 1 << 30)),
              ),
              Expanded(
                child: BgmField(
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: '$_price'),
                  textAlign: TextAlign.center,
                  onChanged: (v) =>
                      setState(() => _price = int.tryParse(v) ?? 0),
                ),
              ),
              BgmHeaderAction(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => _price = _price + 1),
              ),
              const SizedBox(width: 8),
              Text(
                '¥${tgPrice(_price)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '数量',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              BgmHeaderAction(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(
                  () => _amount = (_amount - 100).clamp(100, 1 << 30),
                ),
              ),
              Expanded(
                child: BgmField(
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: '$_amount'),
                  textAlign: TextAlign.center,
                  onChanged: (v) =>
                      setState(() => _amount = int.tryParse(v) ?? 0),
                ),
              ),
              BgmHeaderAction(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => _amount = _amount + 100),
              ),
              const SizedBox(width: 8),
              Text('合计 ¥${tgMoney(_price * _amount)}'),
            ],
          ),
          const SizedBox(height: 16),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _message!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          BgmButton(
            widget.isBid ? '确认买入' : '确认卖出',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_price <= 0 || _amount <= 0) {
      setState(() => _message = '请输入有效的价格和数量');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final api = ref.read(tinygrailApiProvider);
      final ok = widget.isBid
          ? await api.doBid(widget.monoId, _price, _amount)
          : await api.doAsk(widget.monoId, _price, _amount);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        setState(() => _message = '下单失败');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

final _klineProvider = FutureProvider.family<List<TinygrailKline>, int>((
  ref,
  monoId,
) async {
  return ref.read(tinygrailApiProvider).fetchKline(monoId);
});

class _PriceChart extends ConsumerWidget {
  final int monoId;

  const _PriceChart({required this.monoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final klineAsync = ref.watch(_klineProvider(monoId));
    return BgmCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '价格走势 (K线收盘价)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          klineAsync.when(
            loading: () => const SizedBox(height: 180, child: Loading()),
            error: (_, _) => const SizedBox(
              height: 180,
              child: Center(child: Text('图表加载失败')),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const SizedBox(
                  height: 180,
                  child: Center(child: Text('暂无行情数据')),
                );
              }
              return SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    minY: list
                        .map((e) => e.low)
                        .reduce((a, b) => a < b ? a : b)
                        .toDouble(),
                    maxY: list
                        .map((e) => e.high)
                        .reduce((a, b) => a > b ? a : b)
                        .toDouble(),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: theme.colorScheme.outlineVariant,
                        strokeWidth: 0.5,
                      ),
                    ),
                    titlesData: const FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < list.length; i++)
                            FlSpot(
                              i.toDouble(),
                              (list[i].price / 100).toDouble(),
                            ),
                        ],
                        isCurved: false,
                        color: theme.colorScheme.primary,
                        barWidth: 1.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

final _depthProvider = FutureProvider.family<TinygrailDepth, int>((
  ref,
  monoId,
) async {
  return ref.read(tinygrailApiProvider).fetchDepth(monoId);
});

class _DepthView extends ConsumerWidget {
  final int monoId;

  const _DepthView({required this.monoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final depthAsync = ref.watch(_depthProvider(monoId));
    return BgmCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '盘口深度',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          depthAsync.when(
            loading: () => const SizedBox(height: 100, child: Loading()),
            error: (_, _) => const SizedBox(
              height: 100,
              child: Center(child: Text('深度加载失败')),
            ),
            data: (depth) {
              final rows = <Widget>[];
              for (final ask in depth.asks.reversed.take(5).toList().reversed) {
                rows.add(
                  _DepthRow(price: ask.price, amount: ask.amount, isBid: false),
                );
              }
              rows.add(
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '当前价 ¥${tgPrice(ref.watch(_charaProvider(monoId)).valueOrNull?.chara.current ?? 0)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              );
              for (final bid in depth.bids.take(5)) {
                rows.add(
                  _DepthRow(price: bid.price, amount: bid.amount, isBid: true),
                );
              }
              if (rows.isEmpty) rows.add(const Center(child: Text('暂无盘口')));
              return Column(children: rows);
            },
          ),
        ],
      ),
    );
  }
}

class _DepthRow extends StatelessWidget {
  final double price;
  final int amount;
  final bool isBid;

  const _DepthRow({
    required this.price,
    required this.amount,
    required this.isBid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              price == 0 ? '--' : '¥${tgPrice((price * 100).round())}',
              style: TextStyle(
                color: isBid ? context.ds.rise : context.ds.fall,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: 0.5,
              minHeight: 6,
              color: isBid
                  ? context.ds.rise.withValues(alpha: 0.5)
                  : context.ds.fall.withValues(alpha: 0.5),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(width: 8),
          Text('$amount', style: context.ds.caption),
        ],
      ),
    );
  }
}

final _poolProvider = FutureProvider.family<int, int>((ref, monoId) async {
  return ref.read(tinygrailApiProvider).fetchPool(monoId);
});

class _PoolView extends ConsumerWidget {
  final int monoId;

  const _PoolView({required this.monoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final poolAsync = ref.watch(_poolProvider(monoId));
    return BgmActionRow(
      leading: Icon(Icons.pool, color: theme.colorScheme.primary),
      title: '奖池',
      trailing: poolAsync.when(
        loading: () => const BgmSpinner(size: 20),
        error: (_, _) => const Text('-'),
        data: (pool) => Text(
          '¥${tgMoney(pool)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TempleLink extends StatelessWidget {
  final int monoId;

  const _TempleLink({required this.monoId});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BgmActionRow(
            leading: const Icon(Icons.temple_buddhist_outlined),
            title: '圣殿',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/tinygrail/chara/$monoId/temple'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: BgmActionRow(
            leading: const Icon(Icons.account_balance_outlined),
            title: '英灵殿',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/tinygrail/chara/$monoId/valhalla'),
          ),
        ),
      ],
    );
  }
}

/// 交易记录 (我的挂单 + 成交历史)
class _LogsView extends ConsumerWidget {
  final int monoId;

  const _LogsView({required this.monoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final logsAsync = ref.watch(_userLogsProvider(monoId));
    return BgmCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '我的交易记录',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          logsAsync.when(
            loading: () => const SizedBox(height: 80, child: Loading()),
            error: (_, _) => const SizedBox(
              height: 80,
              child: Center(child: Text('请先登录后查看')),
            ),
            data: (logs) {
              final rows = <Widget>[
                _LogRow(
                  label: '我的买单',
                  items: logs.bids,
                  cancelId: (id) =>
                      ref.read(tinygrailApiProvider).doCancelBid(id),
                ),
                _LogRow(
                  label: '我的卖单',
                  items: logs.asks,
                  cancelId: (id) =>
                      ref.read(tinygrailApiProvider).doCancelAsk(id),
                ),
                _LogRow(
                  label: '成交记录',
                  items: [...logs.bidHistory, ...logs.askHistory],
                ),
              ];
              return Column(children: rows);
            },
          ),
        ],
      ),
    );
  }
}

final _userLogsProvider =
    FutureProvider.family<
      ({
        List<TinygrailLog> bids,
        List<TinygrailLog> asks,
        List<TinygrailLog> bidHistory,
        List<TinygrailLog> askHistory,
      }),
      int
    >((ref, monoId) async {
      final api = ref.read(tinygrailApiProvider);
      try {
        final logs = await api.fetchUserLogs(monoId);
        return (
          bids: logs.bids,
          asks: logs.asks,
          bidHistory: logs.bidHistory,
          askHistory: logs.askHistory,
        );
      } catch (_) {
        return (
          bids: <TinygrailLog>[],
          asks: <TinygrailLog>[],
          bidHistory: <TinygrailLog>[],
          askHistory: <TinygrailLog>[],
        );
      }
    });

class _LogRow extends StatelessWidget {
  final String label;
  final List<TinygrailLog> items;
  final Future<bool> Function(int id)? cancelId;

  const _LogRow({required this.label, required this.items, this.cancelId});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text('$label: -', style: context.ds.caption),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            '$label:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        for (final item in items.take(8))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '¥${tgPrice(item.price)} × ${item.amount}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(friendlyTime(item.time), style: context.ds.meta),
                if (cancelId != null)
                  BgmTextAction('撤单', onPressed: () => cancelId!(item.id)),
              ],
            ),
          ),
      ],
    );
  }
}

class _SacrificeSheet extends ConsumerStatefulWidget {
  final int monoId;

  const _SacrificeSheet({required this.monoId});

  static void show(BuildContext context, int monoId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SacrificeSheet(monoId: monoId),
    );
  }

  @override
  ConsumerState<_SacrificeSheet> createState() => _SacrificeSheetState();
}

class _SacrificeSheetState extends ConsumerState<_SacrificeSheet> {
  int _amount = 100;
  bool _sale = false;
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(tinygrailApiProvider)
          .doSacrifice(widget.monoId, _amount, _sale);
      if (!mounted) return;
      Navigator.of(context).pop();
      showBgmToast(context, '献祭成功');
    } catch (e) {
      if (!mounted) return;
      showBgmToast(context, '献祭失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '资产重组 / 献祭',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          BgmField(
            keyboardType: TextInputType.number,
            labelText: '数量',
            controller: TextEditingController(text: '$_amount'),
            onChanged: (v) => _amount = int.tryParse(v) ?? 0,
          ),
          BgmSettingRow(
            title: '股权融资 (出售)',
            trailing: BgmSwitch(
              value: _sale,
              onChanged: (v) => setState(() => _sale = v),
            ),
          ),

          Align(
            alignment: Alignment.centerRight,
            child: BgmButton(
              '确认献祭',
              expand: false,
              loading: _loading,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}
