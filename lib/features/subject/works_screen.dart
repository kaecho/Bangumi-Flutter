import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'collection_sheet.dart';
import 'subject_models.dart';
import 'subject_notes.dart';
import 'subject_providers.dart';

/// Extra 作品 HeaderV2: `{name}的作品 (N)` / 更多作品 + more toolbar
/// 路由: /subject/:id/works (id 为人物 ID)
class WorksScreen extends ConsumerStatefulWidget {
  final int id;
  final String type;

  const WorksScreen({super.key, required this.id, this.type = 'person'});

  @override
  ConsumerState<WorksScreen> createState() => _WorksScreenState();
}

class _WorksScreenState extends ConsumerState<WorksScreen> {
  bool _fixed = false;
  bool _list = true;
  bool _collected = true;
  String _sort = 'date';
  String _position = '';

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final type = widget.type;
    final query = (type: type, id: id, position: _position, sort: _sort);
    final page = ref.watch(monoWorksProvider(query));
    final name = ref
        .watch(monoDetailProvider((type: type, id: id)))
        .valueOrNull
        ?.displayName;
    return Scaffold(
      appBar: BgmAppBar(
        title: extraNamedTitle(
          name,
          '更多作品',
          named: (n) => '$n的作品',
          count: page.valueOrNull?.list.length,
        ),
        showBackButton: true,
        actions: [
          BgmHeaderMore(
            items: worksMoreItems(
              fixed: _fixed,
              list: _list,
              collected: _collected,
            ),
            onSelected: (value) {
              switch (value) {
                case 'browser':
                  openExternalUrl(
                    htmlMonoWorks(type, id, position: _position, sort: _sort),
                  );
                case 'toolbar':
                  setState(() => _fixed = !_fixed);
                case 'layout':
                  setState(() => _list = !_list);
                case 'favor':
                  setState(() => _collected = !_collected);
              }
            },
          ),
        ],
      ),
      body: page.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) =>
            BgmRetry(onRetry: () => ref.invalidate(monoWorksProvider(query))),
        data: (value) {
          final visible = _collected
              ? value.list
              : [
                  for (final item in value.list)
                    if (!item.collected) item,
                ];
          if (visible.isEmpty && value.list.isEmpty) {
            return const Empty(text: '暂无作品');
          }
          final toolBar = _WorksToolBar(
            filters: value.filters,
            sort: _sort,
            position: _position,
            onSort: (v) => setState(() => _sort = v),
            onPosition: (v) => setState(() => _position = v),
          );
          final content = visible.isEmpty
              ? const Empty(text: '暂无作品')
              : _list
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: visible.length,
                  itemBuilder: (_, i) => _WorkRow(item: visible[i]),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 120,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (_, i) => _WorkGrid(item: visible[i]),
                );
          if (_fixed) {
            return Column(
              children: [
                toolBar,
                Expanded(child: content),
              ],
            );
          }
          return Stack(
            children: [
              Positioned.fill(child: content),
              Positioned(left: 0, right: 0, top: 0, child: toolBar),
            ],
          );
        },
      ),
    );
  }
}

class _WorksToolBar extends StatelessWidget {
  final List<MonoVoiceFilter> filters;
  final String sort;
  final String position;
  final ValueChanged<String> onSort;
  final ValueChanged<String> onPosition;

  const _WorksToolBar({
    required this.filters,
    required this.sort,
    required this.position,
    required this.onSort,
    required this.onPosition,
  });

  @override
  Widget build(BuildContext context) {
    String sortLabel() {
      for (final e in kWorksOrders) {
        if (e.$1 == sort) return e.$2;
      }
      return '日期';
    }

    return Material(
      color: context.ds.surfaceBase,
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            _WorksPill(
              label: sortLabel(),
              options: [for (final e in kWorksOrders) e.$2],
              selected: sortLabel(),
              onSelected: (label) {
                for (final e in kWorksOrders) {
                  if (e.$2 == label) onSort(e.$1);
                }
              },
            ),
            for (final filter in filters) ...[
              const SizedBox(width: 8),
              _WorksPill(
                label: () {
                  for (final o in filter.options) {
                    if (o.$1 == position) return o.$2;
                  }
                  return filter.title;
                }(),
                options: [for (final o in filter.options) o.$2],
                selected: () {
                  for (final o in filter.options) {
                    if (o.$1 == position) return o.$2;
                  }
                  return '全部';
                }(),
                onSelected: (label) {
                  for (final o in filter.options) {
                    if (o.$2 == label) onPosition(o.$1);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorksPill extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _WorksPill({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return PopupMenuButton<String>(
      tooltip: label,
      padding: EdgeInsets.zero,
      onSelected: onSelected,
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
        decoration: BoxDecoration(
          color: ds.surfaceCard.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Center(
          child: Text(
            label,
            style: ds.caption.copyWith(
              color: ds.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkGrid extends StatelessWidget {
  final MonoWorkItem item;
  const _WorkGrid({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/subject/${item.id}'),
      onLongPress: () => showCollectionSheet(context, item.id),
      child: Column(
        children: [
          Cover(url: item.cover, width: 88, height: 110, radius: 6),
          const SizedBox(height: 6),
          Text(
            item.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.ds.caption.copyWith(color: context.ds.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _WorkRow extends StatelessWidget {
  final MonoWorkItem item;
  const _WorkRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/subject/${item.id}'),
      onLongPress: () => showCollectionSheet(context, item.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Cover(url: item.cover, width: 56, height: 76, radius: 4),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.tip.isNotEmpty)
                    Text(
                      item.tip,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (item.score > 0)
                    Text(
                      '${item.score.toStringAsFixed(1)} 分',
                      style: TextStyle(fontSize: 11, color: context.ds.star),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: context.ds.textHint),
          ],
        ),
      ),
    );
  }
}
