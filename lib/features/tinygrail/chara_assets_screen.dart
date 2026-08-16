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

/// 角色资产 Extra: {user}的持仓 + IconGo + tabs 总览/人物/圣殿/ICO
class TinygrailCharaAssetsScreen extends ConsumerStatefulWidget {
  final String userName;

  const TinygrailCharaAssetsScreen({super.key, this.userName = ''});

  @override
  ConsumerState<TinygrailCharaAssetsScreen> createState() =>
      _TinygrailCharaAssetsScreenState();
}

class _TinygrailCharaAssetsScreenState
    extends ConsumerState<TinygrailCharaAssetsScreen> {
  String _go = '卖出';

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(tinygrailUserProvider);
    final title = widget.userName.isEmpty ? '我的持仓' : '${widget.userName}的持仓';
    return Scaffold(
      appBar: BgmAppBar(
        title: title,
        actions: [
          TinygrailIconGo(
            value: _go,
            onChanged: (v) => setState(() => _go = v),
          ),
        ],
      ),
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
          return _CharaAssetsBody(hash: user.hash, go: _go);
        },
      ),
    );
  }
}

class _CharaAssetsBody extends ConsumerStatefulWidget {
  final String hash;
  final String go;

  const _CharaAssetsBody({required this.hash, required this.go});

  @override
  ConsumerState<_CharaAssetsBody> createState() => _CharaAssetsBodyState();
}

class _CharaAssetsBodyState extends ConsumerState<_CharaAssetsBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BgmControlledTabStrip(
          controller: _tab,
          scrollable: true,
          tabs: const [
            Tab(text: '总览'),
            Tab(text: '人物'),
            Tab(text: '圣殿'),
            Tab(text: 'ICO'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _AssetTab(
                provider: charaAssetsMergeProvider(widget.hash),
                go: widget.go,
              ),
              _AssetTab(
                provider: charaAssetsCharaProvider(widget.hash),
                go: widget.go,
              ),
              _TempleTab(hash: widget.hash, go: widget.go),
              _AssetTab(
                provider: charaAssetsIcoProvider(widget.hash),
                go: widget.go,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssetTab extends ConsumerStatefulWidget {
  final FutureProvider<List<TinygrailChara>> provider;
  final String go;

  const _AssetTab({required this.provider, required this.go});

  @override
  ConsumerState<_AssetTab> createState() => _AssetTabState();
}

class _AssetTabState extends ConsumerState<_AssetTab> {
  String _sort = 'default';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(widget.provider);
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (_, _) => const Center(child: Text('加载失败')),
      data: (raw) {
        final list = sortTinygrailCharas(raw, _sort);
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: TinygrailSortChip(
                  value: _sort,
                  onChanged: (v) => setState(() => _sort = v),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(widget.provider),
                child: list.isEmpty
                    ? const Empty(text: '暂无数据')
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const BgmHairline(),
                        itemBuilder: (context, index) {
                          final c = list[index];
                          return CharaTile(
                            chara: c,
                            onTap: () => context.push(
                              tinygrailIconGoPath(c.id, widget.go),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '持 ${c.state} 股',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
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
            ),
          ],
        );
      },
    );
  }
}

class _TempleTab extends ConsumerWidget {
  final String hash;
  final String go;

  const _TempleTab({required this.hash, required this.go});

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
                separatorBuilder: (_, _) => const BgmHairline(),
                itemBuilder: (context, index) {
                  final item = list[index];
                  return BgmTextRow(
                    onTap: () => context.push(
                      tinygrailIconGoPath(item.id, go),
                    ),
                    title: item.name,
                    subtitle:
                        'Lv.${item.level} · 献祭 ${tgAmount(item.sacrifices)}',
                    trailing: Text(
                      '精炼 ${item.refine}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

final charaAssetsCharaProvider =
    FutureProvider.family<List<TinygrailChara>, String>((ref, hash) async {
      final data = await ref.read(tinygrailApiProvider).fetchMyCharaAssets();
      return data.chara;
    });

final charaAssetsIcoProvider =
    FutureProvider.family<List<TinygrailChara>, String>((ref, hash) async {
      final data = await ref.read(tinygrailApiProvider).fetchMyCharaAssets();
      return data.ico;
    });

final charaAssetsTempleProvider =
    FutureProvider.family<List<TinygrailTemple>, String>((ref, hash) async {
      return ref.read(tinygrailApiProvider).fetchMyTemple(hash);
    });

final charaAssetsMergeProvider =
    FutureProvider.family<List<TinygrailChara>, String>((ref, hash) async {
      final data = await ref.read(tinygrailApiProvider).fetchMyCharaAssets();
      return [...data.chara, ...data.ico];
    });
