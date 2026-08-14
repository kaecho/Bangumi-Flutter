import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/cover.dart';
import '../../rakuen/html_parse.dart';
import '../../../core/utils/display.dart';
import '../../../core/utils/format.dart';
import '../../../design_system/design_system.dart';
import '../../../shared/widgets/score.dart';

/// 帖子列表行 (小组/板块/搜索通用)
class RakuenTopicRow extends StatelessWidget {
  final RakuenTopicItem topic;
  final bool showGroup;

  const RakuenTopicRow({super.key, required this.topic, this.showGroup = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (showGroup && topic.group.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            topic.group,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      if (showGroup && topic.group.isNotEmpty)
                        const SizedBox(width: 6),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                topic.userName,
                                style: context.ds.meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            UserAgeBadge(userId: topic.userId),
                          ],
                        ),
                      ),
                      if (topic.time.isNotEmpty)
                        Text(
                          topic.time.contains(RegExp(r'[年月]')) ||
                                  topic.time.contains(RegExp(r'^\d{4}-\d'))
                              ? topic.time
                              : friendlyTime(topic.time),
                          style: context.ds.tiny,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (topic.replyCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '${topic.replyCount}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
