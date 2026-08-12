import 'package:flutter/material.dart';

import '../../../shared/widgets/cover.dart';
import '../../../core/html/bgm_html_parser.dart' as core;
import '../../rakuen/rakuen_settings.dart';
import '../../../shared/widgets/bgm_html.dart';
import '../../../core/utils/format.dart';
import '../../../design_system/design_system.dart';

/// 帖子楼层视图 (主楼层 + 子回复)
class FloorView extends StatelessWidget {
  final core.RakuenFloor floor;
  final String floorLabel;
  final bool isAuthor;
  final RakuenSettingsState settings;
  final void Function(String userName)? onReply;
  final bool isSub;

  /// 是否已手动展开全部子回复
  final bool expanded;
  final VoidCallback? onExpand;

  const FloorView({
    super.key,
    required this.floor,
    required this.floorLabel,
    required this.isAuthor,
    required this.settings,
    this.onReply,
    this.isSub = false,
    this.expanded = false,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatar = floor.avatar;

    // 屏蔽默认头像
    if (settings.blockDefaultUser && avatar.isEmpty) {
      return const SizedBox.shrink();
    }
    // 屏蔽用户
    if (settings.isUserBlocked(floor.userId)) {
      return const SizedBox.shrink();
    }
    // 屏蔽关键词
    if (settings.matchesKeyword('${floor.userName}${floor.messageHtml}')) {
      return const SizedBox.shrink();
    }
    // 过滤用户删除的楼层
    final msg = floor.messageHtml.trim();
    if (settings.filterDelete &&
        (msg.isEmpty || msg.contains('该楼层内容已被删除') || msg.contains('该回复已被删除'))) {
      return const SizedBox.shrink();
    }

    final subExpand = int.tryParse(settings.subExpand) ?? 0;
    final showAllSubs = expanded || subExpand == 0 || floor.subReplies.length <= subExpand;
    final visibleSubs = showAllSubs ? floor.subReplies : floor.subReplies.take(subExpand).toList();
    final hiddenSubs = floor.subReplies.length - visibleSubs.length;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: settings.wide ? 16 : 12,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Avatar(url: avatar, size: isSub ? 26 : 36, name: floor.userName),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            floor.userName.isEmpty ? '匿名' : floor.userName,
                            style: TextStyle(
                              fontSize: isSub ? 12 : 13,
                              fontWeight: isAuthor ? FontWeight.w600 : FontWeight.w400,
                              color: isAuthor ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isAuthor)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '楼主',
                              style: TextStyle(fontSize: 9, color: theme.colorScheme.primary),
                            ),
                          ),
                        const Spacer(),
                        if (floorLabel.isNotEmpty) _FloorBadge(label: floorLabel, settings: settings),
                        if (floor.time.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            friendlyTime(floor.time),
                            style: context.ds.tiny,
                          ),
                        ],
                      ],
                    ),
                    if (floor.userSign.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          floor.userSign,
                          style: context.ds.tiny,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (msg.isNotEmpty) BgmHtml(data: msg, showImages: settings.loadImages),
                  ],
                ),
              ),
            ],
          ),
          if (onReply != null && !isSub)
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => onReply!(floor.userName),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.reply_outlined, size: 16, color: theme.colorScheme.outline),
                ),
              ),
            ),
          if (floor.subReplies.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6, left: 36),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, sub) in visibleSubs.indexed)
                    FloorView(
                      floor: sub,
                      floorLabel: sub.floor.isNotEmpty
                          ? sub.floor
                          : '${floorLabel.isEmpty ? '' : floorLabel}-${i + 1}',
                      isAuthor: isAuthor,
                      settings: settings,
                      isSub: true,
                      onReply: onReply,
                    ),
                  if (hiddenSubs > 0)
                    _ExpandSubsButton(
                      count: hiddenSubs,
                      onTap: onExpand,
                    ),
                ],
              ),
            ),
          const Divider(height: 12),
        ],
      ),
    );
  }
}

/// 楼层号样式 (newFloorStyle: A=角标 B=红点 C=背景 D=不设置)
class _FloorBadge extends StatelessWidget {
  final String label;
  final RakuenSettingsState settings;

  const _FloorBadge({required this.label, required this.settings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Text(
      label,
      style: TextStyle(
        fontSize: 10,
        color: settings.floorStyle == 'B'
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
        fontWeight: FontWeight.w500,
      ),
    );
    switch (settings.floorStyle) {
      case 'A': // 角标
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: text,
        );
      case 'B': // 红点
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: theme.colorScheme.error, shape: BoxShape.circle),
            ),
            const SizedBox(width: 3),
            text,
          ],
        );
      case 'C': // 背景
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: text,
        );
      default: // D: 不设置
        return text;
    }
  }
}

class _ExpandSubsButton extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const _ExpandSubsButton({required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Text(
          '展开 $count 条回复',
          style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}
