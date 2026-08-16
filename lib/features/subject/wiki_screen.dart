import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';

import 'subject_models.dart';
import 'subject_providers.dart';
import 'subject_notes.dart';

import '../../design_system/design_system.dart';
import '../../shared/widgets/bgm_button.dart';

/// 维基编辑历史
/// 路由: /subject/:id/wiki
class WikiScreen extends ConsumerWidget {
  final int id;

  const WikiScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edits = ref.watch(wikiProvider(id));
    return Scaffold(
      appBar: BgmAppBar(
        title: extraNamedTitle(
          ref.watch(subjectDetailProvider(id)).valueOrNull?.subject.displayName,
          '修订历史',
          named: (n) => '$n的修订历史',
        ),
        showBackButton: true,
        actions: [
          BgmHeaderMore.browser(() => openExternalUrl(htmlSubjectWikiEdit(id))),
        ],
      ),


      body: edits.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) =>
            BgmRetry(onRetry: () => ref.invalidate(wikiProvider(id))),
        data: (items) => items.isEmpty
            ? const Empty(text: '暂无修订记录')
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, _) => const BgmHairline(indent: 16),
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
    return BgmTextRow(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Text(
          edit.userName.isEmpty ? '?' : edit.userName.characters.first,
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      title: edit.userName.isEmpty ? '匿名用户' : edit.userName,
      subtitle: [
        edit.time,
        if (edit.summary.isNotEmpty) edit.summary,
      ].join(' · '),
      trailing: edit.rev > 0
          ? Text('#${edit.rev}', style: context.ds.meta)
          : null,
    );
  }
}
