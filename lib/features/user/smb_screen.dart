import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/models/subject.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
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

/// 本地管理 (文件夹 + 条目)
class SmbScreen extends ConsumerWidget {
  const SmbScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(smbControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('本地管理'),

        actions: [
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (v) {
              if (v == 'add') {
                unawaited(_showFolderDialog(context, ref));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'add', child: Text('新增服务')),
            ],
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFolderDialog(context, ref),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('新建文件夹'),
      ),
      body: folders.isEmpty
          ? const Center(child: Text('暂无文件夹, 点击右下角新建'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.folder,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(folder.name),
                    subtitle: Text(
                      [
                        if (folder.note.isNotEmpty) folder.note,
                        '${folder.subjects.length} 个条目',
                      ].join(' · '),
                    ),
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
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _SmbFolderDetail(folder: folder),
                      ),
                    ),
                  ),
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
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(folder == null ? '新建文件夹' : '重命名'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: '备注 (可选)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final controller = ref.read(smbControllerProvider.notifier);
              if (folder == null) {
                controller.addFolder(name, noteCtrl.text.trim());
              } else {
                controller.renameFolder(folder.id, name, noteCtrl.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _SmbFolderDetail extends ConsumerStatefulWidget {
  final SmbFolder folder;

  const _SmbFolderDetail({required this.folder});

  @override
  ConsumerState<_SmbFolderDetail> createState() => _SmbFolderDetailState();
}

class _SmbFolderDetailState extends ConsumerState<_SmbFolderDetail> {
  bool _fetching = false;

  Future<void> _addSubject() async {
    final idCtrl = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加条目'),
        content: TextField(
          controller: idCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '条目 ID',
            hintText: '例如 326',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, idCtrl.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
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
          .addSubject(widget.folder.id, {
            'id': subject.id,
            'name': subject.name,
            'nameCn': subject.nameCn,
            'cover': subject.images.common,
          });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已添加 ${subject.displayName}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('获取条目失败: $e')));
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(smbControllerProvider);
    final folder =
        folders.where((f) => f.id == widget.folder.id).firstOrNull ??
        widget.folder;
    return Scaffold(
      appBar: AppBar(
        title: Text(folder.name),
        actions: [
          IconButton(
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
          : ListView.builder(
              itemCount: folder.subjects.length,
              itemBuilder: (context, index) {
                final subject = folder.subjects[index];
                final name = (subject['nameCn'] as String? ?? '').isNotEmpty
                    ? subject['nameCn'] as String
                    : subject['name'] as String? ?? '';
                final cover = subject['cover'] as String? ?? '';
                final jpName = subject['name'] as String? ?? '';
                final romaji = basicKatakanaToRomaji(jpName);
                return ListTile(
                  leading: Cover(url: cover, width: 42, height: 56),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: romaji.isEmpty
                      ? null
                      : Text(
                          romaji,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: '移除',
                    onPressed: () => unawaited(
                      ref
                          .read(smbControllerProvider.notifier)
                          .removeSubject(folder.id, subject['id'] as int? ?? 0),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
