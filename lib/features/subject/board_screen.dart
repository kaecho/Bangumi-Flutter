import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';

import '../rakuen/html_parse.dart';
import 'subject_providers.dart';
import 'subject_notes.dart';

import '../../shared/widgets/bgm_button.dart';

/// 条目讨论版
/// 路由: /subject/:id/board
class SubjectBoardScreen extends ConsumerWidget {
  final int id;

  const SubjectBoardScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(subjectBoardProvider(id));
    final name = ref
        .watch(subjectDetailProvider(id))
        .valueOrNull
        ?.subject
        .displayName;
    return Scaffold(
      appBar: BgmAppBar(
        title: extraNamedTitle(name, '讨论版', named: (n) => '$n的讨论版'),
        showBackButton: true,
        actions: [
          BgmHeaderMore.browser(() => openExternalUrl(htmlSubjectBoard(id))),
        ],
      ),


      body: board.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) =>
            BgmRetry(onRetry: () => ref.invalidate(subjectBoardProvider(id))),
        data: (items) => items.isEmpty
            ? const Empty(text: '暂无讨论')
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, _) => const BgmHairline(),
                itemBuilder: (_, i) => _BoardRow(item: items[i]),
              ),
      ),
    );
  }
}

class _BoardRow extends StatelessWidget {
  final RakuenTopicItem item;

  const _BoardRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return BgmTextRow(
      title: item.title,
      replies: item.replyCount,
      subtitle: [
        if (item.userName.isNotEmpty) item.userName,
        if (item.time.isNotEmpty) item.time,
      ].join(' · '),
      trailing: Icon(Icons.chevron_right, size: 18, color: context.ds.textHint),
      onTap: item.topicId.isEmpty
          ? null
          : () => context.push('/rakuen/topic/${item.topicId}'),
    );
  }
}
