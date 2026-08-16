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

/// 圣星 / 通天塔 (原项目: 全局/持仓 + 条数工具栏)
class TinygrailStarScreen extends ConsumerStatefulWidget {
  const TinygrailStarScreen({super.key});

  @override
  ConsumerState<TinygrailStarScreen> createState() =>
      _TinygrailStarScreenState();
}

class _TinygrailStarScreenState extends ConsumerState<TinygrailStarScreen> {
  bool _holdOnly = false;
  int _limit = 100;
  static const _limits = [24, 100, 200, 300, 400, 500];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(starListProvider(_limit));
    return Scaffold(
      appBar: BgmAppBar(
        title: '通天塔',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: BgmSegmented<bool>(
              values: const [(false, '全局'), (true, '持仓')],
              selected: _holdOnly,
              onSelect: (v) => setState(() => _holdOnly = v),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final n in _limits)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: BgmFilterChip(
                          label: '$n',
                          selected: _limit == n,
                          onTap: () => setState(() => _limit = n),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Loading(),
              error: (_, _) => const Center(child: Text('加载失败')),
              data: (raw) {
                final list = _holdOnly
                    ? raw.where((e) => e.state > 0 || e.userAmount > 0).toList()
                    : raw;
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(starListProvider(_limit)),
                  child: list.isEmpty
                      ? const Empty(text: '暂无数据')
                      : ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const BgmHairline(),
                          itemBuilder: (context, index) {
                            final chara = list[index];
                            return CharaTile(
                              chara: chara,
                              onTap: () =>
                                  context.push('/tinygrail/chara/${chara.id}'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '#${index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '星之力 ${chara.starForces}',
                                    style: context.ds.meta,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final starListProvider = FutureProvider.family<List<TinygrailChara>, int>((
  ref,
  limit,
) async {
  return ref.read(tinygrailApiProvider).fetchStar(1, limit);
});
