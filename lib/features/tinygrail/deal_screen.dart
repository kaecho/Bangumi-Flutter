import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';

/// 成交记录 (指定角色)
class TinygrailDealScreen extends ConsumerWidget {
  final int monoId;

  const TinygrailDealScreen({super.key, required this.monoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charaAsync = ref.watch(dealCharaProvider(monoId));
    return Scaffold(
      appBar: AppBar(title: const Text('成交记录')),
      body: charaAsync.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (data) {
          final chara = data.chara;
          final logs = data.logs;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(dealCharaProvider(monoId)),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: ListTile(
                    onTap: () => context.push('/tinygrail/chara/$monoId'),
                    leading: CircleAvatar(child: Text(chara.name.isEmpty ? '?' : chara.name.characters.first)),
                    title: Text(chara.name),
                    subtitle: Text(
                      '现价 ¥${tgPrice(chara.current)} · Lv.${chara.level} · 持仓 ${chara.userAmount}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('买入记录', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        if (logs.bidHistory.isEmpty)
                          const Text('暂无', style: TextStyle(fontSize: 12))
                        else
                          for (final log in logs.bidHistory.take(20))
                            _LogLine(log: log, isBid: true),
                        const Divider(height: 20),
                        const Text('卖出记录', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        if (logs.askHistory.isEmpty)
                          const Text('暂无', style: TextStyle(fontSize: 12))
                        else
                          for (final log in logs.askHistory.take(20))
                            _LogLine(log: log, isBid: false),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  final TinygrailLog log;
  final bool isBid;

  const _LogLine({required this.log, required this.isBid});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '¥${tgPrice(log.price)} × ${log.amount}',
            style: TextStyle(
              fontSize: 13,
              color: isBid ? Colors.red : Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            log.time.replaceFirst('T', ' '),
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

final dealCharaProvider =
    FutureProvider.family<({TinygrailChara chara, _DealLogs logs}), int>((ref, monoId) async {
  final api = ref.read(tinygrailApiProvider);
  final chara = await api.fetchChara(monoId);
  final logs = await api.fetchUserLogs(monoId);
  return (
    chara: chara,
    logs: _DealLogs(
      bidHistory: logs.bidHistory,
      askHistory: logs.askHistory,
    ),
  );
});

class _DealLogs {
  final List<TinygrailLog> bidHistory;
  final List<TinygrailLog> askHistory;

  const _DealLogs({required this.bidHistory, required this.askHistory});
}
