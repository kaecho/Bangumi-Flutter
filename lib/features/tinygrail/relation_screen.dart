import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_widgets.dart';

/// 角色关系 (批量角色列表, 参数 ids)
class TinygrailRelationScreen extends ConsumerWidget {
  final List<int> ids;

  const TinygrailRelationScreen({super.key, required this.ids});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(relationProvider(ids));
    return Scaffold(
      appBar: AppBar(title: const Text('角色关系')),
      body: async.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (list) => list.isEmpty
            ? const Empty(text: '暂无角色')
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => CharaTile(
                  chara: list[index],
                  onTap: () => context.push('/tinygrail/chara/${list[index].id}'),
                ),
              ),
      ),
    );
  }
}

final relationProvider = FutureProvider.family<List<TinygrailChara>, List<int>>((ref, ids) async {
  return ref.read(tinygrailApiProvider).fetchCharaByIds(ids);
});
