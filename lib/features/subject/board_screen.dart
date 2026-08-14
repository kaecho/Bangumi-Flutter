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

/// 条目讨论版
/// 路由: /subject/:id/board
class SubjectBoardScreen extends ConsumerWidget {
  final int id;

  const SubjectBoardScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(subjectBoardProvider(id));
    return Scaffold(
      appBar: BgmAppBar(
        title: '讨论版',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: '浏览器查看',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => openExternalUrl(htmlSubjectBoard(id)),
          ),
        ],
      ),

      body: board.when(
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
                onPressed: () => ref.invalidate(subjectBoardProvider(id)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? const Empty(text: '暂无讨论')
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
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
    return ListTile(
      title: Text(
        item.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.ds.bodyStrong,
      ),
      subtitle: Text(
        [
          if (item.userName.isNotEmpty) item.userName,
          if (item.replies.isNotEmpty) '${item.replyCount} 回复',
          if (item.time.isNotEmpty) item.time,
        ].join(' · '),
        style: context.ds.caption,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(Icons.chevron_right, size: 18, color: context.ds.textHint),
      onTap: item.topicId.isEmpty
          ? null
          : () => context.push('/rakuen/topic/${item.topicId}'),
    );
  }
}
