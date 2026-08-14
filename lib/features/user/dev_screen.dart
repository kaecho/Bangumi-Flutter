import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/debug/debug_log.dart';
import '../../core/storage/settings_store.dart';
import '../../shared/models/user.dart';

/// 应用版本 (与 pubspec.yaml 保持一致)
const String kAppVersion = '1.0.3+4';

/// 调试日志: 写入 [DebugLog] (内存尾部 + 文件, 调试模式开启时由 ApiClient 持续追加)
void debugLog(String message) {
  unawaited(DebugLog.instance.write(message));
  debugPrint('[debug] $message');
}

/// 开发 (版本信息 + 调试日志)
class DevScreen extends ConsumerStatefulWidget {
  const DevScreen({super.key});

  @override
  ConsumerState<DevScreen> createState() => _DevScreenState();
}

class _DevScreenState extends ConsumerState<DevScreen> {
  String? _logPath;

  @override
  void initState() {
    super.initState();
    unawaited(_collect());
  }

  Future<void> _collect() async {
    final store = ref.read(settingsStoreProvider);
    final user = ref.read(currentUserProvider);
    debugLog('Flutter ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    debugLog('登录: ${user != null ? user.displayName : '未登录'} (${user?.id ?? '-'})');
    debugLog('主题模式: ${store.themeMode.name}, 主题色: #${store.primaryColor.toARGB32().toRadixString(16)}');
    debugLog('小圣杯: ${store.tinygrailEnabled}, 图片质量: ${store.imageQuality}');
    final boxNames = ['settings', 'subject', 'user', 'collection', 'timeline', 'topic', 'rakuen'];
    for (final name in boxNames) {
      try {
        debugLog('缓存 $name: ${Hive.box<dynamic>(name).length} 条');
      } catch (_) {}
    }
    _logPath = await DebugLog.instance.path();
    if (mounted) setState(() {});
  }

  Future<void> _clear() async {
    await DebugLog.instance.clear();
    if (mounted) setState(() {});
  }

  Future<void> _share() async {
    final p = await DebugLog.instance.path();
    if (p == null) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(p)], subject: 'Bangumi 调试日志'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final store = ref.watch(settingsStoreProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('开发'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: '分享日志文件',
            onPressed: _share,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空日志',
            onPressed: _clear,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('版本信息', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
                  const SizedBox(height: 8),
                  Text('应用版本: $kAppVersion'),
                  Text('运行时: ${kDebugMode ? 'Debug' : 'Release'}'),
                  Text('平台: ${Platform.operatingSystem} (${Platform.operatingSystemVersion})'),
                  const SizedBox(height: 4),
                  Text('登录用户: ${user?.displayName ?? '未登录'} (id=${user?.id ?? '-'})'),
                  Text('用户组: ${user == null ? '-' : userGroupText[user.userGroup] ?? '-'}'),
                  const SizedBox(height: 4),
                  Text('主题模式: ${store.themeMode.name}'),
                  Text('主题色: #${store.primaryColor.toARGB32().toRadixString(16).padLeft(8, '0')}'),
                  Text('动态取色: ${store.dynamicColor}'),
                  Text('封面过渡: ${store.coverFadeIn}'),
                  Text('图片质量: ${store.imageQuality}'),
                  Text('小圣杯: ${store.tinygrailEnabled}'),
                  Text('调试模式: ${store.debugLog ? '开' : '关'}'),
                  Text(
                    '日志文件: ${_logPath ?? '尚未生成 (打开调试模式后发起请求才会生成)'}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('调试日志', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
                  const SizedBox(height: 8),
                  if (DebugLog.instance.tail.isEmpty)
                    Text('暂无日志', style: TextStyle(fontSize: 12, color: theme.colorScheme.outline))
                  else
                    for (final line in DebugLog.instance.tail.reversed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          line,
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
