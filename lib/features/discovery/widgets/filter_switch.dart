import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/design_system.dart';

/// 原项目 TEXT_TOTAL + FILTER_SWITCH_DS / PATH_MAP
const kFilterSwitchDs = [
  ('番剧', '/anime', 5113),
  ('游戏', '/game', 2837),
  ('漫画', '/manga', 10622),
  ('文库', '/wenku', 2740),
  ('ADV', '/adv', 3600),
  ('NSFW', '/nsfw', 5987),
];

/// 找番剧 / 游戏 / 漫画 / 文库 / ADV / NSFW 共用频道条
class DiscoveryFilterSwitch extends StatelessWidget {
  final String name;
  final String title;

  const DiscoveryFilterSwitch({
    super.key,
    required this.name,
    this.title = '频道',
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Text(title, style: ds.caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in kFilterSwitchDs)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: GestureDetector(
                        onTap: item.$1 == name
                            ? null
                            : () => context.replace(item.$2),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: item.$1 == name
                                ? ds.surfaceCard
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text.rich(
                            TextSpan(
                              text: item.$1,
                              style: ds.caption.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              children: [
                                TextSpan(
                                  text: ' ${item.$3}',
                                  style: ds.tiny.copyWith(
                                    color: ds.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
