import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刮奖失败: $e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label失败: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final api = ref.read(tinygrailApiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('刮刮乐日榜')),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
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
                      FilledButton.icon(
                        onPressed: _loading ? null : () => _scratch(),
                        icon: const Icon(Icons.celebration_outlined),
                        label: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('环保刮刮乐'),
                      ),
                      OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () => _scratch(fantasy: true),
                        child: const Text('幻想乡刮刮乐'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
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
                      FilledButton.tonal(
                        onPressed: _loading
                            ? null
                            : () => _run('每日签到', api.doBonusDaily),
                        child: const Text('每日签到'),
                      ),
                      FilledButton.tonal(
                        onPressed: _loading
                            ? null
                            : () => _run('每周分红', api.doBonus),
                        child: const Text('每周分红'),
                      ),
                      FilledButton.tonal(
                        onPressed: _loading
                            ? null
                            : () => _run('节日奖励', api.doBonusHoliday),
                        child: const Text('节日奖励'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _ResultView(result: _result),
              ),
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
