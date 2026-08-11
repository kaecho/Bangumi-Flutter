import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'widgets/discovery_html.dart';

/// 关联系列 (条目系列)
///
/// 移植原项目 series 算法: 收藏 (看过/在看) → 条目关系
/// (/v0/subjects/{id}/subjects) → 并查集合并成系列组。
class SeriesGroup {
  final String name; // 系列名 (组内第一个条目)
  final List<Subject> subjects;

  const SeriesGroup({required this.name, required this.subjects});
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
  final collected = collections.where((e) => e.type == 2 || e.type == 3).toList();
  if (collected.isEmpty) return const [];

  // 2. 条目关系 → 邻接表
  final relations = <int, List<int>>{};
  Future<void> fetchRelations(int subjectId) async {
    try {
      final data = await client.get(apiV0SubjectSeries(subjectId));
      final list = (data as List).whereType<Map<String, dynamic>>();
      relations[subjectId] = list
          .where((e) => (e['type'] as num?)?.toInt() == 2 && kSeriesRelations.contains(e['relation']))
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

  final byId = <int, Subject>{};
  for (final e in collected) {
    byId[e.subjectId] = e.subject;
  }
  // 组内条目的名称/封面需要条目信息, 从收藏中补全 (未收藏的仅保留 id 占位)
  final result = <SeriesGroup>[];
  for (final ids in groups.values) {
    final unique = ids.toSet().toList()..sort();
    if (unique.length < 2) continue;
    final subjects = [
      for (final id in unique)
        byId[id] ??
            Subject(
              id: id,
              images: const SubjectImages(),
            ),
    ];
    result.add(SeriesGroup(name: subjects.first.displayName, subjects: subjects));
  }
  result.sort((a, b) => a.subjects.length.compareTo(b.subjects.length));
  return result.reversed.toList();
});

/// 关联系列
class SeriesScreen extends ConsumerWidget {
  const SeriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(isLoggedInProvider);
    final groups = ref.watch(seriesProvider);
    return Scaffold(
      appBar: BgmAppBar(title: '关联系列', showBackButton: true),
      body: !loggedIn
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('此功能依赖收藏数据, 请先登录'),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => context.push('/login'),
                    child: const Text('去登录'),
                  ),
                ],
              ),
            )
          : groups.when(
              loading: () => const Center(child: Loading()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('加载失败'),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(seriesProvider),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('收藏数据不足, 暂无关联系列'))
                  : RefreshIndicator(
                      onRefresh: () => ref.refresh(seriesProvider.future),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final group = list[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                                child: Text(
                                  '${group.name} (${group.subjects.length})',
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
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  itemCount: group.subjects.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                                  itemBuilder: (context, i) {
                                    final subject = group.subjects[i];
                                    return GestureDetector(
                                      onTap: () => context.push('/subject/${subject.id}'),
                                      child: SizedBox(
                                        width: 90,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                              style: const TextStyle(fontSize: 11),
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
                    ),
            ),
    );
  }
}
