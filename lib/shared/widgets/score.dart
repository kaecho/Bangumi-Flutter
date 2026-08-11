import 'package:flutter/material.dart';

/// 评分组件 (数字 + 星级)
class Score extends StatelessWidget {
  final double score;
  final int total;
  final double fontSize;
  final bool showTotal;

  const Score({
    super.key,
    required this.score,
    this.total = 0,
    this.fontSize = 12,
    this.showTotal = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final text = score > 0 ? score.toStringAsFixed(1) : '--';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: fontSize + 2, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: color),
        ),
        if (showTotal && total > 0) ...[
          const SizedBox(width: 3),
          Text(
            '($total人评分)',
            style: TextStyle(fontSize: fontSize - 2, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// 星级组件 (1-10 分制 → 半星展示)
class Stars extends StatelessWidget {
  final double score;
  final double size;
  final Color? color;

  const Stars({super.key, required this.score, this.size = 10, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final value = (score / 2).clamp(0, 5);
    final full = value.floor();
    final half = (value - full) >= 0.25 && (value - full) < 0.75;
    final hasHalf = (value - full) >= 0.25;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) {
          return Icon(Icons.star, size: size, color: c);
        }
        if (i == full && half) {
          return Icon(Icons.star_half, size: size, color: c);
        }
        if (i == full && hasHalf && !half) {
          return Icon(Icons.star_half, size: size, color: c);
        }
        return Icon(Icons.star_border, size: size, color: c);
      }),
    );
  }
}

/// 收藏数文案
String collectionCountText(Map<String, int> counts) {
  final parts = <String>[];
  if ((counts['wish'] ?? 0) > 0) parts.add('${counts['wish']} 期望');
  if ((counts['doing'] ?? 0) > 0) parts.add('${counts['doing']} 在看');
  if ((counts['collect'] ?? 0) > 0) parts.add('${counts['collect']} 看过');
  if ((counts['on_hold'] ?? 0) > 0) parts.add('${counts['on_hold']} 搁置');
  if ((counts['dropped'] ?? 0) > 0) parts.add('${counts['dropped']} 抛弃');
  return parts.join(' / ');
}

/// 标签 Chip
class Tag extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback? onTap;
  final double fontSize;

  const Tag({super.key, required this.text, this.active = false, this.onTap, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
        border: active ? null : Border.all(color: theme.dividerColor, width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          color: active ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}

/// 区块标题 (section header)
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}
