import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_widgets.dart';

/// 圣星榜单 (与圣星同源, 独立路由)
class TinygrailStarRankScreen extends ConsumerWidget {
  const TinygrailStarRankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(starRankProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('圣星榜单')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(starRankProvider),
          child: list.isEmpty
              ? const Empty(text: '暂无数据')
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final chara = list[index];
                    return CharaTile(
                      chara: chara,
                      onTap: () => context.push('/tinygrail/chara/${chara.id}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            '星之力 ${chara.starForces}',
                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
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

final starRankProvider = FutureProvider<List<TinygrailChara>>((ref) async {
  return ref.read(tinygrailApiProvider).fetchStar(1, 100);
});
