import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_widgets.dart';
import '../../design_system/design_system.dart';

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

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('热门榜单'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
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
        children: const [
          _RefineList(),
          _CharaList(type: 'msrc'),
          _CharaList(type: 'mvc'),
          _CharaList(type: 'mrc'),
          _CharaList(type: 'mfc'),
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
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = list[index];
              return ListTile(
                leading: Cover(
                  url: item.cover.replaceFirst('//', 'https://'),
                  width: 40,
                  height: 40,
                  radius: 6,
                ),
                title: Row(
                  children: [
                    Text('${index + 1}', style: context.ds.caption),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '精炼 Lv.${item.refine}',
                      style: context.ds.tiny.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  '@${item.userName.isEmpty ? item.userId : item.userName} · 献祭 ${item.sacrifices}',
                  style: context.ds.meta,
                ),
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

  const _CharaList({required this.type});

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
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final chara = list[index];
                    return CharaTile(
                      chara: chara,
                      onTap: () => context.push('/tinygrail/chara/${chara.id}'),
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
