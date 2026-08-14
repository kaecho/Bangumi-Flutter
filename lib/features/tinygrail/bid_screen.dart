import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_widgets.dart';
import '../../design_system/design_system.dart';

/// 我的挂单 (买单/卖单, 可撤单)
class TinygrailBidScreen extends ConsumerStatefulWidget {
  const TinygrailBidScreen({super.key});

  @override
  ConsumerState<TinygrailBidScreen> createState() => _TinygrailBidScreenState();
}

class _TinygrailBidScreenState extends ConsumerState<TinygrailBidScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已撤单')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('撤单失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _batchCancel() async {
    final isBid = _tab.index == 0;
    final list = isBid
        ? (ref.read(myBidsProvider).valueOrNull ?? const <TinygrailChara>[])
        : (ref.read(myAsksProvider).valueOrNull ?? const <TinygrailChara>[]);
    if (list.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前没有可取消的委托')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('小圣杯助手'),
        content: Text('确定取消 (${list.length}) 个 (${isBid ? '买单' : '卖单'})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
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
      appBar: AppBar(
        title: const Text('我的委托'),
        actions: [
          IconButton(
            tooltip: '批量取消',
            icon: const Icon(Icons.cancel_presentation_outlined),
            onPressed: _busy ? null : _batchCancel,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '买单'),
            Tab(text: '卖单'),
          ],
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
                        separatorBuilder: (_, _) => const Divider(height: 1),
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
                                TextButton(
                                  onPressed: () => widget.onCancel(c),
                                  child: const Text(
                                    '撤单',
                                    style: TextStyle(fontSize: 11),
                                  ),
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

final myBidsProvider = FutureProvider<List<TinygrailChara>>((ref) async {
  return ref.read(tinygrailApiProvider).fetchMyBids();
});

final myAsksProvider = FutureProvider<List<TinygrailChara>>((ref) async {
  return ref.read(tinygrailApiProvider).fetchMyAsks();
});
