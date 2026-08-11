import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/subject.dart';
import '../../../shared/widgets/cover.dart';

/// 条目网格卡片: 封面 + 排名角标 + 标题 + 评分/集数
///
/// Discovery 各列表页通用 (搜索 / 排行榜 / 标签 / 目录详情 / 新番等)。
class SubjectCard extends StatelessWidget {
  final Subject subject;

  /// 排名角标 (从 1 开始), 前 3 名高亮
  final int? rank;
  final bool showScore;
  final bool showEps;

  /// 封面下方信息行文案 (如 放送时间/季度), 优先级高于评分
  final String? subtitle;
  final VoidCallback? onTap;

  const SubjectCard({
    super.key,
    required this.subject,
    this.rank,
    this.showScore = true,
    this.showEps = false,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = subject.rating;
    final info = subtitle ??
        (showScore && rating != null && rating.score > 0
            ? '${rating.score.toStringAsFixed(1)}分'
            : '');

    return InkWell(
      onTap: onTap ?? () => context.push('/subject/${subject.id}'),
      borderRadius: BorderRadius.circular(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Cover(
                  url: subject.images.medium,
                  width: double.infinity,
                  height: double.infinity,
                  radius: 6,
                ),
                if (rank != null && rank! > 0)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rank! <= 3
                            ? theme.colorScheme.primary
                            : Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: rank! <= 3
                              ? theme.colorScheme.onPrimary
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subject.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.25,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          if (info.isNotEmpty)
            Text(
              info,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            )
          else if (showEps && subject.eps > 0)
            Text(
              '全 ${subject.eps} 话',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
