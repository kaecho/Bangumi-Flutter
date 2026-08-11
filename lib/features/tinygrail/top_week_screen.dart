import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';

/// 每周萌王 (周榜 + 历史)
class TinygrailTopWeekScreen extends ConsumerStatefulWidget {
  const TinygrailTopWeekScreen({super.key});

  @override
  ConsumerState<TinygrailTopWeekScreen> createState() => _TinygrailTopWeekScreenState();
}

class _TinygrailTopWeekScreenState extends ConsumerState<TinygrailTopWeekScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('每周萌王'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: '本周'), Tab(text: '历史')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _TopWeekList(),
          _TopWeekHistory(),
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
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => _TopWeekTile(item: list[index]),
              ),
      ),
    );
  }
}

class _TopWeekHistory extends ConsumerWidget {
  const _TopWeekHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(topWeekHistoryProvider);
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (_, _) => const Center(child: Text('加载失败')),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(topWeekHistoryProvider),
        child: list.isEmpty
            ? const Empty(text: '暂无历史记录')
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => _TopWeekTile(item: list[index]),
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
    final theme = Theme.of(context);
    return ListTile(
      onTap: () => context.push('/tinygrail/chara/${item.id}'),
      leading: Text('#${item.rank}', style: const TextStyle(fontWeight: FontWeight.w700)),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        'Lv.${item.level} · 价格 ¥${tgPrice(item.price)} · 股息 ${item.rate.toStringAsFixed(2)}',
        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
      ),
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

final topWeekHistoryProvider = FutureProvider<List<TinygrailTopWeek>>((ref) async {
  return ref.read(tinygrailApiProvider).fetchTopWeekHistory(1);
});
