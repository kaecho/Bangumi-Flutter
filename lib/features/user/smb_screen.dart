import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/models/subject.dart';

import '../../design_system/design_system.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'package:go_router/go_router.dart';
import 'user_models.dart' show basicKatakanaToRomaji;

/// 本地管理文件夹
class SmbFolder {
  final String id;
  final String name;
  final String note;
  final List<Map<String, dynamic>> subjects; // {id, name, nameCn, cover}

  const SmbFolder({
    required this.id,
    required this.name,
    this.note = '',
    this.subjects = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'note': note,
    'subjects': subjects,
  };

  factory SmbFolder.fromJson(Map<String, dynamic> json) => SmbFolder(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    note: json['note'] as String? ?? '',
    subjects:
        (json['subjects'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        const [],
  );
}

/// 本地文件夹状态 (hive 'smb' box 持久化)
class SmbController extends Notifier<List<SmbFolder>> {
  static const _boxName = 'smb';
  static const _key = 'folders';

  @override
  List<SmbFolder> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final box = await Hive.openBox<dynamic>(_boxName);
    final raw = box.get(_key) as String?;
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => SmbFolder.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      state = list;
    } catch (_) {}
  }

  Future<void> _save() async {
    final box = await Hive.openBox<dynamic>(_boxName);
    await box.put(_key, jsonEncode([for (final f in state) f.toJson()]));
  }

  Future<void> addFolder(String name, String note) async {
    final folder = SmbFolder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      note: note,
    );
    state = [...state, folder];
    await _save();
  }

  Future<void> renameFolder(String id, String name, String note) async {
    state = [
      for (final f in state)
        if (f.id == id)
          SmbFolder(id: f.id, name: name, note: note, subjects: f.subjects)
        else
          f,
    ];
    await _save();
  }

  Future<void> removeFolder(String id) async {
    state = state.where((f) => f.id != id).toList();
    await _save();
  }

  Future<void> addSubject(String folderId, Map<String, dynamic> subject) async {
    state = [
      for (final f in state)
        if (f.id == folderId)
          SmbFolder(
            id: f.id,
            name: f.name,
            note: f.note,
            subjects: [
              ...f.subjects.where((s) => s['id'] != subject['id']),
              subject,
            ],
          )
        else
          f,
    ];
    await _save();
  }

  Future<void> removeSubject(String folderId, int subjectId) async {
    state = [
      for (final f in state)
        if (f.id == folderId)
          SmbFolder(
            id: f.id,
            name: f.name,
            note: f.note,
            subjects: [
              for (final s in f.subjects)
                if (s['id'] != subjectId) s,
            ],
          )
        else
          f,
    ];
    await _save();
  }
}

final smbControllerProvider = NotifierProvider<SmbController, List<SmbFolder>>(
  SmbController.new,
);

/// 原版 SMB Header DATA (配置同步未移植, 只留新增服务)
const kSmbMoreItems = <(String, String)>[('add', '新增服务')];

/// 本地管理 (文件夹 + 条目)
class SmbScreen extends ConsumerWidget {
  const SmbScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(smbControllerProvider);
    return Scaffold(
      appBar: BgmAppBar(
        title: '本地管理',
        actions: [
          BgmHeaderMore(
            items: kSmbMoreItems,
            onSelected: (v) {
              if (v == 'add') unawaited(_showFolderDialog(context, ref));
            },
          ),
        ],
      ),
      body: folders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('暂无文件夹'),
                  const SizedBox(height: 12),
                  BgmButton(
                    '新建文件夹',
                    expand: false,
                    onPressed: () => _showFolderDialog(context, ref),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: folders.length,
              separatorBuilder: (_, _) => const BgmHairline(),
              itemBuilder: (context, index) {
                final folder = folders[index];
                return BgmTextRow(
                  leading: Icon(Icons.folder, color: context.ds.accent),
                  title: folder.name,
                  subtitle: [
                    if (folder.note.isNotEmpty) folder.note,
                    '${folder.subjects.length} 个条目',
                  ].join(' · '),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'rename') {
                        unawaited(
                          _showFolderDialog(context, ref, folder: folder),
                        );
                      } else if (action == 'delete') {
                        unawaited(
                          ref
                              .read(smbControllerProvider.notifier)
                              .removeFolder(folder.id),
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'rename', child: Text('重命名')),
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                  onTap: () => context.push('/settings/smb/${folder.id}'),
                );
              },
            ),
    );
  }

  Future<void> _showFolderDialog(
    BuildContext context,
    WidgetRef ref, {
    SmbFolder? folder,
  }) async {
    final nameCtrl = TextEditingController(text: folder?.name ?? '');
    final noteCtrl = TextEditingController(text: folder?.note ?? '');
    await showBgmDialog<void>(
      context: context,
      title: folder == null ? '新建文件夹' : '重命名',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BgmField(controller: nameCtrl, labelText: '名称'),
          const SizedBox(height: 8),
          BgmField(controller: noteCtrl, labelText: '备注 (可选)'),
        ],
      ),
      actions: (ctx) => [
        BgmButton(
          '取消',
          type: BgmButtonType.plain,
          expand: false,
          onPressed: () => Navigator.pop(ctx),
        ),
        BgmButton(
          '保存',
          expand: false,
          onPressed: () {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) return;
            final controller = ref.read(smbControllerProvider.notifier);
            if (folder == null) {
              controller.addFolder(name, noteCtrl.text.trim());
            } else {
              controller.renameFolder(folder.id, name, noteCtrl.text.trim());
            }
            Navigator.pop(ctx);
          },
        ),
      ],
    );
  }
}

class SmbFolderDetailScreen extends ConsumerStatefulWidget {
  final String folderId;

  const SmbFolderDetailScreen({super.key, required this.folderId});

  @override
  ConsumerState<SmbFolderDetailScreen> createState() =>
      _SmbFolderDetailScreenState();
}

class _SmbFolderDetailScreenState extends ConsumerState<SmbFolderDetailScreen> {
  bool _fetching = false;

  Future<void> _addSubject() async {
    final idCtrl = TextEditingController();
    final id = await showBgmDialog<String>(
      context: context,
      content: BgmField(
        controller: idCtrl,
        keyboardType: TextInputType.number,
        labelText: '条目 ID',
        hintText: '例如 326',
      ),
      actions: (ctx) => [
        BgmButton(
          '取消',
          type: BgmButtonType.plain,
          expand: false,
          onPressed: () => Navigator.pop(ctx),
        ),
        BgmButton(
          '添加',
          expand: false,
          onPressed: () => Navigator.pop(ctx, idCtrl.text.trim()),
        ),
      ],
    );
    final sid = int.tryParse(id ?? '');
    if (sid == null || sid <= 0) return;

    setState(() => _fetching = true);
    try {
      final client = ref.read(apiClientProvider);
      final data = await client.get(apiSubject(sid));
      final subject = Subject.fromJson(data as Map<String, dynamic>);
      await ref
          .read(smbControllerProvider.notifier)
          .addSubject(widget.folderId, {
            'id': subject.id,
            'name': subject.name,
            'nameCn': subject.nameCn,
            'cover': subject.images.common,
          });
      if (!mounted) return;
      showBgmToast(context, '已添加 ${subject.displayName}');
    } catch (e) {
      if (!mounted) return;
      showBgmToast(context, '获取条目失败: $e');
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(smbControllerProvider);
    final folder = folders.where((f) => f.id == widget.folderId).firstOrNull;
    if (folder == null) {
      return const Scaffold(
        appBar: BgmAppBar(title: '本地管理'),
        body: Center(child: Text('文件夹不存在')),
      );
    }
    return Scaffold(
      appBar: BgmAppBar(
        title: folder.name,
        actions: [
          BgmHeaderAction(
            icon: const Icon(Icons.add),
            tooltip: '添加条目',
            onPressed: _fetching ? null : _addSubject,
          ),
        ],
      ),
      body: _fetching
          ? const Loading()
          : folder.subjects.isEmpty
          ? const Center(child: Text('暂无条目, 点击右上角按 ID 添加'))
          : ListView.separated(
              itemCount: folder.subjects.length,
              separatorBuilder: (_, _) => const BgmHairline(),
              itemBuilder: (context, index) {
                final subject = folder.subjects[index];
                final name = (subject['nameCn'] as String? ?? '').isNotEmpty
                    ? subject['nameCn'] as String
                    : subject['name'] as String? ?? '';
                final cover = subject['cover'] as String? ?? '';
                final jpName = subject['name'] as String? ?? '';
                final romaji = basicKatakanaToRomaji(jpName);
                return BgmTextRow(
                  leading: Cover(url: cover, width: 42, height: 56),
                  title: name,
                  subtitle: romaji.isEmpty ? null : romaji,
                  trailing: BgmHeaderAction(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: '移除',
                    onPressed: () => unawaited(
                      ref
                          .read(smbControllerProvider.notifier)
                          .removeSubject(folder.id, subject['id'] as int? ?? 0),
                    ),
                  ),
                  onTap: () {
                    final sid = subject['id'] as int? ?? 0;
                    if (sid > 0) context.push('/subject/$sid');
                  },
                );
              },
            ),
    );
  }
}
