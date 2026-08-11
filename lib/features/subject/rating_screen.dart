import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';
import 'subject_models.dart';
import 'subject_providers.dart';

/// 评分分布
/// 路由: /subject/:id/rating
class RatingScreen extends ConsumerWidget {
  final int id;

  const RatingScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(ratingStatsProvider(id));
    return Scaffold(
      appBar: BgmAppBar(title: '评分分布', showBackButton: true),
      body: stats.when(
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
                onPressed: () => ref.invalidate(ratingStatsProvider(id)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (value) => value.total == 0 && value.comments.isEmpty
            ? const Empty(text: '暂无评分数据')
            : RatingView(stats: value),
      ),
    );
  }
}

class RatingView extends ConsumerStatefulWidget {
  final RatingStats stats;
  const RatingView({super.key, required this.stats});

  @override
  ConsumerState<RatingView> createState() => _RatingViewState();
}

class _RatingViewState extends ConsumerState<RatingView> {
  int _filter = 0; // 0 = 全部, 1-10 = 按分数

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = widget.stats;
    final comments = _filter == 0
        ? stats.comments
        : stats.comments.where((c) => c.star == _filter).toList();
    final maxCount = stats.counts.values.fold<int>(0, (a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 总分 + 柱状图
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    stats.score > 0 ? stats.score.toStringAsFixed(1) : '--',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Stars(score: stats.score, size: 14),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${stats.total} 人评分${stats.rank > 0 ? ' · 排名 ${stats.rank}' : ''}',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (maxCount * 1.15).clamp(1, double.infinity).toDouble(),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                            BarTooltipItem(
                          '${group.x} 分: ${rod.toY.round()} 人',
                          TextStyle(
                            color: theme.colorScheme.onInverseSurface,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 34,
                          getTitlesWidget: (v, meta) => Text(
                            v.toInt().toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (v, meta) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              v.toInt().toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color: v.toInt() == _filter
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: theme.dividerColor.withValues(alpha: 0.5),
                        strokeWidth: 0.5,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      for (var score = 1; score <= 10; score++)
                        BarChartGroupData(
                          x: score,
                          barRods: [
                            BarChartRodData(
                              toY: stats.countOf(score).toDouble(),
                              width: 14,
                              color: score == _filter
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withValues(alpha: 0.55),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 分数筛选
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: '全部',
                selected: _filter == 0,
                onTap: () => setState(() => _filter = 0),
              ),
              for (var score = 1; score <= 10; score++)
                _FilterChip(
                  label: '$score 分',
                  selected: _filter == score,
                  onTap: () => setState(() => _filter = score),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '吐槽箱${_filter > 0 ? ' · $_filter 分' : ''} (${comments.length})',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        if (comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: const Center(
              child: Text('该分数段暂无吐槽', style: TextStyle(fontSize: 13)),
            ),
          )
        else
          for (final c in comments) _CommentTile(comment: c),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final SubjectCommentItem comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(url: comment.avatar, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.userName,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (comment.star > 0) ...[
                      const SizedBox(width: 4),
                      Stars(score: comment.star.toDouble(), size: 9),
                    ],
                    if (comment.time.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        comment.time,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(comment.content, style: const TextStyle(fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
