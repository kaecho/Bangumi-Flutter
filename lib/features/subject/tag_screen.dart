import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/subject.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';
import 'subject_providers.dart';
import '../../design_system/design_system.dart';

/// 条目标签
/// 路由: /subject/:id/tag
class SubjectTagScreen extends ConsumerWidget {
  final int id;

  const SubjectTagScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(subjectDetailProvider(id));
    return Scaffold(
      appBar: BgmAppBar(title: '标签', showBackButton: true),
      body: detail.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 8),
              const Text('加载失败'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(subjectDetailProvider(id)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (value) => value.tags.isEmpty
            ? const Empty(text: '暂无标签')
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: value.tags.length,
                itemBuilder: (_, i) => _TagRow(
                  subjectId: id,
                  tag: value.tags[i],
                  type: value.subject.type,
                ),
              ),
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  final int subjectId;
  final Tag tag;
  final String type;

  const _TagRow({required this.subjectId, required this.tag, required this.type});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(
        '/subject/$subjectId/typerank?tag=${Uri.encodeComponent(tag.name)}&type=$type',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(tag.name, style: const TextStyle(fontSize: 14)),
            ),
            Text(
              '${tag.count}',
              style: context.ds.caption,
            ),
            Icon(Icons.chevron_right, size: 18, color: context.ds.textHint),
          ],
        ),
      ),
    );
  }
}
