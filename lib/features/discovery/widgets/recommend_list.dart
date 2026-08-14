import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/models/collection.dart';
import '../../../shared/models/subject.dart';
import '../../../shared/widgets/cover.dart';
import '../../../shared/widgets/loading.dart';
import '../../../shared/widgets/score.dart';
import '../../subject/collection_sheet.dart';
import 'discovery_html.dart';

/// 猜你喜欢推荐项 (基于用户收藏的客户端评分, 对应原项目 like 的 calc())
class RecommendItem {
  final Subject subject;
  final int type; // 收藏状态
  final int epStatus;
  final String updatedAt;
  final double score;

  const RecommendItem({
    required this.subject,
    this.type = 0,
    this.epStatus = 0,
    this.updatedAt = '',
    this.score = 0,
  });

  /// 推荐理由 (简化自原项目 getReasonsInfo)
  String get reasonText {
    final reasons = <String>[];
    if (subject.rating != null && subject.rating!.score > 0) {
      reasons.add('条目分数高');
    }
    if (subject.rank > 0 && subject.rank <= 500) reasons.add('排名靠前');
    if (subject.tags.isNotEmpty) {
      reasons.add('标签倾向 ${subject.tags.take(2).map((t) => t.name).join('/')}');
    }
    if (subject.collection != null && subject.collection!.collect > 1000) {
      reasons.add('人气收藏');
    }

    return reasons.isEmpty
        ? '推荐值 ${score.toStringAsFixed(1)}'
        : reasons.take(2).join(' / ');
  }
}

/// 类型 Tab (v0 subject_type 数字)
const kRecommendTypes = [
  (2, '动画'),
  (1, '书籍'),
  (4, '游戏'),
  (3, '音乐'),
  (6, '三次元'),
];

/// 拉取用户某类型的全部收藏 (各状态第一页, 每页 100)
Future<List<V0CollectionItem>> fetchUserCollectionsAll(
  Ref ref,
  String userId,
  int subjectType,
) async {
  final client = ref.read(apiClientProvider);
  final all = <V0CollectionItem>[];
  for (final status in const [1, 3, 2, 4, 5]) {
    try {
      final data = await client.get(
        apiV0UsersCollections(userId, '$subjectType', 100, 0, '$status'),
      );
      all.addAll(parseV0Collections(data));
    } catch (_) {
      // 单状态失败不影响其他
    }
  }
  return all;
}

/// 推荐评分 (简化自原项目 calc: rate/rank/score/时间/标签 加权)
double calcRecommendScore(V0CollectionItem item) {
  var score = 0.0;
  final subject = item.subject;
  if (item.type >= 1 && item.type <= 5) {
    score += (item.type == 2 || item.type == 3) ? 2 : 1;
  }
  if (subject.rating != null) score += (subject.rating!.score / 10) * 3;
  if (subject.rank > 0) {
    score += subject.rank <= 100 ? 2 : (subject.rank <= 500 ? 1 : 0.5);
  }

  if (item.updatedAt.isNotEmpty) {
    final date = DateTime.tryParse(item.updatedAt.replaceFirst(' ', 'T'));
    if (date != null) {
      final days = DateTime.now().difference(date).inDays;
      if (days <= 7) score += 1.5;
    }
  }
  if (subject.tags.isNotEmpty) score += 0.5;
  return score;
}

/// 猜你喜欢列表 (like / recommend 共用)
class RecommendList extends ConsumerWidget {
  final int subjectType; // 1=book 2=anime 3=music 4=game 6=real

  const RecommendList({super.key, required this.subjectType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recommendProvider(subjectType));
    return items.when(
      loading: () => const Center(child: Loading()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('加载失败'),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(recommendProvider(subjectType)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (list) => list.isEmpty
          ? const Center(child: Text('收藏数据不足, 无法推荐'))
          : RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(recommendProvider(subjectType).future),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  return InkWell(
                    onTap: () => context.push('/subject/${item.subject.id}'),
                    onLongPress: () =>
                        showCollectionSheet(context, item.subject.id),

                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Cover(
                            url: item.subject.images.medium,
                            width: 56,
                            height: 75,
                            radius: 6,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.subject.displayName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '推荐值 ${item.score.toStringAsFixed(1)} · ${SubjectType.statusText(item.type, item.subject.type)}',

                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.reasonText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.subject.rating != null &&
                              item.subject.rating!.score > 0)
                            Score(
                              score: item.subject.rating!.score,
                              total: 0,
                              fontSize: 11,
                              showTotal: false,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

/// 猜你喜欢数据: 收藏 → 客户端评分 → 降序
final recommendProvider = FutureProvider.family<List<RecommendItem>, int>((
  ref,
  subjectType,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final userId = user.username.isEmpty ? '${user.id}' : user.username;
  final collections = await fetchUserCollectionsAll(ref, userId, subjectType);
  final items =
      collections
          .map(
            (item) => RecommendItem(
              subject: item.subject,
              type: item.type,
              epStatus: item.epStatus,
              updatedAt: item.updatedAt,
              score: calcRecommendScore(item),
            ),
          )
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));
  return items.take(200).toList();
});
