import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import '../../design_system/design_system.dart';

/// 圣殿列表 (最近圣殿)
class TinygrailTemplesScreen extends ConsumerWidget {
  const TinygrailTemplesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(templesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('圣殿列表')),
      body: async.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(templesProvider),
          child: list.isEmpty
              ? const Empty(text: '暂无圣殿')
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return ListTile(
                      onTap: () => context.push('/tinygrail/chara/${item.id}'),
                      leading: Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${item.nickname} · Lv.${item.level} · 献祭 ${tgAmount(item.sacrifices)}',
                        style: context.ds.meta,
                      ),
                      trailing: Text(tgMoney(item.assets), style: const TextStyle(fontWeight: FontWeight.w600)),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

final templesProvider = FutureProvider<List<TinygrailTemple>>((ref) async {
  return ref.read(tinygrailApiProvider).fetchTempleLast();
});
