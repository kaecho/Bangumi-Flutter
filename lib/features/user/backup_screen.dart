import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_notes.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';

/// 本地备份: 导出/导入 设置 + 缓存 (JSON 文件)
class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  static const _kCacheBoxes = [
    'settings',
    'subject',
    'user',
    'collection',
    'timeline',
    'topic',
  ];

  Future<Map<String, dynamic>> _exportJson() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      settings[key] = prefs.get(key);
    }

    final cache = <String, dynamic>{};
    for (final name in _kCacheBoxes) {
      try {
        final box = Hive.box<dynamic>(name);
        cache[name] = box.toMap();
      } catch (_) {
        // 未打开的 box 跳过
      }
    }

    return {
      'app': 'bangumi',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings,
      'cache': cache,
    };
  }

  Future<void> _export(BuildContext context) async {
    try {
      final json = jsonEncode(await _exportJson());
      final dir = await Directory.systemTemp.createTemp('bangumi_backup');
      final file = File(
        '${dir.path}/bangumi_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(json, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          text: 'Bangumi 本地备份',
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      showBgmToast(context, '导出失败: $e');
    }
  }

  Future<void> _import(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showBgmDialog<String>(
      context: context,
      title: '导入备份',
      content: BgmField(
        controller: controller,
        maxLines: 10,
        hintText: '粘贴备份 JSON 内容…',
      ),
      actions: (ctx) => [
        BgmButton(
          '取消',
          type: BgmButtonType.plain,
          expand: false,
          onPressed: () => Navigator.pop(ctx),
        ),
        BgmButton(
          '导入',
          expand: false,
          onPressed: () => Navigator.pop(ctx, controller.text),
        ),
      ],
    );
    if (result == null || result.trim().isEmpty) return;

    try {
      final data = jsonDecode(result) as Map<String, dynamic>;
      final settings = data['settings'] as Map<String, dynamic>? ?? const {};
      final cache = data['cache'] as Map<String, dynamic>? ?? const {};

      final prefs = await SharedPreferences.getInstance();
      for (final entry in settings.entries) {
        final value = entry.value;
        if (value is String) {
          await prefs.setString(entry.key, value);
        } else if (value is bool) {
          await prefs.setBool(entry.key, value);
        } else if (value is num) {
          await prefs.setInt(entry.key, value.toInt());
        } else if (value is List) {
          await prefs.setStringList(
            entry.key,
            value.map((e) => e.toString()).toList(),
          );
        }
      }

      for (final boxEntry in cache.entries) {
        try {
          final box = Hive.box<dynamic>(boxEntry.key);
          final values = boxEntry.value as Map<String, dynamic>? ?? const {};
          for (final kv in values.entries) {
            await box.put(kv.key, kv.value);
          }
        } catch (_) {
          // 未知 box 或不可序列化内容跳过
        }
      }

      if (!context.mounted) return;
      showBgmToast(context, '导入成功, 重启后完全生效');
    } catch (e) {
      if (!context.mounted) return;
      showBgmToast(context, '导入失败: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: BgmAppBar(
        title: '本地备份',
        actions: [
          BgmHeaderAction(
            tooltip: '说明',
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push(backupNotePath()),
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          BgmSettingRow(
            title: '导出备份',
            subtitle: '将设置与缓存导出为 JSON 文件并分享',
            trailing: Icon(Icons.upload_file, color: theme.colorScheme.primary),
            onTap: () => _export(context),
          ),
          BgmSettingRow(
            title: '导入备份',
            subtitle: '粘贴备份 JSON 内容恢复设置与缓存',
            trailing: Icon(Icons.download, color: theme.colorScheme.primary),
            onTap: () => _import(context),
          ),
        ],
      ),
    );
  }
}
