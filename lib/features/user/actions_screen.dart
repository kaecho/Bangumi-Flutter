import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../../core/utils/display.dart';

import 'user_notes.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';

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

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'name': name,
    'url': url,
    'active': active,
  };

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
      ActionItem(
        uuid: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        url: url,
      ),
    ];
    await _save();
  }

  Future<void> update(String uuid, String name, String url) async {
    state = [
      for (final item in state)
        if (item.uuid == uuid)
          ActionItem(uuid: uuid, name: name, url: url, active: item.active)
        else
          item,
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
        if (item.uuid == uuid)
          ActionItem(uuid: uuid, name: item.name, url: item.url, active: active)
        else
          item,
    ];
    await _save();
  }
}

final actionsControllerProvider =
    NotifierProvider<ActionsController, List<ActionItem>>(
      ActionsController.new,
    );

/// 操作记录 (本地快捷操作列表)
class ActionsScreen extends ConsumerWidget {
  final String? name;

  const ActionsScreen({super.key, this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(actionsControllerProvider);
    return Scaffold(
      appBar: BgmAppBar(
        title: actionsTitle(name),
        actions: [
          BgmHeaderMore(
            items: kActionsMoreItems,
            onSelected: (_) => context.push(actionsNotePath()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('暂无操作'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return BgmSettingRow(
                        title: item.name,
                        subtitle: item.url,
                        trailing: BgmSwitch(
                          value: item.active,
                          onChanged: (v) => ref
                              .read(actionsControllerProvider.notifier)
                              .toggle(item.uuid, v),
                        ),
                        below: Row(
                          children: [
                            BgmHeaderAction(
                              icon: const Icon(Icons.open_in_new, size: 18),
                              onPressed: () => openExternalUrl(item.url),
                            ),
                            BgmHeaderAction(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _edit(context, ref, item: item),
                            ),
                            BgmHeaderAction(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => ref
                                  .read(actionsControllerProvider.notifier)
                                  .remove(item.uuid),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: BgmButton(
                '添加',
                type: BgmButtonType.plain,
                onPressed: () => _edit(context, ref),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    ActionItem? item,
  }) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final urlCtrl = TextEditingController(text: item?.url ?? '');
    final saved = await showBgmDialog<bool>(
      context: context,
      title: item == null ? '添加操作' : '编辑操作',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BgmField(controller: nameCtrl, labelText: '名称'),
          const SizedBox(height: 8),
          BgmField(controller: urlCtrl, labelText: '网址'),
        ],
      ),
      actions: (ctx) => [
        BgmButton(
          '取消',
          type: BgmButtonType.plain,
          expand: false,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        BgmButton(
          '保存',
          expand: false,
          onPressed: () {
            if (nameCtrl.text.trim().isEmpty || urlCtrl.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(ctx, true);
          },
        ),
      ],
    );
    if (saved != true) return;
    final controller = ref.read(actionsControllerProvider.notifier);
    if (item == null) {
      await controller.add(nameCtrl.text.trim(), urlCtrl.text.trim());
    } else {
      await controller.update(
        item.uuid,
        nameCtrl.text.trim(),
        urlCtrl.text.trim(),
      );
    }
  }
}
