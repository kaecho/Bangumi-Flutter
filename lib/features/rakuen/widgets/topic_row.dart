import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/cover.dart';
import '../../rakuen/html_parse.dart';
import '../../../core/utils/display.dart';
import '../../../core/utils/format.dart';
import '../../../design_system/design_system.dart';
import '../../../shared/widgets/score.dart';

/// 原版小组时间格式: 最近 = 相对时间, 日期 = 绝对时间
String formatRakuenTopicTime(String time, {required bool lastDate}) {
  if (time.isEmpty) return '';
  final looksAbsolute =
      time.contains(RegExp(r'[年月]')) || time.contains(RegExp(r'^\d{4}-\d'));
  if (looksAbsolute) return time;
  return lastDate ? friendlyTime(time) : absoluteTime(time);
}

/// 帖子列表行 (小组/板块/搜索通用)
class RakuenTopicRow extends StatelessWidget {
  final RakuenTopicItem topic;
  final bool showGroup;
  final bool lastDate;

  const RakuenTopicRow({
    super.key,
    required this.topic,
    this.showGroup = true,
    this.lastDate = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBlog = topic.topicId.startsWith('blog/');
    final isMono =
        topic.topicId.startsWith('prsn/') || topic.topicId.startsWith('crt/');
    final isEp = topic.topicId.startsWith('ep/');
    final showUser = !isMono && !isEp;
    final showGroupLabel = showGroup && !isMono && topic.group.isNotEmpty;
    final timeText = formatRakuenTopicTime(topic.time, lastDate: lastDate);

    final meta = [
      if (timeText.isNotEmpty) timeText,
      if (showGroupLabel) topic.group,
      if (showUser && topic.userName.isNotEmpty) topic.userName,
    ].join(' / ');

    return InkWell(
      onTap: () {
        final id = topic.topicId;
        if (id.startsWith('blog/')) {
          final blogId = int.tryParse(id.split('/').last);
          if (blogId != null) {
            context.push('/rakuen/blog/$blogId');
            return;
          }
        }
        context.push('/rakuen/topic/$id');
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(
              url: topic.avatar.startsWith('//')
                  ? 'https:${topic.avatar}'
                  : topic.avatar,
              size: 34,
              name: topic.userName,
              userId: topic.userId,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: topic.title),
                          if (topic.replyCount > 0)
                            TextSpan(
                              text: ' +${topic.replyCount}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          if (isBlog)
                            TextSpan(
                              text: '  日志',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: theme.hintColor,
                              ),
                            ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: visualFontSize(topic.title, const [
                          (20, 13),
                          (0, 14),
                        ]),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              meta,
                              style: context.ds.meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showUser && topic.userId.isNotEmpty)
                            UserAgeBadge(userId: topic.userId),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
