import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_widgets.dart';

/// 英灵殿
class TinygrailValhallaScreen extends ConsumerWidget {
  const TinygrailValhallaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(valhallaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('英灵殿')),
      body: async.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(valhallaProvider),
          child: list.isEmpty
              ? const Empty(text: '暂无数据')
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => CharaTile(
                    chara: list[index],
                    onTap: () => context.push('/tinygrail/chara/${list[index].id}'),
                  ),
                ),
        ),
      ),
    );
  }
}

final valhallaProvider = FutureProvider<List<TinygrailChara>>((ref) async {
  return ref.read(tinygrailApiProvider).fetchValhalla();
});
