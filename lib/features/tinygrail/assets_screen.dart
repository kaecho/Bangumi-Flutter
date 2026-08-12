import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_widgets.dart';
import '../../design_system/design_system.dart';

/// 我的资产 (持仓 + ICO)
class TinygrailAssetsScreen extends ConsumerWidget {
  const TinygrailAssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(tinygrailUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('我的资产')),
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
                  FilledButton(onPressed: () => context.push('/tinygrail/login'), child: const Text('去授权')),
                ],
              ),
            );
          }
          return _AssetsBody(user: user);
        },
      ),
    );
  }
}

class _AssetsBody extends ConsumerWidget {
  final TinygrailUser user;

  const _AssetsBody({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myCharaAssetsProvider);
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (_, _) => const Center(child: Text('加载失败')),
      data: (data) {
        final chara = data.chara;
        final ico = data.ico;
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myCharaAssetsProvider),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.nickname, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _Stat(label: '可用资金', value: tgMoney(user.balance)),
                          _Stat(label: '持股总值', value: tgMoney(user.amount)),
                          _Stat(label: '资产总额', value: tgMoney(user.total)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _SectionTitle(title: '我的持仓 (${chara.length})'),
              if (chara.isEmpty)
                const Empty(text: '暂无持仓')
              else
                for (final c in chara)
                  CharaTile(
                    chara: c,
                    onTap: () => context.push('/tinygrail/chara/${c.id}'),
                  ),
              const Divider(),
              _SectionTitle(title: '我的 ICO (${ico.length})'),
              if (ico.isEmpty)
                const Empty(text: '暂无 ICO')
              else
                for (final c in ico)
                  CharaTile(
                    chara: c,
                    onTap: () => context.push('/tinygrail/chara/${c.id}'),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: context.ds.meta),
        ],
      ),
    );
  }
}

final myCharaAssetsProvider =
    FutureProvider<({List<TinygrailChara> chara, List<TinygrailChara> ico})>((ref) async {
  return ref.read(tinygrailApiProvider).fetchMyCharaAssets();
});
