import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../core/storage/cache.dart';

/// 调试日志存储 (持久化于 hive settings box, 最多保留 200 条)
class LogStore {
  LogStore._();

  static const _kKey = 'debug_logs';
  static const _kMax = 200;

  static Box<dynamic> _box() => Cache.instance.box('settings');

  /// 追加一条日志 (最新在前)
  static Future<void> write(String line) async {
    final box = _box();
    final logs = (box.get(_kKey) as List?)?.cast<String>() ?? <String>[];
    final stamp = DateTime.now().toString().substring(5, 19);
    logs.insert(0, '[$stamp] $line');
    if (logs.length > _kMax) logs.removeRange(_kMax, logs.length);
    await box.put(_kKey, logs);
  }

  static List<String> read() => (_box().get(_kKey) as List?)?.cast<String>() ?? const [];

  static Future<void> clear() => _box().delete(_kKey);
}

/// 日志查看 (移植自原项目 screens/web-view/log)
/// 路由: /log
class LogScreen extends ConsumerWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = LogStore.read();
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志'),
        actions: [
          IconButton(
            tooltip: '清空日志',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              await LogStore.clear();
              if (context.mounted) {
                ref.invalidateSelf();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('日志已清空')),
                );
              }
            },
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(child: Text('暂无日志'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) => Text(
                logs[index],
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.4),
              ),
            ),
    );
  }
}
