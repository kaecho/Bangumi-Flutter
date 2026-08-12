import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import '../../design_system/design_system.dart';

/// 进阶推荐条目 (含第一档买卖价与评分)
class AdvanceItem {
  final TinygrailChara chara;
  final double mark;
  final double firstPrice;
  final int firstAmount;

  const AdvanceItem({
    required this.chara,
    this.mark = 0,
    this.firstPrice = 0,
    this.firstAmount = 0,
  });
}

/// 计算角色股息率 (与原项目 calculateRate 一致)
double tgCalculateRate(double rate, int rank, int stars) {
  if (rank < 501 && rate > 0) return (601 - rank) * 0.005 * rate;
  return stars * 2;
}

/// 进阶玩法通用列表页
class AdvanceListScreen extends ConsumerWidget {
  final String title;
  final FutureProvider<List<AdvanceItem>> provider;
  final String valueLabel;

  const AdvanceListScreen({
    super.key,
    required this.title,
    required this.provider,
    this.valueLabel = '评分',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: async.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(provider),
          child: list.isEmpty
              ? const Empty(text: '暂无推荐, 请先登录或稍后重试')
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = list[index];
                    final chara = item.chara;
                    return ListTile(
                      onTap: () => context.push('/tinygrail/chara/${chara.id}'),
                      leading: Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      title: Text(chara.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '现价 ¥${tgPrice(chara.current)} · Lv.${chara.level} · 股息 ${chara.rate.toStringAsFixed(2)}',
                        style: context.ds.meta,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$valueLabel ${item.mark.toStringAsFixed(1)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (item.firstPrice > 0)
                            Text(
                              '一档 ¥${tgPrice(item.firstPrice)} (${item.firstAmount})',
                              style: context.ds.meta,
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// 买入推荐 (卖出推荐页面实际逻辑: 从市场筛低估)
final advanceAskProvider = FutureProvider<List<AdvanceItem>>((ref) async {
  final api = ref.read(tinygrailApiProvider);
  final items = <TinygrailChara>[];
  for (var i = 0; i < 3; i++) {
    final batch = await api.fetchList('recent', page: i + 1, limit: 80);
    for (final chara in batch) {
      if (chara.asks >= 10 && tgCalculateRate(chara.rate, chara.rank, chara.stars) >= 2) {
        items.add(chara);
      }
    }
  }
  // 深度取第一卖价
  final result = <AdvanceItem>[];
  for (final chara in items) {
    try {
      final depth = await api.fetchDepth(chara.id);
      final asks = depth.asks.where((e) => e.price > 0).toList();
      if (asks.isEmpty) continue;
      final rate = tgCalculateRate(chara.rate, chara.rank, chara.stars);
      final mark = rate / asks.first.price * 100;
      if (mark > 1) {
        result.add(AdvanceItem(
          chara: chara,
          mark: mark,
          firstPrice: asks.first.price,
          firstAmount: asks.first.amount,
        ));
      }
    } catch (_) {}
  }
  result.sort((a, b) => b.mark.compareTo(a.mark));
  return result.take(100).toList();
});

/// 卖出推荐 (从持仓中筛)
final advanceBidProvider = FutureProvider<List<AdvanceItem>>((ref) async {
  final api = ref.read(tinygrailApiProvider);
  final assets = await api.fetchMyCharaAssets();
  final result = <AdvanceItem>[];
  for (final chara in assets.chara) {
    if (chara.current < 20) continue;
    try {
      final depth = await api.fetchDepth(chara.id);
      final bids = depth.bids.where((e) => e.price > 0).toList();
      if (bids.isEmpty) continue;
      final markRate = tgCalculateRate(chara.rate, (chara.rank > 500 ? 500 : chara.rank) == 0 ? 500 : (chara.rank > 500 ? 500 : chara.rank), chara.stars);
      final mark = bids.first.price / (markRate <= 0 ? 1 : markRate);
      result.add(AdvanceItem(
        chara: chara,
        mark: mark,
        firstPrice: bids.first.price,
        firstAmount: bids.first.amount,
      ));
    } catch (_) {}
  }
  result.sort((a, b) => b.mark.compareTo(a.mark));
  return result.take(100).toList();
});

/// 献祭推荐 (从持仓中筛)
final advanceSacrificeProvider = FutureProvider<List<AdvanceItem>>((ref) async {
  final api = ref.read(tinygrailApiProvider);
  final assets = await api.fetchMyCharaAssets();
  final result = <AdvanceItem>[];
  for (final chara in assets.chara) {
    final templeRate = chara.rate * (chara.level + 1) * 0.3;
    if (templeRate > chara.rate) {
      result.add(AdvanceItem(chara: chara, mark: templeRate - chara.rate));
    }
  }
  result.sort((a, b) => b.mark.compareTo(a.mark));
  return result;
});

/// 拍卖推荐 (从英灵殿中筛)
Future<List<AdvanceItem>> _fetchAuctionList(TinygrailApi api, bool useB) async {
  final list = await api.fetchValhalla(limit: 400);
  final result = <AdvanceItem>[];
  for (final chara in list) {
    if (chara.rate < 2 || chara.state < 80) continue;
    if (useB && chara.level < 3) continue;
    final rank = useB ? (chara.rank > 500 ? 500 : chara.rank) : chara.rank;
    if (rank > 500 && !useB) continue;
    final rate = tgCalculateRate(chara.rate, rank == 0 ? 500 : rank, chara.stars);
    final mark = rate / (chara.price <= 0 ? 1 : chara.price) * 100;
    if (mark >= 5) {
      result.add(AdvanceItem(chara: chara, mark: mark, firstPrice: chara.price.toDouble()));
    }
  }
  result.sort((a, b) => b.mark.compareTo(a.mark));
  return result.take(100).toList();
}

/// 拍卖推荐 A
final advanceAuctionProvider = FutureProvider<List<AdvanceItem>>((ref) {
  return _fetchAuctionList(ref.read(tinygrailApiProvider), false);
});

/// 拍卖推荐 B
final advanceAuction2Provider = FutureProvider<List<AdvanceItem>>((ref) {
  return _fetchAuctionList(ref.read(tinygrailApiProvider), true);
});

/// 低价股 (英灵殿中低价)
final advanceStateProvider = FutureProvider<List<AdvanceItem>>((ref) async {
  final api = ref.read(tinygrailApiProvider);
  final list = await api.fetchValhalla(limit: 400);
  final result = <AdvanceItem>[];
  for (final chara in list) {
    if (chara.current > 15) continue;
    try {
      final depth = await api.fetchDepth(chara.id);
      final asks = depth.asks.where((e) => e.price > 0).toList();
      if (asks.isEmpty) continue;
      result.add(AdvanceItem(
        chara: chara,
        mark: asks.first.price,
        firstPrice: asks.first.price,
        firstAmount: asks.first.amount,
      ));
    } catch (_) {}
  }
  result.sort((a, b) => a.mark.compareTo(b.mark));
  return result.take(100).toList();
});
