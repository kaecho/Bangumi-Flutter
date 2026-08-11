import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// 操作记录项 (本地快捷操作, 移植自原项目 screens/user/actions)
class ActionItem {
  final String uuid;
  final String name;
  final String url;
  final bool active;

  const ActionItem({
    required this.uuid,
    required this.name,
    required this.url,
    this.active = true,
  });

  Map<String, dynamic> toJson() => {'uuid': uuid, 'name': name, 'url': url, 'active': active};

  factory ActionItem.fromJson(Map<String, dynamic> json) => ActionItem(
        uuid: json['uuid'] as String? ?? '',
        name: json['name'] as String? ?? '',
        url: json['url'] as String? ?? '',
        active: (json['active'] as num?)?.toInt() != 0,
      );
}

/// 操作记录状态 (hive 持久化)
class ActionsController extends Notifier<List<ActionItem>> {
  static const _boxName = 'settings';
  static const _key = 'actions';

  @override
  List<ActionItem> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final box = await Hive.openBox<dynamic>(_boxName);
    final raw = box.get(_key) as String?;
    if (raw == null) return;
    try {
      state = (jsonDecode(raw) as List)
          .map((e) => ActionItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {}
  }

  Future<void> _save() async {
    final box = await Hive.openBox<dynamic>(_boxName);
    await box.put(_key, jsonEncode([for (final item in state) item.toJson()]));
  }

  Future<void> add(String name, String url) async {
    state = [
      ...state,
      ActionItem(uuid: DateTime.now().microsecondsSinceEpoch.toString(), name: name, url: url),
    ];
    await _save();
  }

  Future<void> update(String uuid, String name, String url) async {
    state = [
      for (final item in state)
        if (item.uuid == uuid) ActionItem(uuid: uuid, name: name, url: url, active: item.active) else item,
    ];
    await _save();
  }

  Future<void> remove(String uuid) async {
    state = state.where((item) => item.uuid != uuid).toList();
    await _save();
  }

  Future<void> toggle(String uuid, bool active) async {
    state = [
      for (final item in state)
        if (item.uuid == uuid) ActionItem(uuid: uuid, name: item.name, url: item.url, active: active) else item,
    ];
    await _save();
  }
}

final actionsControllerProvider = NotifierProvider<ActionsController, List<ActionItem>>(
  ActionsController.new,
);

/// 操作记录 (本地快捷操作列表)
class ActionsScreen extends ConsumerWidget {
  const ActionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(actionsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('操作记录')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('添加操作'),
      ),
      body: items.isEmpty
          ? const Center(child: Text('暂无操作, 点击右下角添加'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: SwitchListTile(
                    title: Text(item.name),
                    subtitle: Text(
                      item.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: item.active,
                    onChanged: (v) =>
                        ref.read(actionsControllerProvider.notifier).toggle(item.uuid, v),
                    secondary: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.open_in_new, size: 18),
                          onPressed: () => launchUrl(Uri.parse(item.url)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _edit(context, ref, item: item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              ref.read(actionsControllerProvider.notifier).remove(item.uuid),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, {ActionItem? item}) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final urlCtrl = TextEditingController(text: item?.url ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? '添加操作' : '编辑操作'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称')),
            const SizedBox(height: 8),
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: '网址')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || urlCtrl.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final controller = ref.read(actionsControllerProvider.notifier);
    if (item == null) {
      await controller.add(nameCtrl.text.trim(), urlCtrl.text.trim());
    } else {
      await controller.update(item.uuid, nameCtrl.text.trim(), urlCtrl.text.trim());
    }
  }
}
