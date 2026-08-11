import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/app_bar.dart';
import 'widgets/discovery_html.dart';
import 'widgets/paged.dart';

class DollarsTopics extends PagedNotifier<TopicRow, int> {
  @override
  Future<List<TopicRow>> fetchPage(int arg, int page) async {
    final client = ref.read(apiClientProvider);
    // Dollars 聊天页需登录, 这里按任务描述展示 Dollars 小组的论坛主题列表
    final body = await client.get(htmlDollarsForum(page: page), host: kHost);
    return parseTopicRows(body as String);
  }
}

final dollarsTopicsProvider =
    AsyncNotifierProvider.family<DollarsTopics, PagedData<TopicRow>, int>(DollarsTopics.new);

/// Dollars 论坛 (Dollars 小组主题列表)
class DollarsScreen extends ConsumerWidget {
  const DollarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: BgmAppBar(title: 'Dollars', showBackButton: true),
      body: PagedListView<TopicRow, int>(
        provider: dollarsTopicsProvider,
        arg: 0,
        emptyText: '暂无讨论',
        itemBuilder: (context, row, index) => _TopicRowView(row: row),
      ),
    );
  }
}

class _TopicRowView extends StatelessWidget {
  final TopicRow row;

  const _TopicRowView({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push(
        '/web/${Uri.encodeComponent('https://bgm.tv/group/topic/${row.id}')}',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${row.username} · 最后回复 ${row.lastTime}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${row.replies} 回复',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
