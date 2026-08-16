import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_widgets.dart';
import '../../design_system/design_system.dart';

/// 献祭 (资产重组): 我的角色列表 + 献祭/星之力操作
class TinygrailSacrificeScreen extends ConsumerWidget {
  const TinygrailSacrificeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(tinygrailUserProvider);
    return Scaffold(
      appBar: const BgmAppBar(title: '资产重组'),
      body: userAsync.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (user) {
          if (user == null || user.hash.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('请先授权登录小圣杯'),
                  const SizedBox(height: 8),
                  BgmButton(
                    '去授权',
                    expand: false,
                    onPressed: () => context.push('/tinygrail/login'),
                  ),
                ],
              ),
            );
          }
          return _SacrificeBody(hash: user.hash);
        },
      ),
    );
  }
}

class _SacrificeBody extends ConsumerWidget {
  final String hash;

  const _SacrificeBody({required this.hash});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sacrificeProvider(hash));
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (_, _) => const Center(child: Text('加载失败')),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(sacrificeProvider(hash)),
        child: list.isEmpty
            ? const Empty(text: '暂无持仓角色')
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const BgmHairline(),
                itemBuilder: (context, index) {
                  final c = list[index];
                  return CharaTile(
                    chara: c,
                    onTap: () => context.push('/tinygrail/chara/${c.id}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '持 ${c.state} 股',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '献祭 ${tgAmount(c.sacrifices)}',
                          style: context.ds.meta,
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

final sacrificeProvider = FutureProvider.family<List<TinygrailChara>, String>((
  ref,
  hash,
) async {
  return ref.read(tinygrailApiProvider).fetchCharaAll(hash);
});
