import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';

/// 拍卖 (我的拍卖 + 竞拍)
class TinygrailAuctionScreen extends ConsumerWidget {
  const TinygrailAuctionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myAuctionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('拍卖')),
      body: async.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(myAuctionProvider),
          child: list.isEmpty
              ? const Empty(text: '暂无拍卖记录')
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return ListTile(
                      onTap: () => context.push('/tinygrail/chara/${item.monoId}'),
                      leading: Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '竞拍 ${item.auctionState}人/${item.auctionType}股 · ${_stateText(item.state)}',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      trailing: Text(
                        '${item.amount}股 ¥${tgPrice(item.price)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  String _stateText(int state) => switch (state) {
        1 => '已成功',
        2 => '已失败',
        _ => '拍卖中',
      };
}

final myAuctionProvider = FutureProvider<List<TinygrailAuctionItem>>((ref) async {
  return ref.read(tinygrailApiProvider).fetchMyAuction();
});
