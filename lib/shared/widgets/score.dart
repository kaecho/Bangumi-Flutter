import 'package:flutter/material.dart';

import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';

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
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, _) {
        if (SettingsStore.instance.hideScore) return const SizedBox.shrink();
        final ds = context.ds;
        final text = score > 0 ? score.toStringAsFixed(1) : '--';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: fontSize + 2, color: ds.star),
            const SizedBox(width: AppGap.x1),
            Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: ds.star,
              ),
            ),
            if (showTotal && total > 0) ...[
              const SizedBox(width: AppGap.x1),
              Text('($total人评分)', style: ds.meta),
            ],
          ],
        );
      },
    );
  }
}

/// 原项目 ScoreTag: 粉色小芯片显示评分档位
class ScoreTag extends StatelessWidget {
  final num value;

  const ScoreTag({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final label = collectionRatingLabel(value);
    if (label.isEmpty) return const SizedBox.shrink();
    final ds = context.ds;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: dark ? ds.surfaceCard : ds.accent,
        borderRadius: AppRadius.sAll,
      ),
      child: Text(
        label,
        style: context.ds.caption.copyWith(
          color: dark ? ds.accent : Colors.white,
          fontSize: 12,
        ),
      ),
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
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, _) {
        if (SettingsStore.instance.hideScore) return const SizedBox.shrink();
        final c = color ?? context.ds.star;
        final value = (score / 2).clamp(0, 5);
        final full = value.floor();
        final hasHalf = (value - full) >= 0.25;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            if (i < full) {
              return Icon(Icons.star, size: size, color: c);
            }
            if (i == full && hasHalf) {
              return Icon(Icons.star_half, size: size, color: c);
            }
            return Icon(Icons.star_border, size: size, color: c);
          }),
        );
      },
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

/// 标签 Chip (胶囊形, 选中 = 主题色淡底 + 主题色文字)
class Tag extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback? onTap;

  const Tag({super.key, required this.text, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final Widget child = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppGap.x5,
        vertical: AppGap.x2,
      ),
      decoration: BoxDecoration(
        color: active ? ds.accentSoft : ds.surfaceCard,
        borderRadius: BorderRadius.circular(999),
        border: active ? null : Border.all(color: ds.border, width: 0.5),
      ),
      child: Text(
        text,
        style: active ? ds.caption.copyWith(color: ds.accent) : ds.caption,
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
    final ds = context.ds;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppGap.x6,
        AppGap.x7,
        AppGap.x6,
        AppGap.x4,
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: ds.accent,
              borderRadius: BorderRadius.circular(AppRadius.s),
            ),
          ),
          const SizedBox(width: AppGap.x3),
          Text(title, style: ds.section),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// 用户站龄 (原项目 UserAge)
class UserAgeBadge extends StatelessWidget {
  final String userId;

  const UserAgeBadge({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, _) {
        final store = SettingsStore.instance;
        if (!store.userAge) return const SizedBox.shrink();
        final label = userAgeLabel(userId, type: store.userAgeType);
        if (label == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            label,
            style: context.ds.tiny.copyWith(color: context.ds.textHint),
          ),
        );
      },
    );
  }
}

/// 原版 SectionTitle 右侧: 副文案 + md-navigate-next
class SectionMore extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const SectionMore({super.key, this.label = '更多', required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: context.ds.caption),
            Icon(
              Icons.navigate_next,
              size: 18,
              color: context.ds.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 列表底「加载更多」文字链, 对齐原版 Heatmap / Pagination 而非 M3 按钮
class LoadMoreLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const LoadMoreLink({super.key, this.label = '加载更多', required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Text(
            label,
            style: context.ds.caption.copyWith(color: context.ds.accent),
          ),
        ),
      ),
    );
  }
}
