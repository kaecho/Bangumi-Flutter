import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/bgm_button.dart';

import '../../shared/widgets/app_bar.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';

/// 初始股份 (ICO 参与者, 参数 icoId 或 monoId)
class TinygrailInitialScreen extends ConsumerWidget {
  final int icoId;

  const TinygrailInitialScreen({super.key, required this.icoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(initialProvider(icoId));
    return Scaffold(
      appBar: BgmAppBar(title: '初始股份'),
      body: async.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (list) => list.isEmpty
            ? const Empty(text: '暂无参与者')
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const BgmHairline(),
                itemBuilder: (context, index) {
                  final item = list[index];
                  return BgmTextRow(
                    leading: Text(
                      '#${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    title: item.nickName.isEmpty ? item.name : item.nickName,
                    subtitle: friendlyTime(item.begin),
                    trailing: Text(
                      '${tgAmount(item.amount)} 股',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

final initialProvider = FutureProvider.family<List<TinygrailInitial>, int>((
  ref,
  icoId,
) async {
  return ref.read(tinygrailApiProvider).fetchInitial(icoId, 1);
});
