import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_widgets.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已撤单')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('撤单失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的挂单'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: '买单'), Tab(text: '卖单')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _OrderList(
            provider: myBidsProvider,
            onCancel: (c) => _cancel(() => ref.read(tinygrailApiProvider).doCancelBid(c.id)),
          ),
          _OrderList(
            provider: myAsksProvider,
            onCancel: (c) => _cancel(() => ref.read(tinygrailApiProvider).doCancelAsk(c.id)),
          ),
        ],
      ),
    );
  }
}

class _OrderList extends ConsumerWidget {
  final FutureProvider<List<TinygrailChara>> provider;
  final void Function(TinygrailChara) onCancel;

  const _OrderList({required this.provider, required this.onCancel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (_, _) => const Center(child: Text('请先登录')),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(provider),
        child: list.isEmpty
            ? const Empty(text: '暂无挂单')
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final c = list[index];
                  return CharaTile(
                    chara: c,
                    onTap: () => context.push('/tinygrail/chara/${c.id}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('¥${tgPrice(c.price)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('${c.amount}股', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                        TextButton(onPressed: () => onCancel(c), child: const Text('撤单', style: TextStyle(fontSize: 11))),
                      ],
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
