import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';
import 'tinygrail_api.dart';

/// 环保刮刮乐 (抽奖榜入口)
class TinygrailLotteryRankScreen extends ConsumerStatefulWidget {
  const TinygrailLotteryRankScreen({super.key});

  @override
  ConsumerState<TinygrailLotteryRankScreen> createState() =>
      _TinygrailLotteryRankScreenState();
}

class _TinygrailLotteryRankScreenState
    extends ConsumerState<TinygrailLotteryRankScreen> {
  bool _loading = false;
  dynamic _result;
  int _count = 0;
  bool _public = true;


  @override
  void initState() {
    super.initState();
    unawaited(_loadCount());
  }

  Future<void> _loadCount() async {
    final count = await ref.read(tinygrailApiProvider).doDailyCount();
    if (!mounted) return;
    setState(() => _count = count);
  }

  Future<void> _scratch({bool fantasy = false}) async {
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(tinygrailApiProvider)
          .doScratch(fantasy: fantasy);
      if (!mounted) return;
      setState(() => _result = result);
      await _loadCount();
    } catch (e) {
      if (!mounted) return;
      showBgmToast(context, '刮奖失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(String label, Future<dynamic> Function() action) async {
    setState(() => _loading = true);
    try {
      final result = await action();
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      showBgmToast(context, '$label失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final api = ref.read(tinygrailApiProvider);
    return Scaffold(
      appBar: BgmAppBar(
        title: '刮刮乐日榜',
        actions: [
          BgmHeaderAction(
            tooltip: '公开状态',
            icon: Text(
              _public ? '公开中' : '匿名中',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            onPressed: () async {
              final ok = await showBgmConfirm(
                context,
                title: '小圣杯助手',
                message: '是否切换你的刮刮乐用户公开状态?',
              );
              if (ok == true && mounted) setState(() => _public = !_public);
            },
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BgmCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  '每日刮刮乐',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '今日已刮 $_count 次',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    BgmButton(
                      '环保刮刮乐',
                      expand: false,
                      loading: _loading,
                      onPressed: _loading ? null : () => _scratch(),
                    ),
                    BgmButton(
                      '幻想乡',
                      type: BgmButtonType.plain,
                      expand: false,
                      onPressed: _loading
                          ? null
                          : () => _scratch(fantasy: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BgmCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '签到 / 分红',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    BgmButton(
                      '每日签到',
                      type: BgmButtonType.ghost,
                      expand: false,
                      onPressed: _loading
                          ? null
                          : () => _run('每日签到', api.doBonusDaily),
                    ),
                    BgmButton(
                      '每周分红',
                      type: BgmButtonType.ghost,
                      expand: false,
                      onPressed: _loading
                          ? null
                          : () => _run('每周分红', api.doBonus),
                    ),
                    BgmButton(
                      '节日奖励',
                      type: BgmButtonType.ghost,
                      expand: false,
                      onPressed: _loading
                          ? null
                          : () => _run('节日奖励', api.doBonusHoliday),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            BgmCard(
              padding: const EdgeInsets.all(16),
              child: _ResultView(result: _result),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final dynamic result;

  const _ResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (result is Map<String, dynamic>) {
      final map = result as Map<String, dynamic>;
      final items = map['Items'] ?? map['Value'];
      if (items is List && items.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '刮奖结果',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in items.take(20))
              if (item is Map<String, dynamic>)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${item['Name'] ?? '-'} × ${item['Amount'] ?? 0}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
          ],
        );
      }
      if (map['Message'] != null) {
        return Text(
          '${map['Message']}',
          style: TextStyle(color: theme.colorScheme.error),
        );
      }
    }
    return Text('$result', style: const TextStyle(fontSize: 13));
  }
}
