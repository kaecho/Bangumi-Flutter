import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/models/group.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import 'widgets/discovery_html.dart';
import 'widgets/paged.dart';

class GroupList extends PagedNotifier<Group, int> {
  @override
  Future<List<Group>> fetchPage(int arg, int page) async {
    final client = ref.read(apiClientProvider);
    final body = await client.get(htmlGroupList(page: page), host: kHost);
    return parseGroupList(body as String);
  }
}

final groupListProvider =
    AsyncNotifierProvider.family<GroupList, PagedData<Group>, int>(GroupList.new);

/// 小组列表
class GroupScreen extends ConsumerWidget {
  const GroupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: BgmAppBar(title: '小组', showBackButton: true),
      body: PagedGridView<Group, int>(
        provider: groupListProvider,
        arg: 0,
        crossAxisCount: 2,
        childAspectRatio: 1.7,
        emptyText: '暂无小组',
        itemBuilder: (context, group, index) => _GroupCard(group: group),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Group group;

  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push(
        '/web/${Uri.encodeComponent('https://bgm.tv/group/${group.name}')}',
      ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Cover(
              url: group.icon,
              width: 44,
              height: 44,
              radius: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.title.isEmpty ? group.name : group.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${group.members} 位成员',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
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
