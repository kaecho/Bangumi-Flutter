import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';

/// 圣殿 (我的圣殿)
class TinygrailTempleScreen extends ConsumerWidget {
  const TinygrailTempleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(tinygrailUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('圣殿')),
      body: userAsync.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (user) {
          if (user == null || user.hash.isEmpty) {
            return const _LoginGate();
          }
          return _MyTempleList(hash: user.hash);
        },
      ),
    );
  }
}

class _LoginGate extends StatelessWidget {
  const _LoginGate();

  @override
  Widget build(BuildContext context) {
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
}

class _MyTempleList extends ConsumerWidget {
  final String hash;

  const _MyTempleList({required this.hash});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myTempleProvider(hash));
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (_, _) => const Center(child: Text('加载失败')),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(myTempleProvider(hash)),
        child: list.isEmpty
            ? const Empty(text: '暂无圣殿, 去献祭建立圣殿吧')
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
                      'Lv.${item.level} · 献祭 ${tgAmount(item.sacrifices)} · 星之力 ${item.userStarForces}',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    trailing: Text('精炼 ${item.refine}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  );
                },
              ),
      ),
    );
  }
}

final myTempleProvider = FutureProvider.family<List<TinygrailTemple>, String>((ref, hash) async {
  return ref.read(tinygrailApiProvider).fetchMyTemple(hash);
});
