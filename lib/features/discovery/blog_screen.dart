import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import 'widgets/discovery_html.dart';
import 'widgets/paged.dart';

class BlogList extends PagedNotifier<BlogListRow, int> {
  @override
  Future<List<BlogListRow>> fetchPage(int arg, int page) async {
    final client = ref.read(apiClientProvider);
    final body = await client.get(htmlBlogList(page: page), host: kHost);
    return parseBlogList(body as String);
  }
}

final blogListProvider =
    AsyncNotifierProvider.family<BlogList, PagedData<BlogListRow>, int>(BlogList.new);

/// 全站日志
class BlogScreen extends ConsumerWidget {
  const BlogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: BgmAppBar(title: '日志', showBackButton: true),
      body: PagedListView<BlogListRow, int>(
        provider: blogListProvider,
        arg: 0,
        emptyText: '暂无日志',
        itemBuilder: (context, row, index) => _BlogRow(row: row),
      ),
    );
  }
}

class _BlogRow extends StatelessWidget {
  final BlogListRow row;

  const _BlogRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push(
        '/web/${Uri.encodeComponent('https://bgm.tv/blog/${row.id}')}',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 44,
                height: 44,
                child: row.cover.isEmpty
                    ? Container(color: theme.colorScheme.surfaceContainerHighest)
                    : Cover(url: row.cover, width: 44, height: 44, radius: 4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (row.content.isNotEmpty)
                    Text(
                      row.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${row.username} · ${row.time} · ${row.replies} 回复',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
