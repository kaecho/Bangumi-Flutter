import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/cover.dart';
import '../../../core/html/bgm_html_parser.dart' as core;
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/site_cookies.dart';
import '../../../core/storage/settings_store.dart';
import '../../rakuen/rakuen_settings.dart';

import '../../../shared/widgets/bgm_html.dart';
import '../../../core/utils/display.dart';
import '../../../core/utils/format.dart';
import '../../../design_system/design_system.dart';
import '../../../shared/widgets/score.dart';
import '../../../shared/widgets/bgm_button.dart';
import '../../../shared/widgets/likes_grid.dart';

import 'fixed_textarea.dart';

/// 帖子楼层视图 (主楼层 + 子回复)
class FloorView extends ConsumerWidget {
  final core.RakuenFloor floor;
  final String floorLabel;
  final bool isAuthor;
  final RakuenSettingsState settings;
  final void Function(ReplyTarget target)? onReply;
  final bool isSub;

  /// 主题 ID (用于贴贴/复制链接; 为空时隐藏贴贴与链接菜单)
  final String topicId;
  final int likeType;

  /// 是否已手动展开全部子回复
  final bool expanded;
  final VoidCallback? onExpand;

  /// 长楼层正文是否展开 (漂浮收起)
  final bool htmlExpanded;
  final VoidCallback? onHtmlToggle;

  const FloorView({
    super.key,
    required this.floor,
    required this.floorLabel,
    required this.isAuthor,
    required this.settings,
    this.onReply,
    this.isSub = false,
    this.topicId = '',
    this.likeType = 8,
    this.expanded = false,
    this.onExpand,
    this.htmlExpanded = false,
    this.onHtmlToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    // 原版: 0=一直折叠; 2/4/8=超过后折叠溢出
    final subExpand = int.tryParse(settings.subExpand) ?? 4;
    final limit = subExpand <= 0 ? 0 : subExpand;
    final showAllSubs = expanded || floor.subReplies.length <= limit;
    final visibleSubs = showAllSubs
        ? floor.subReplies
        : floor.subReplies.take(limit).toList();
    final hiddenSubs = floor.subReplies.length - visibleSubs.length;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: settings.wide ? 16 : 12,
        vertical: 8,
      ),
      child: GestureDetector(
        onLongPress: () => _showFloorMenu(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Avatar(
                      url: avatar,
                      size: isSub ? 26 : 36,
                      name: floor.userName,
                      userId: floor.userId,
                    ),
                    if (settings.isTracked(floor.userId))
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Icon(
                          Icons.star,
                          size: 12,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayText(
                                floor.userName.isEmpty ? '匿名' : floor.userName,
                              ),
                              style: TextStyle(
                                fontSize: isSub ? 12 : 13,
                                fontWeight: isAuthor
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isAuthor
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          UserAgeBadge(userId: floor.userId),

                          if (isAuthor)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '楼主',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          const Spacer(),
                          if (floorLabel.isNotEmpty)
                            _FloorBadge(label: floorLabel, settings: settings),
                          if (floor.time.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              friendlyTime(floor.time),
                              style: context.ds.tiny,
                            ),
                          ],
                          if (ref.watch(settingsStoreProvider).showSource &&
                              floor.source.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(floor.source, style: context.ds.tiny),
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
                      if (msg.isNotEmpty)
                        settings.showFoldButton && msg.length > 480
                            ? _FoldableHtml(
                                html: msg,
                                showImages: settings.loadImages,
                                matchLink: settings.matchLink,
                                emojiSize: settings.bigEmojiSize,
                                expanded: htmlExpanded,
                                onToggle: onHtmlToggle,
                              )
                            : BgmHtml(
                                data: msg,
                                showImages: settings.loadImages,
                                matchLink: settings.matchLink,
                                emojiSize: settings.bigEmojiSize,
                              ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isSub)
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (settings.likes && floor.likes > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '${floor.likes} 贴贴',
                          style: context.ds.tiny,
                        ),
                      ),

                    if (onReply != null)
                      InkWell(
                        onTap: () => onReply!(
                          ReplyTarget(
                            userName: floor.userName,
                            messageHtml: floor.messageHtml,
                            replySub: floor.replySub,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.reply_outlined,
                            size: 16,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (floor.subReplies.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6, left: 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
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
                        isAuthor: isAuthor && sub.userId == floor.userId,

                        settings: settings,
                        isSub: true,
                        onReply: onReply,
                        topicId: topicId,
                        likeType: likeType,
                      ),
                    if (floor.subReplies.length > limit)
                      _ExpandSubsButton(
                        count: hiddenSubs,
                        expanded: expanded,
                        onTap: onExpand,
                      ),
                  ],
                ),
              ),
            const BgmHairline(),
          ],
        ),
      ),
    );
  }

  /// 楼层长按菜单 (原项目楼层操作菜单)
  Future<void> _showFloorMenu(BuildContext context, WidgetRef ref) async {
    final isBlocked = settings.isUserBlocked(floor.userId);
    final canLike = topicId.isNotEmpty && floor.id.isNotEmpty;
    final canDisconnect = floor.userId.isNotEmpty;

    final action = await showBgmSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BgmActionRow(
              title:
                  '$floorLabel. ${floor.userName.isEmpty ? '匿名' : floor.userName}',
            ),
            const BgmHairline(),
            if (onReply != null)
              BgmActionRow(
                title: '回复',
                onTap: () => Navigator.of(ctx).pop('reply'),
              ),
            if (canLike)
              BgmActionRow(
                title: '贴贴',
                onTap: () => Navigator.of(ctx).pop('like'),
              ),
            BgmActionRow(
              title: '复制文本',
              onTap: () => Navigator.of(ctx).pop('copy'),
            ),
            if (canLike)
              BgmActionRow(
                title: '复制链接',
                onTap: () => Navigator.of(ctx).pop('copyLink'),
              ),
            BgmActionRow(
              title: isBlocked ? '解除屏蔽' : '屏蔽用户',
              onTap: () => Navigator.of(ctx).pop('block'),
            ),
            if (canDisconnect)
              BgmActionRow(
                title: '绝交',
                onTap: () => Navigator.of(ctx).pop('disconnect'),
              ),
            if (floor.userId.isNotEmpty)
              BgmActionRow(
                title: settings.isTracked(floor.userId) ? '取消追踪' : '追踪回复',
                onTap: () => Navigator.of(ctx).pop('track'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case 'reply':
        onReply?.call(
          ReplyTarget(
            userName: floor.userName,
            messageHtml: floor.messageHtml,
            replySub: floor.replySub,
          ),
        );
      case 'like':
        await showLikesGrid(
          context: context,
          ref: ref,
          likeType: likeType,
          mainId: int.tryParse(topicId.split('/').last) ?? 0,
          relatedId: int.tryParse(floor.id) ?? 0,
        );
      case 'copy':
        await Clipboard.setData(
          ClipboardData(text: stripHtml(floor.messageHtml)),
        );
        if (context.mounted) {
          showBgmToast(context, '已复制', duration: const Duration(seconds: 1));
        }
      case 'copyLink':
        await Clipboard.setData(
          ClipboardData(text: htmlTopicPage(topicId, postId: floor.id)),
        );
        if (context.mounted) {
          showBgmToast(context, '已复制链接', duration: const Duration(seconds: 1));
        }
      case 'block':
        await ref
            .read(rakuenSettingsProvider.notifier)
            .addBlockUser(floor.userId);
      case 'disconnect':
        await _disconnectUser(ref);
      case 'track':
        await ref
            .read(rakuenSettingsProvider.notifier)
            .toggleTrackUser(floor.userId);
    }
  }

  /// 绝交: GET /disconnect/{userId}?gh={formhash}
  Future<void> _disconnectUser(WidgetRef ref) async {
    final gh = await _formhash(ref);
    if (gh.isEmpty) return;
    try {
      await ref.read(apiClientProvider).get(apiDisconnect(floor.userId, gh));
    } catch (e) {
      // 绝交失败静默
    }
  }

  Future<String> _formhash(WidgetRef ref) async {
    try {
      return await ref.read(formhashProvider.future);
    } catch (_) {
      return '';
    }
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
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
              ),
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
  final bool expanded;
  final VoidCallback? onTap;

  const _ExpandSubsButton({
    required this.count,
    this.expanded = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Text(
          expanded ? '收起楼层' : '展开 $count 条回复',
          style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}

class _FoldableHtml extends StatefulWidget {
  final String html;
  final bool showImages;
  final bool matchLink;
  final int emojiSize;
  final bool expanded;
  final VoidCallback? onToggle;

  const _FoldableHtml({
    required this.html,
    required this.showImages,
    this.matchLink = false,
    this.emojiSize = 36,
    this.expanded = false,
    this.onToggle,
  });

  @override
  State<_FoldableHtml> createState() => _FoldableHtmlState();
}

class _FoldableHtmlState extends State<_FoldableHtml> {
  late bool _expanded = widget.expanded;

  @override
  void didUpdateWidget(covariant _FoldableHtml oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) {
      _expanded = widget.expanded;
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    widget.onToggle?.call();
  }

  @override
  Widget build(BuildContext context) {
    final html = BgmHtml(
      data: widget.html,
      showImages: widget.showImages,
      matchLink: widget.matchLink,
      emojiSize: widget.emojiSize,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_expanded)
          html
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ClipRect(child: html),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _toggle,
            child: Text(
              _expanded ? '收起' : '展开',
              style: context.ds.caption.copyWith(color: context.ds.accent),
            ),
          ),
        ),
      ],
    );
  }
}
