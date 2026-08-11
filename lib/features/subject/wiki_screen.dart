import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';
import 'subject_models.dart';
import 'subject_providers.dart';

/// 维基编辑历史
/// 路由: /subject/:id/wiki
class WikiScreen extends ConsumerWidget {
  final int id;

  const WikiScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edits = ref.watch(wikiProvider(id));
    return Scaffold(
      appBar: BgmAppBar(title: '维基修订历史', showBackButton: true),
      body: edits.when(
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
                onPressed: () => ref.invalidate(wikiProvider(id)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? const Empty(text: '暂无修订记录')
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (_, i) => _WikiRow(edit: items[i]),
              ),
      ),
    );
  }
}

class _WikiRow extends StatelessWidget {
  final WikiEdit edit;
  const _WikiRow({required this.edit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Text(
          edit.userName.isEmpty ? '?' : edit.userName.characters.first,
          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
      title: Text(
        edit.userName.isEmpty ? '匿名用户' : edit.userName,
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          [
            edit.time,
            if (edit.summary.isNotEmpty) edit.summary,
          ].join(' · '),
          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: edit.rev > 0
          ? Text(
              '#${edit.rev}',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
            )
          : null,
    );
  }
}
