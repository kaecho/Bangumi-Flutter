import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';

import 'subject_models.dart';
import 'subject_providers.dart';
import '../../design_system/design_system.dart';

/// 制作人员
/// 路由: /subject/:id/persons
class PersonsScreen extends ConsumerWidget {
  final int id;

  const PersonsScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persons = ref.watch(subjectPersonsProvider(id));
    return Scaffold(
      appBar: BgmAppBar(
        title: '制作人员',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: '浏览器查看',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => openExternalUrl(htmlSubjectPersons(id)),
          ),
        ],
      ),

      body: persons.when(
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
                onPressed: () => ref.invalidate(subjectPersonsProvider(id)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (list) => list.isEmpty
            ? const Empty(text: '暂无制作人员')
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.62,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) => _PersonCard(person: list[i]),
              ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final PersonVo person;
  const _PersonCard({required this.person});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.push('/mono/person/${person.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Cover(
            url: person.images.large,
            width: double.infinity,
            height: 132,
            radius: 6,
          ),
          const SizedBox(height: 6),
          Text(
            person.displayName,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (person.relation.isNotEmpty)
            Text(
              person.relation,
              style: TextStyle(fontSize: 10, color: theme.colorScheme.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (person.career.isNotEmpty)
            Text(
              person.career.join(' / '),
              style: context.ds.tiny,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
