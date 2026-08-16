import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';

import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import '../../design_system/design_system.dart';

/// 成交记录 (指定角色)
class TinygrailDealScreen extends ConsumerWidget {
  final int monoId;

  const TinygrailDealScreen({super.key, required this.monoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charaAsync = ref.watch(dealCharaProvider(monoId));
    return Scaffold(
      appBar: BgmAppBar(
        title: charaAsync.maybeWhen(
          data: (data) => data.chara.name.isEmpty ? '成交记录' : data.chara.name,
          orElse: () => '成交记录',
        ),
        actions: [
          BgmHeaderAction(
            tooltip: '资产重组',
            icon: const Icon(Icons.workspaces_outline),
            onPressed: () => context.push('/tinygrail/chara/$monoId'),
          ),
          BgmHeaderAction(
            tooltip: 'K线',
            icon: const Icon(Icons.waterfall_chart),
            onPressed: () => context.push('/tinygrail/chara/$monoId'),
          ),
        ],
      ),
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
                BgmTextRow(
                  onTap: () => context.push('/tinygrail/chara/$monoId'),
                  title: chara.name,
                  subtitle:
                      '现价 ¥${tgPrice(chara.current)} · Lv.${chara.level} · 持仓 ${chara.userAmount}',
                ),
                const SizedBox(height: 8),
                BgmCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '买入记录',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      if (logs.bidHistory.isEmpty)
                        const Text('暂无', style: TextStyle(fontSize: 12))
                      else
                        for (final log in logs.bidHistory.take(20))
                          _LogLine(log: log, isBid: true),
                      const BgmHairline(),

                      const Text(
                        '卖出记录',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      if (logs.askHistory.isEmpty)
                        const Text('暂无', style: TextStyle(fontSize: 12))
                      else
                        for (final log in logs.askHistory.take(20))
                          _LogLine(log: log, isBid: false),
                    ],
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
              color: isBid ? context.ds.rise : context.ds.fall,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(log.time.replaceFirst('T', ' '), style: context.ds.meta),
        ],
      ),
    );
  }
}

final dealCharaProvider =
    FutureProvider.family<({TinygrailChara chara, _DealLogs logs}), int>((
      ref,
      monoId,
    ) async {
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
