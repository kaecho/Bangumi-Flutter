import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
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
  static const _limits = [24, 100, 200, 500];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(starListProvider(_limit));
    return Scaffold(
      appBar: AppBar(
        title: const Text('通天塔'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<bool>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(value: false, label: Text('全局')),
                ButtonSegment(value: true, label: Text('持仓')),
              ],
              selected: {_holdOnly},
              onSelectionChanged: (s) => setState(() => _holdOnly = s.first),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: PopupMenuButton<int>(
                tooltip: '条数',
                onSelected: (v) => setState(() => _limit = v),
                itemBuilder: (_) => [
                  for (final n in _limits)
                    PopupMenuItem(value: n, child: Text('$n 条')),
                ],
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('$_limit 条'),
                ),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
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
                          separatorBuilder: (_, _) => const Divider(height: 1),
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
