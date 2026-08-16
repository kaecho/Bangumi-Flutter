import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/ep.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';

import 'subject_providers.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/bgm_button.dart';
import 'subject_notes.dart';

/// 条目概览 (书籍/音乐: 卷/碟 分组章节)
/// 路由: /subject/:id/overview
class OverviewScreen extends ConsumerStatefulWidget {
  final int id;

  const OverviewScreen({super.key, required this.id});

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final detail = ref.watch(subjectDetailProvider(id));
    final eps = ref.watch(epListProvider(id)).valueOrNull;
    return Scaffold(
      appBar: BgmAppBar(
        title: extraNamedTitle(
          detail.valueOrNull?.subject.displayName,
          '概览',
          named: (n) => '$n的概览',
        ),
        showBackButton: true,
        actions: [
          BgmHeaderMore.browser(
            () => openExternalUrl(htmlSubjectRelations(id)),
          ),
        ],
      ),

      body: detail.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) =>
            BgmRetry(onRetry: () => ref.invalidate(subjectDetailProvider(id))),
        data: (value) {
          if (eps == null || eps.total == 0) {
            return const Empty(text: '暂无章节信息');
          }
          final all = [
            ...eps.eps,
            ...eps.type1,
            ...eps.type2,
            ...eps.type3,
            ...eps.type4,
            ...eps.type6,
          ];
          final filters = overviewDiscFilters(all.map((e) => e.disc));
          final selected = _filter.isEmpty
              ? overviewFilterValue(filters.first.title, filters.first.value)
              : _filter;
          final disc = overviewDiscFromFilter(selected);
          final groups = <int, List<Ep>>{};
          for (final ep in all) {
            if (disc != null && ep.disc != disc) continue;
            groups.putIfAbsent(ep.disc, () => []).add(ep);
          }
          final sorted = groups.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));
          return Column(
            children: [
              if (filters.length > 1)
                Material(
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
                          onSelected: (v) => setState(() => _filter = v),
                          itemBuilder: (_) => [
                            for (final item in filters)
                              PopupMenuItem(
                                value: overviewFilterValue(
                                  item.title,
                                  item.value,
                                ),
                                child: Text(
                                  overviewFilterValue(item.title, item.value),
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
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      value.subject.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '共 ${eps.total} 章节${value.subject.volums > 0 ? ' · ${value.subject.volums} 卷' : ''}',
                      style: context.ds.caption,
                    ),
                    const SizedBox(height: 12),
                    for (final entry in sorted)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              overviewDiscLabel(entry.key),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          for (final ep in entry.value)
                            InkWell(
                              onTap: () => context.push(
                                '/subject/$id/ep/${ep.id}/comments',
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 30,
                                      child: Text(
                                        '${ep.sort}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        ep.displayName.isEmpty
                                            ? '第 ${ep.sort} 话'
                                            : ep.displayName,
                                        style: const TextStyle(fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (ep.duration.isNotEmpty)
                                      Text(ep.duration, style: context.ds.meta),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
