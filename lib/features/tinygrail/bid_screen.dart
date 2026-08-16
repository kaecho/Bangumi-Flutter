import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_widgets.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/app_bar.dart';

import '../../shared/widgets/bgm_button.dart';
import 'auction_screen.dart';


/// 我的挂单 (买单/卖单, 可撤单)
class TinygrailBidScreen extends ConsumerStatefulWidget {
  final String initialType;

  const TinygrailBidScreen({super.key, this.initialType = 'bid'});

  @override
  ConsumerState<TinygrailBidScreen> createState() => _TinygrailBidScreenState();
}

class _TinygrailBidScreenState extends ConsumerState<TinygrailBidScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(
    length: 3,
    vsync: this,
    initialIndex: switch (widget.initialType) {
      'asks' => 1,
      'auction' => 2,
      _ => 0,
    },
  );

  bool _busy = false;

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _cancel(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(myBidsProvider);
      ref.invalidate(myAsksProvider);
      ref.invalidate(myAuctionProvider);
      if (mounted) {
        showBgmToast(context, '已撤单');
      }
    } catch (e) {
      if (mounted) {
        showBgmToast(context, '撤单失败: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _batchCancel() async {
    final index = _tab.index;
    if (index == 2) {
      final list =
          ref.read(myAuctionProvider).valueOrNull ??
          const <TinygrailAuctionItem>[];
      if (list.isEmpty) {
        showBgmToast(context, '当前没有可取消的委托');
        return;
      }
      final ok = await showBgmConfirm(
        context,
        title: '小圣杯助手',
        message: '确定取消 (${list.length}) 个 (我的拍卖)?',
      );
      if (ok != true || !mounted) return;
      await _cancel(() async {
        final api = ref.read(tinygrailApiProvider);
        for (final item in list) {
          await api.doAuctionCancel(item.id);
        }
        return true;
      });
      return;
    }
    final isBid = index == 0;
    final list = isBid
        ? (ref.read(myBidsProvider).valueOrNull ?? const <TinygrailChara>[])
        : (ref.read(myAsksProvider).valueOrNull ?? const <TinygrailChara>[]);
    if (list.isEmpty) {
      showBgmToast(context, '当前没有可取消的委托');
      return;
    }
    final ok = await showBgmConfirm(
      context,
      title: '小圣杯助手',
      message: '确定取消 (${list.length}) 个 (${isBid ? '我的买单' : '我的卖单'})?',
    );
    if (ok != true || !mounted) return;
    await _cancel(() async {
      final api = ref.read(tinygrailApiProvider);
      for (final item in list) {
        if (isBid) {
          await api.doCancelBid(item.id);
        } else {
          await api.doCancelAsk(item.id);
        }
      }
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: '我的委托',
        actions: [
          BgmHeaderAction(
            tooltip: '批量取消',
            icon: const Icon(Icons.cancel_presentation_outlined),
            onPressed: _busy ? null : _batchCancel,
          ),
        ],
        bottom: BgmControlledTabStrip(
          controller: _tab,
          tabs: const [Text('我的买单'), Text('我的卖单'), Text('我的拍卖')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _OrderList(
            provider: myBidsProvider,
            onCancel: (c) =>
                _cancel(() => ref.read(tinygrailApiProvider).doCancelBid(c.id)),
          ),
          _OrderList(
            provider: myAsksProvider,
            onCancel: (c) =>
                _cancel(() => ref.read(tinygrailApiProvider).doCancelAsk(c.id)),
          ),
          const _AuctionList(),
        ],
      ),
    );
  }
}

class _OrderList extends ConsumerStatefulWidget {
  final FutureProvider<List<TinygrailChara>> provider;
  final void Function(TinygrailChara) onCancel;

  const _OrderList({required this.provider, required this.onCancel});

  @override
  ConsumerState<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends ConsumerState<_OrderList> {
  String _sort = 'default';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(widget.provider);
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (_, _) => const Center(child: Text('请先登录')),
      data: (raw) {
        final list = sortTinygrailCharas(raw, _sort);
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: TinygrailSortChip(
                  value: _sort,
                  onChanged: (v) => setState(() => _sort = v),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(widget.provider),
                child: list.isEmpty
                    ? const Empty(text: '暂无挂单')
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const BgmHairline(),
                        itemBuilder: (context, index) {
                          final c = list[index];
                          return CharaTile(
                            chara: c,
                            onTap: () =>
                                context.push('/tinygrail/chara/${c.id}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '¥${tgPrice(c.price)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${c.amount}股',
                                      style: context.ds.meta,
                                    ),
                                  ],
                                ),
                                BgmTextAction(
                                  '撤单',
                                  onPressed: () => widget.onCancel(c),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AuctionList extends ConsumerWidget {
  const _AuctionList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myAuctionProvider);
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (_, _) => const Center(child: Text('请先登录')),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(myAuctionProvider),
        child: list.isEmpty
            ? const Empty(text: '暂无拍卖记录')
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const BgmHairline(),
                itemBuilder: (context, index) {
                  final item = list[index];
                  final state = switch (item.state) {
                    1 => '已成功',
                    2 => '已失败',
                    _ => '拍卖中',
                  };
                  return BgmTextRow(
                    onTap: () =>
                        context.push('/tinygrail/chara/${item.monoId}'),
                    leading: Text(
                      '#${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    title: item.name,
                    subtitle:
                        '竞拍 ${item.auctionState}人/${item.auctionType}股 · $state',
                    trailing: Text(
                      '${item.amount}股 ¥${tgPrice(item.price)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

final myBidsProvider = FutureProvider<List<TinygrailChara>>((ref) async {
  return ref.read(tinygrailApiProvider).fetchMyBids();
});

final myAsksProvider = FutureProvider<List<TinygrailChara>>((ref) async {
  return ref.read(tinygrailApiProvider).fetchMyAsks();
});
