import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';

import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';
import '../../shared/models/ep.dart';

import 'subject_models.dart';
import 'subject_providers.dart';
import '../../shared/widgets/bgm_button.dart';
import 'subject_notes.dart';

/// 章节吐槽箱
/// 路由: /subject/:id/ep/:epId/comments
class EpCommentsScreen extends ConsumerWidget {
  final int id;
  final int epId;

  const EpCommentsScreen({super.key, required this.id, required this.epId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comments = ref.watch(epCommentsProvider(epId));
    final eps = ref.watch(epListProvider(id)).valueOrNull;
    Ep? ep;
    if (eps != null) {
      for (final item in [
        ...eps.eps,
        ...eps.type1,
        ...eps.type2,
        ...eps.type3,
        ...eps.type4,
        ...eps.type6,
      ]) {
        if (item.id == epId) {
          ep = item;
          break;
        }
      }
    }
    return Scaffold(
      appBar: BgmAppBar(
        title: epCommentsTitle(
          sort: ep?.sort,
          name: ep == null ? null : (ep.name.isNotEmpty ? ep.name : ep.nameCn),
        ),
        showBackButton: true,
        actions: [
          BgmHeaderMore.browser(() => openExternalUrl(htmlEpPage(epId))),
        ],
      ),

      body: comments.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) =>
            BgmRetry(onRetry: () => ref.invalidate(epCommentsProvider(epId))),
        data: (value) => value.items.isEmpty
            ? const Empty(text: '暂无吐槽', icon: Icons.chat_bubble_outline)
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: value.items.length,
                itemBuilder: (_, i) => _CommentTile(comment: value.items[i]),
              ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final SubjectCommentItem comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(url: comment.avatar, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayText(comment.userName),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    UserAgeBadge(userId: comment.userId),
                    if (comment.time.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        comment.time,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  displayText(comment.content),
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
