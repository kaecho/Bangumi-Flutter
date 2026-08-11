import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_widgets.dart';

/// 角色资产 (我的持仓 + ICO + 圣殿)
class TinygrailCharaAssetsScreen extends ConsumerWidget {
  const TinygrailCharaAssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(tinygrailUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('角色资产')),
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
          return _CharaAssetsBody(hash: user.hash);
        },
      ),
    );
  }
}

class _CharaAssetsBody extends ConsumerStatefulWidget {
  final String hash;

  const _CharaAssetsBody({required this.hash});

  @override
  ConsumerState<_CharaAssetsBody> createState() => _CharaAssetsBodyState();
}

class _CharaAssetsBodyState extends ConsumerState<_CharaAssetsBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tab,
          tabs: const [Tab(text: '持仓'), Tab(text: 'ICO'), Tab(text: '圣殿')],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _AssetTab(provider: charaAssetsCharaProvider(widget.hash)),
              _AssetTab(provider: charaAssetsIcoProvider(widget.hash)),
              _TempleTab(hash: widget.hash),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssetTab extends ConsumerWidget {
  final FutureProvider<List<TinygrailChara>> provider;

  const _AssetTab({required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (_, _) => const Center(child: Text('加载失败')),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(provider),
        child: list.isEmpty
            ? const Empty(text: '暂无数据')
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final c = list[index];
                  return CharaTile(
                    chara: c,
                    onTap: () => context.push('/tinygrail/chara/${c.id}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('持 ${c.state} 股', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '献祭 ${tgAmount(c.sacrifices)}',
                          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
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

class _TempleTab extends ConsumerWidget {
  final String hash;

  const _TempleTab({required this.hash});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(charaAssetsTempleProvider(hash));
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (_, _) => const Center(child: Text('加载失败')),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(charaAssetsTempleProvider(hash)),
        child: list.isEmpty
            ? const Empty(text: '暂无圣殿')
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = list[index];
                  return ListTile(
                    onTap: () => context.push('/tinygrail/chara/${item.id}'),
                    title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      'Lv.${item.level} · 献祭 ${tgAmount(item.sacrifices)}',
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

final charaAssetsCharaProvider = FutureProvider.family<List<TinygrailChara>, String>((ref, hash) async {
  final data = await ref.read(tinygrailApiProvider).fetchMyCharaAssets();
  return data.chara;
});

final charaAssetsIcoProvider = FutureProvider.family<List<TinygrailChara>, String>((ref, hash) async {
  final data = await ref.read(tinygrailApiProvider).fetchMyCharaAssets();
  return data.ico;
});

final charaAssetsTempleProvider = FutureProvider.family<List<TinygrailTemple>, String>((ref, hash) async {
  return ref.read(tinygrailApiProvider).fetchMyTemple(hash);
});
