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
import 'subject_notes.dart';

import '../../design_system/design_system.dart';
import '../../shared/widgets/bgm_button.dart';

/// 制作人员 Extra Filter: 全部职位 + 职位计数, 动画制作排最前
/// 路由: /subject/:id/persons
class PersonsScreen extends ConsumerStatefulWidget {
  final int id;

  const PersonsScreen({super.key, required this.id});

  @override
  ConsumerState<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonsScreenState extends ConsumerState<PersonsScreen> {
  String _position = '';

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final persons = ref.watch(subjectPersonsProvider(id));
    final name = ref
        .watch(subjectDetailProvider(id))
        .valueOrNull
        ?.subject
        .displayName;
    return Scaffold(
      appBar: BgmAppBar(
        title: extraNamedTitle(name, '更多制作人员', named: (n) => '$n的制作人员'),
        showBackButton: true,
        actions: [
          BgmHeaderMore.browser(() => openExternalUrl(htmlSubjectPersons(id))),
        ],
      ),
      body: persons.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) =>
            BgmRetry(onRetry: () => ref.invalidate(subjectPersonsProvider(id))),
        data: (list) {
          if (list.isEmpty) return const Empty(text: '暂无制作人员');
          final filters = personsFilters(list);
          final selected = _position.isEmpty
              ? personsFilterValue(filters.first.title, filters.first.value)
              : _position;
          final visible = filterPersons(list, selected);
          return Column(
            children: [
              if (filters.length > 1)
                _PersonsToolBar(
                  filters: filters,
                  selected: selected,
                  onSelect: (v) => setState(() => _position = v),
                ),
              Expanded(
                child: visible.isEmpty
                    ? const Empty(text: '暂无制作人员')
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 120,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.62,
                            ),
                        itemCount: visible.length,
                        itemBuilder: (_, i) => _PersonCard(person: visible[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PersonsToolBar extends StatelessWidget {
  final List<({String title, int value})> filters;
  final String selected;
  final ValueChanged<String> onSelect;

  const _PersonsToolBar({
    required this.filters,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      for (final item in filters) personsFilterValue(item.title, item.value),
    ];
    return Material(
      color: context.ds.surfaceBase,
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            PopupMenuButton<String>(
              tooltip: selected,
              padding: EdgeInsets.zero,
              onSelected: onSelect,
              itemBuilder: (_) => [
                for (final option in options)
                  PopupMenuItem(
                    value: option,
                    child: Text(
                      option,
                      style: TextStyle(
                        fontWeight: option == selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
              ],
              child: Container(
                constraints: const BoxConstraints(minHeight: 30),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                child: Text(
                  selected,
                  style: context.ds.caption.copyWith(
                    color: context.ds.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
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
          if (person.jobs.isNotEmpty)
            Text(
              person.jobs.join(' / '),
              style: TextStyle(fontSize: 10, color: theme.colorScheme.primary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (person.info.isNotEmpty)
            Text(
              person.info,
              style: context.ds.tiny,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
