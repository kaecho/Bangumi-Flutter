import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_widgets.dart';

/// 热门榜单 (移植自原项目 screens/tinygrail/overview)
///
/// 5 tab: 精炼排行 / 最高股息 / 最高市值 / 最大涨幅 / 最大跌幅。
/// 角色 tab 一次拉 400 条 (无服务端分页), 精炼排行走 refine 接口。
class TinygrailOverviewScreen extends ConsumerStatefulWidget {
  const TinygrailOverviewScreen({super.key});

  @override
  ConsumerState<TinygrailOverviewScreen> createState() =>
      _TinygrailOverviewScreenState();
}

class _TinygrailOverviewScreenState
    extends ConsumerState<TinygrailOverviewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 5, vsync: this);
  String _go = '卖出';


  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: '热门榜单',
        actions: [
          TinygrailIconGo(
            value: _go,
            onChanged: (v) => setState(() => _go = v),
          ),
        ],
        bottom: BgmControlledTabStrip(
          controller: _tab,
          scrollable: true,
          tabs: const [
            Tab(text: '精炼排行'),
            Tab(text: '最高股息'),
            Tab(text: '最高市值'),
            Tab(text: '最大涨幅'),
            Tab(text: '最大跌幅'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          const _RefineList(),
          _CharaList(type: 'msrc', go: _go),
          _CharaList(type: 'mvc', go: _go),
          _CharaList(type: 'mrc', go: _go),
          _CharaList(type: 'mfc', go: _go),
        ],
      ),
    );
  }
}

/// 精炼排行 tab
class _RefineList extends ConsumerStatefulWidget {
  const _RefineList();

  @override
  ConsumerState<_RefineList> createState() => _RefineListState();
}

class _RefineListState extends ConsumerState<_RefineList> {
  late Future<List<TinygrailRefine>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(tinygrailApiProvider).fetchRefineRank();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Loading(height: double.infinity);
        }
        final list = snapshot.data ?? const <TinygrailRefine>[];
        if (snapshot.hasError || list.isEmpty) {
          return Empty(text: snapshot.hasError ? '加载失败, 请重试' : '暂无数据');
        }
        return RefreshIndicator(
          onRefresh: () async {
            setState(
              () => _future = ref.read(tinygrailApiProvider).fetchRefineRank(),
            );
            await _future;
          },
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const BgmHairline(),
            itemBuilder: (context, index) {
              final item = list[index];
              return BgmTextRow(
                leading: Cover(
                  url: item.cover.replaceFirst('//', 'https://'),
                  width: 40,
                  height: 40,
                  radius: 6,
                ),
                title: item.name,
                subtitle:
                    '#${index + 1} · 精炼 Lv.${item.refine} · @${item.userName.isEmpty ? item.userId : item.userName} · 献祭 ${item.sacrifices}',
                onTap: () => context.push('/tinygrail/chara/${item.monoId}'),
              );
            },
          ),
        );
      },
    );
  }
}

/// 角色排行 tab (type 见 apiTinygrailRankList)
class _CharaList extends ConsumerStatefulWidget {
  final String type;
  final String go;

  const _CharaList({required this.type, required this.go});

  @override
  ConsumerState<_CharaList> createState() => _CharaListState();
}

class _CharaListState extends ConsumerState<_CharaList> {
  late Future<List<TinygrailChara>> _future;
  String _sort = 'default';

  @override
  void initState() {
    super.initState();
    _future = ref.read(tinygrailApiProvider).fetchList(widget.type);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Loading(height: double.infinity);
        }
        final raw = snapshot.data ?? const <TinygrailChara>[];
        if (snapshot.hasError || raw.isEmpty) {
          return Empty(text: snapshot.hasError ? '加载失败, 请重试' : '暂无数据');
        }
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
                onRefresh: () async {
                  setState(
                    () => _future = ref
                        .read(tinygrailApiProvider)
                        .fetchList(widget.type),
                  );
                  await _future;
                },
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const BgmHairline(),
                  itemBuilder: (context, index) {
                    final chara = list[index];
                    return CharaTile(
                      chara: chara,
                      onTap: () =>
                          context.push(tinygrailIconGoPath(chara.id, widget.go)),
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
