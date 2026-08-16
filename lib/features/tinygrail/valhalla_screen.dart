import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';

import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_widgets.dart';

/// 英灵殿
class TinygrailValhallaScreen extends ConsumerStatefulWidget {
  const TinygrailValhallaScreen({super.key});

  @override
  ConsumerState<TinygrailValhallaScreen> createState() =>
      _TinygrailValhallaScreenState();
}

class _TinygrailValhallaScreenState
    extends ConsumerState<TinygrailValhallaScreen> {
  String _sort = 'default';
  String _go = '资产重组';


  @override
  Widget build(BuildContext context) {
    final async = ref.watch(valhallaProvider);
    return Scaffold(
      appBar: BgmAppBar(
        title: '英灵殿',
        actions: [
          TinygrailIconGo(
            value: _go,
            onChanged: (v) => setState(() => _go = v),
          ),
        ],
      ),
      body: async.when(
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
                  onRefresh: () async => ref.invalidate(valhallaProvider),
                  child: list.isEmpty
                      ? const Empty(text: '暂无数据')
                      : ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const BgmHairline(),
                          itemBuilder: (context, index) => CharaTile(
                            chara: list[index],
                            onTap: () => context.push(
                              tinygrailIconGoPath(list[index].id, _go),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final valhallaProvider = FutureProvider<List<TinygrailChara>>((ref) async {
  return ref.read(tinygrailApiProvider).fetchValhalla();
});
