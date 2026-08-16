import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/site_cookies.dart';
import '../../design_system/design_system.dart';
import 'bgm_button.dart';
import 'cover.dart';

/// 原版 LIKE_TYPE
const kLikeTypeRakuen = 8;
const kLikeTypeTimeline = 40;
const kLikeTypeSay = 50;

/// 原版 likes-grid DATA: [emojiIndex, value]
const kLikesGridData = <(int, int)>[
  (67, 0),
  (63, 79),
  (38, 54),
  (124, 140),
  (46, 62),
  (106, 122),
  (88, 104),
  (64, 80),
  (125, 141),
  (72, 88),
  (69, 85),
  (74, 90),
];

/// 原版 DATA_TIMELINE: 8 个
const kLikesGridTimelineData = <(int, int)>[
  (67, 0),
  (88, 104),
  (38, 54),
  (124, 140),
  (106, 122),
  (74, 90),
  (72, 88),
  (64, 80),
];

List<(int, int)> likesGridData(int likeType) =>
    likeType == kLikeTypeTimeline || likeType == kLikeTypeSay
    ? kLikesGridTimelineData
    : kLikesGridData;

/// 原版 /img/smiles/tv/NN.gif
String bgmSmileUrl(int index) =>
    '$kHost/img/smiles/tv/${index.toString().padLeft(2, '0')}.gif';

int likesGridEmoji(int value) {
  for (final item in kLikesGridData) {
    if (item.$2 == value) return item.$1;
  }
  return 38;
}

Future<void> showLikesGrid({
  required BuildContext context,
  required WidgetRef ref,
  required int likeType,
  required int mainId,
  required int relatedId,
}) async {
  if (mainId <= 0 || relatedId <= 0) {
    showBgmToast(context, '暂时不能贴贴');
    return;
  }
  if (!ref.read(canActAsLoggedInProvider)) {
    await context.push('/login');
    return;
  }
  String gh = '';
  try {
    gh = await ref.read(formhashProvider.future);
  } catch (_) {}
  if (gh.isEmpty) {
    if (context.mounted) showBgmToast(context, '点赞需要站点 Cookie 登录');
    return;
  }
  if (!context.mounted) return;
  final value = await showBgmSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('贴贴', style: context.ds.section),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in likesGridData(likeType))
                  InkWell(
                    onTap: () => Navigator.of(ctx).pop('${item.$2}'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.ds.surfaceCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: context.ds.border,
                          width: 0.5,
                        ),
                      ),
                      child: Cover(
                        url: bgmSmileUrl(item.$1),
                        width: 28,
                        height: 28,
                        radius: 0,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (value == null) return;
  try {
    await ref
        .read(apiClientProvider)
        .post(
          apiLike(likeType, mainId, id: relatedId, value: value, gh: gh),
          host: kHost,
        );
    if (context.mounted) showBgmToast(context, '已贴贴');
  } catch (_) {
    if (context.mounted) showBgmToast(context, '点赞失败');
  }
}
