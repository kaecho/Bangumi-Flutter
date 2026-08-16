import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';

/// 每周萌王 (周榜 + 历史)
class TinygrailTopWeekScreen extends ConsumerStatefulWidget {
  const TinygrailTopWeekScreen({super.key});

  @override
  ConsumerState<TinygrailTopWeekScreen> createState() =>
      _TinygrailTopWeekScreenState();
}

class _TinygrailTopWeekScreenState
    extends ConsumerState<TinygrailTopWeekScreen> {
  int _prev = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: '每周萌王',
        actions: [
          BgmHeaderAction(
            tooltip: '我的拍卖',
            icon: const Icon(Icons.gavel, size: 20),
            onPressed: () => context.push('/tinygrail/bid?type=auction'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BgmHeaderAction(
                  tooltip: '上一周',
                  icon: const Icon(Icons.navigate_before, size: 20),
                  onPressed: _prev >= 40
                      ? null
                      : () => setState(() => _prev += 1),
                ),
                Text(
                  _prev == 0 ? '本周' : '前 $_prev 周',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                BgmHeaderAction(
                  tooltip: '下一周',
                  icon: const Icon(Icons.navigate_next, size: 20),
                  onPressed: _prev == 0
                      ? null
                      : () => setState(() => _prev -= 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: _prev == 0
                ? const _TopWeekList()
                : _TopWeekHistory(prev: _prev),
          ),
        ],
      ),
    );
  }
}

class _TopWeekList extends ConsumerWidget {
  const _TopWeekList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(topWeekProvider);
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (_, _) => const Center(child: Text('加载失败')),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(topWeekProvider),
        child: list.isEmpty
            ? const Empty(text: '暂无数据')
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const BgmHairline(),
                itemBuilder: (context, index) =>
                    _TopWeekTile(item: list[index]),
              ),
      ),
    );
  }
}

class _TopWeekHistory extends ConsumerWidget {
  final int prev;

  const _TopWeekHistory({required this.prev});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(topWeekHistoryProvider(prev));
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (_, _) => const Center(child: Text('加载失败')),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(topWeekHistoryProvider(prev)),
        child: list.isEmpty
            ? const Empty(text: '暂无历史记录')
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const BgmHairline(),
                itemBuilder: (context, index) =>
                    _TopWeekTile(item: list[index]),
              ),
      ),
    );
  }
}

class _TopWeekTile extends StatelessWidget {
  final TinygrailTopWeek item;

  const _TopWeekTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return BgmTextRow(
      onTap: () => context.push('/tinygrail/chara/${item.id}'),
      leading: Text(
        '#${item.rank}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      title: item.name,
      subtitle:
          'Lv.${item.level} · 价格 ¥${tgPrice(item.price)} · 股息 ${item.rate.toStringAsFixed(2)}',
      trailing: Text(
        '额外 ${tgAmount(item.extra)}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

final topWeekProvider = FutureProvider<List<TinygrailTopWeek>>((ref) async {
  return ref.read(tinygrailApiProvider).fetchTopWeek();
});

final topWeekHistoryProvider = FutureProvider.family<List<TinygrailTopWeek>, int>(
  (ref, prev) async {
    return ref.read(tinygrailApiProvider).fetchTopWeekHistory(prev);
  },
);
