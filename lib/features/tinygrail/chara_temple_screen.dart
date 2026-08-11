import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_widgets.dart';

/// 角色圣殿 (圣殿列表)
class TinygrailCharaTempleScreen extends ConsumerWidget {
  final int monoId;

  const TinygrailCharaTempleScreen({super.key, required this.monoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_templeProvider(monoId));
    return Scaffold(
      appBar: AppBar(title: const Text('圣殿')),
      body: async.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (list) => list.isEmpty
            ? const Empty(text: '暂无圣殿')
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = list[index];
                  return UserTile(
                    name: item.nickname.isEmpty ? item.name : item.nickname,
                    avatar: item.avatar,
                    subtitle: 'Lv.${item.level} · 献祭 ${tgAmount(item.sacrifices)} · 资产 ${tgMoney(item.assets)}',
                    value: '精炼 ${item.refine}',
                    rank: index + 1,
                  );
                },
              ),
      ),
    );
  }
}

final _templeProvider = FutureProvider.family<List<TinygrailTemple>, int>((ref, monoId) async {
  return ref.read(tinygrailApiProvider).fetchCharaTemple(monoId);
});

/// 角色英灵殿 (可拍卖信息 + 上周拍卖结果)
class TinygrailCharaValhallaScreen extends ConsumerWidget {
  final int monoId;

  const TinygrailCharaValhallaScreen({super.key, required this.monoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_valhallaProvider(monoId));
    return Scaffold(
      appBar: AppBar(title: const Text('英灵殿')),
      body: async.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (data) {
          final logs = data.logs;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: const Text('可拍卖数量'),
                  trailing: Text('${data.amount}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('上周拍卖结果', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (logs.isEmpty)
                        const Text('暂无记录', style: TextStyle(fontSize: 12))
                      else
                        for (final log in logs)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '${log.time} · ${log.amount} 股 · ¥${tgPrice(log.price)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final _valhallaProvider =
    FutureProvider.family<({int amount, List<TinygrailLog> logs}), int>((ref, monoId) async {
  final api = ref.read(tinygrailApiProvider);
  final amount = await api.fetchValhallaChara(monoId);
  final logs = await api.fetchAuctionLastWeek(monoId);
  return (amount: amount, logs: logs);
});
