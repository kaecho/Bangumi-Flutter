import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/display.dart';

import '../../design_system/design_system.dart';
import 'origin_utils.dart';

/// 源头类型
const kOriginTypes = [
  ('anime', '动画'),
  ('hanime', '里番'),
  ('manga', '漫画'),
  ('wenku', '文库'),
  ('music', '音乐'),
  ('game', '游戏'),
  ('real', '三次元'),
];

/// 源头条目
class OriginItem {
  final String uuid;
  final String name;
  final String url;
  final bool active;

  const OriginItem({
    required this.uuid,
    required this.name,
    required this.url,
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'name': name,
    'url': url,
    'active': active,
  };

  factory OriginItem.fromJson(Map<String, dynamic> json) => OriginItem(
    uuid: json['uuid'] as String? ?? '',
    name: json['name'] as String? ?? '',
    url: json['url'] as String? ?? '',
    active: (json['active'] as num?)?.toInt() != 0,
  );
}

/// 源头设置 (每个类型维护自定义数据源列表, 本地持久化)
class OriginStore {
  static const _key = 'setting_origin_custom';

  Future<Map<String, List<OriginItem>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries)
          e.key: (e.value as List)
              .map(
                (item) =>
                    OriginItem.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, List<OriginItem>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        for (final e in data.entries)
          e.key: [for (final item in e.value) item.toJson()],
      }),
    );
  }
}

/// 源头设置
class OriginSettingScreen extends ConsumerStatefulWidget {
  const OriginSettingScreen({super.key});

  @override
  ConsumerState<OriginSettingScreen> createState() =>
      _OriginSettingScreenState();
}

class _OriginSettingScreenState extends ConsumerState<OriginSettingScreen> {
  final _store = OriginStore();
  Map<String, List<OriginItem>> _data = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _store.load();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    await _store.save(_data);
    ref.invalidate(originConfigProvider);
  }

  Future<void> _edit(String type, [OriginItem? item]) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final urlCtrl = TextEditingController(text: item?.url ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? '添加源头' : '编辑源头'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(labelText: '网址'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || urlCtrl.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved != true) return;

    setState(() {
      final list = [...?_data[type]];
      if (item == null) {
        list.add(
          OriginItem(
            uuid: DateTime.now().microsecondsSinceEpoch.toString(),
            name: nameCtrl.text.trim(),
            url: urlCtrl.text.trim(),
          ),
        );
      } else {
        final index = list.indexWhere((e) => e.uuid == item.uuid);
        if (index >= 0) {
          list[index] = OriginItem(
            uuid: item.uuid,
            name: nameCtrl.text.trim(),
            url: urlCtrl.text.trim(),
            active: item.active,
          );
        }
      }
      _data = {..._data, type: list};
    });
    await _save();
  }

  Future<void> _remove(String type, String uuid) async {
    setState(() {
      _data = {
        ..._data,
        type: [...?_data[type]].where((e) => e.uuid != uuid).toList(),
      };
    });
    await _save();
  }

  Future<void> _toggle(String type, String uuid, bool active) async {
    setState(() {
      _data = {
        ..._data,
        type: [
          for (final e in _data[type] ?? const <OriginItem>[])
            if (e.uuid == uuid)
              OriginItem(uuid: e.uuid, name: e.name, url: e.url, active: active)
            else
              e,
        ],
      };
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('自定义源头'),
        actions: [
          IconButton(
            tooltip: '说明',
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push('/tips'),
          ),
        ],
      ),

      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('自定义数据源, 供条目页跳转使用', style: context.ds.caption),
                ),
                for (final (type, label) in kOriginTypes)
                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.add),
                            tooltip: '添加',
                            onPressed: () => _edit(type),
                          ),
                        ),
                        for (final item in _data[type] ?? const <OriginItem>[])
                          SwitchListTile(
                            title: Text(
                              item.name,
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              item.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            value: item.active,
                            onChanged: (v) => _toggle(type, item.uuid, v),
                            secondary: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  onPressed: () => openExternalUrl(item.url),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  onPressed: () => _edit(type, item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => _remove(type, item.uuid),
                                ),
                              ],
                            ),
                          ),
                        if ((_data[type] ?? const []).isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              '暂无源头',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
