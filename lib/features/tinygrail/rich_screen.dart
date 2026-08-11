import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_widgets.dart';

/// 富豪榜
class TinygrailRichScreen extends ConsumerWidget {
  const TinygrailRichScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(richProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('富豪榜')),
      body: async.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(richProvider),
          child: list.isEmpty
              ? const Empty(text: '暂无数据')
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return UserTile(
                      name: item.nickname.isEmpty ? item.userId : item.nickname,
                      avatar: item.avatar,
                      subtitle: '现金 ${tgMoney(item.assets)} · 总资产 ${tgMoney(item.total)}',
                      value: tgMoney(item.total),
                      rank: item.rank,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

final richProvider = FutureProvider<List<TinygrailRich>>((ref) async {
  return ref.read(tinygrailApiProvider).fetchRich(1, 400);
});
