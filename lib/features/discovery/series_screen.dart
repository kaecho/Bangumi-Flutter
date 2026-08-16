import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/models/subject.dart';
import '../../design_system/design_system.dart';

import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/bgm_button.dart';
import 'series_header.dart';
import 'series_notes.dart';
import 'widgets/discovery_html.dart';

import 'widgets/recommend_list.dart';

/// 关联系列 (条目系列)
///
/// 移植原项目 series 算法: 收藏 (看过/在看) → 条目关系
/// (/v0/subjects/{id}/subjects) → 并查集合并成系列组。
class SeriesItem {
  final Subject subject;
  final int collectionType;
  final int epStatus;

  const SeriesItem({
    required this.subject,
    this.collectionType = 0,
    this.epStatus = 0,
  });
}

class SeriesGroup {
  final String name;
  final List<SeriesItem> items;

  const SeriesGroup({required this.name, required this.items});

  List<Subject> get subjects => [for (final item in items) item.subject];
}

/// 原版 DATA_SORT / RANK_ANIME_FILTER / DATA_AIRTIME / DATA_STATUS
const kSeriesSorts = ['默认', '关联数', '新放送', '评分'];
const kSeriesFilters = ['全部', 'TV', 'WEB', 'OVA', '剧场版', '动态漫画', '其他'];
const kSeriesStatus = ['全部', '有关联系列', '未收藏', '看过', '在看', '未看完'];

List<String> seriesAirtimeYears([int? now]) {
  final year = now ?? DateTime.now().year;
  return ['全部', for (var y = year; y >= 1980; y--) '$y'];
}

List<SeriesItem> filterSeriesItems(
  List<SeriesItem> items, {
  required String filter,
  required String airtime,
  required String status,
}) {
  var data = items;
  if (filter.isNotEmpty && filter != '全部') {
    data = [
      for (final item in data)
        if (item.subject.tags.any((t) => t.name.contains(filter)) ||
            item.subject.displayName.contains(filter))
          item,
    ];
  }
  if (airtime.isNotEmpty && airtime != '全部') {
    data = [
      for (final item in data)
        if (item.subject.airDate.contains('$airtime-')) item,
    ];
  }
  if (status == '未收藏') {
    data = [
      for (final item in data)
        if (item.collectionType == 0) item,
    ];
  } else if (status == '看过') {
    data = [
      for (final item in data)
        if (item.collectionType == 2) item,
    ];
  } else if (status == '在看') {
    data = [
      for (final item in data)
        if (item.collectionType == 3) item,
    ];
  } else if (status == '未看完') {
    data = [
      for (final item in data)
        if (item.epStatus > 0 &&
            item.subject.eps > 0 &&
            item.epStatus != item.subject.eps)
          item,
    ];
  }
  return data;
}

List<SeriesGroup> filterSeriesGroups(
  List<SeriesGroup> groups, {
  required String sort,
  required String filter,
  required String airtime,
  required String status,
}) {
  final visible = <SeriesGroup>[];
  for (final group in groups) {
    if (status == '有关联系列' && group.items.length <= 1) continue;
    final items = filterSeriesItems(
      group.items,
      filter: filter,
      airtime: airtime,
      status: status,
    );
    if (items.isEmpty) continue;
    visible.add(SeriesGroup(name: group.name, items: items));
  }
  if (sort == '关联数') {
    visible.sort((a, b) => b.items.length.compareTo(a.items.length));
  } else if (sort == '新放送') {
    int stamp(SeriesGroup group) {
      var max = 0;
      for (final item in group.items) {
        final n = int.tryParse(item.subject.airDate.replaceAll('-', '')) ?? 0;
        if (n > max) max = n;
      }
      return max;
    }

    visible.sort((a, b) => stamp(b).compareTo(stamp(a)));
  } else if (sort == '评分') {
    int rankOf(SeriesGroup group) {
      var min = 9999;
      for (final item in group.items) {
        final rank = item.subject.rank == 0 ? 9999 : item.subject.rank;
        if (rank < min) min = rank;
      }
      return min;
    }

    visible.sort((a, b) => rankOf(a).compareTo(rankOf(b)));
  }
  return visible;
}

/// 与原项目一致的关联类型
const kSeriesRelations = ['前传', '续集', '番外篇', '主线故事', '相同世界观', '不同世界观'];

final seriesProvider = FutureProvider<List<SeriesGroup>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final userId = user.username.isEmpty ? '${user.id}' : user.username;
  final client = ref.read(apiClientProvider);

  // 1. 收藏 (看过 type=2 + 在看 type=3, 动画)
  final collections = await fetchUserCollectionsAll(ref, userId, 2);
  final collected = collections
      .where((e) => e.type == 2 || e.type == 3)
      .toList();
  if (collected.isEmpty) return const [];

  // 2. 条目关系 → 邻接表
  final relations = <int, List<int>>{};
  Future<void> fetchRelations(int subjectId) async {
    try {
      final data = await client.get(apiV0SubjectSeries(subjectId));
      final list = (data as List).whereType<Map<String, dynamic>>();
      relations[subjectId] = list
          .where(
            (e) =>
                (e['type'] as num?)?.toInt() == 2 &&
                kSeriesRelations.contains(e['relation']),
          )
          .map((e) => (e['id'] as num?)?.toInt() ?? 0)
          .where((id) => id > 0)
          .toList();
    } catch (_) {
      relations[subjectId] = const [];
    }
  }

  final seeds = collected.map((e) => e.subjectId).take(40).toList();
  await Future.wait(seeds.map(fetchRelations));

  // 3. 并查集合并
  final parent = <int, int>{};
  int find(int x) {
    parent[x] ??= x;
    if (parent[x] != x) parent[x] = find(parent[x]!);
    return parent[x]!;
  }

  void union(int a, int b) {
    final ra = find(a);
    final rb = find(b);
    if (ra != rb) parent[ra] = rb;
  }

  for (final entry in relations.entries) {
    for (final id in entry.value) {
      if (entry.key != id) union(entry.key, id);
    }
  }

  // 4. 组装分组 (组内条目 ≥2 才有系列意义)
  final groups = <int, List<int>>{};
  for (final id in [...relations.keys, ...relations.values.expand((v) => v)]) {
    groups.putIfAbsent(find(id), () => []).add(id);
  }

  final byId = <int, V0CollectionItem>{};
  for (final e in collected) {
    byId[e.subjectId] = e;
  }
  // 组内条目的名称/封面需要条目信息, 从收藏中补全 (未收藏的仅保留 id 占位)
  final result = <SeriesGroup>[];
  for (final ids in groups.values) {
    final unique = ids.toSet().toList()..sort();
    if (unique.length < 2) continue;
    final items = [
      for (final id in unique)
        SeriesItem(
          subject:
              byId[id]?.subject ??
              Subject(id: id, images: const SubjectImages()),
          collectionType: byId[id]?.type ?? 0,
          epStatus: byId[id]?.epStatus ?? 0,
        ),
    ];
    result.add(
      SeriesGroup(name: items.first.subject.displayName, items: items),
    );
  }
  result.sort((a, b) => a.items.length.compareTo(b.items.length));
  return result.reversed.toList();
});

/// 关联系列
class SeriesScreen extends ConsumerStatefulWidget {
  const SeriesScreen({super.key});

  @override
  ConsumerState<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends ConsumerState<SeriesScreen> {
  bool _fixed = true;
  String _sort = '';
  String _filter = '';
  String _airtime = '';
  String _status = '';

  void _onMore(String value) {
    switch (value) {
      case 'info':
        context.push(seriesNotePath());
      case 'toolbar':
        setState(() => _fixed = !_fixed);
    }
  }

  Widget _toolBar() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _SeriesPill(
            icon: Icons.sort,
            label: _sort.isEmpty ? '排序' : _sort,
            options: kSeriesSorts,
            selected: _sort.isEmpty ? '默认' : _sort,
            onSelected: (v) => setState(() => _sort = v == '默认' ? '' : v),
          ),
          const SizedBox(width: 8),
          _SeriesPill(
            label: _airtime.isEmpty ? '年' : _airtime,
            options: seriesAirtimeYears(),
            selected: _airtime.isEmpty ? '全部' : _airtime,
            onSelected: (v) => setState(() => _airtime = v == '全部' ? '' : v),
          ),
          const SizedBox(width: 8),
          _SeriesPill(
            icon: Icons.filter_list,
            label: _filter.isEmpty ? '类型' : _filter,
            options: kSeriesFilters,
            selected: _filter.isEmpty ? '全部' : _filter,
            onSelected: (v) => setState(() => _filter = v == '全部' ? '' : v),
          ),
          const SizedBox(width: 8),
          _SeriesPill(
            label: _status.isEmpty ? '状态' : _status,
            options: kSeriesStatus,
            selected: _status.isEmpty ? '全部' : _status,
            onSelected: (v) => setState(() => _status = v == '全部' ? '' : v),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(isLoggedInProvider);
    final groups = ref.watch(seriesProvider);
    final toolBar = _toolBar();
    return Scaffold(
      appBar: seriesAppBar(
        context: context,
        onRefresh: () => ref.invalidate(seriesProvider),
        fixed: _fixed,
        onMore: _onMore,
      ),
      body: !loggedIn
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('此功能依赖收藏数据, 请先登录'),
                  const SizedBox(height: 12),
                  BgmButton(
                    '去登录',
                    expand: false,
                    onPressed: () => context.push('/login'),
                  ),
                ],
              ),
            )
          : groups.when(
              loading: () => const Center(child: Loading()),
              error: (error, _) =>
                  BgmRetry(onRetry: () => ref.invalidate(seriesProvider)),
              data: (list) {
                final visible = filterSeriesGroups(
                  list,
                  sort: _sort,
                  filter: _filter,
                  airtime: _airtime,
                  status: _status,
                );
                final listView = visible.isEmpty
                    ? const Center(child: Text('收藏数据不足, 暂无关联系列'))
                    : RefreshIndicator(
                        onRefresh: () => ref.refresh(seriesProvider.future),
                        child: ListView.builder(
                          padding: EdgeInsets.only(
                            top: _fixed ? 0 : 44,
                            bottom: 24,
                          ),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final group = visible[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    12,
                                    14,
                                    6,
                                  ),
                                  child: Text(
                                    '${group.name} (${group.items.length})',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 150,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    itemCount: group.items.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (context, i) {
                                      final subject = group.items[i].subject;
                                      return GestureDetector(
                                        onTap: () => context.push(
                                          '/subject/${subject.id}',
                                        ),
                                        child: SizedBox(
                                          width: 90,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Cover(
                                                url: subject.images.medium,
                                                width: 90,
                                                height: 120,
                                                radius: 6,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                subject.displayName.isEmpty
                                                    ? '${subject.id}'
                                                    : subject.displayName,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      );
                if (_fixed) {
                  return Column(
                    children: [
                      toolBar,
                      Expanded(child: listView),
                    ],
                  );
                }
                return Stack(
                  children: [
                    Positioned.fill(child: listView),
                    Positioned(left: 0, right: 0, top: 0, child: toolBar),
                  ],
                );
              },
            ),
    );
  }
}

class _SeriesPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _SeriesPill({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.icon,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: ds.textPrimary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: ds.caption.copyWith(
                color: ds.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
