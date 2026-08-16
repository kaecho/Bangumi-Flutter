import 'package:flutter/material.dart';

import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';

/// 原版 HeaderV2Popover: 说明 + 工具栏锁定
List<(String, String)> seriesMoreItems({required bool fixed}) => [
  ('info', '说明'),
  ('toolbar', '工具栏〔${fixed ? '锁定' : '浮动'}〕'),
];

PreferredSizeWidget seriesAppBar({
  required BuildContext context,
  required VoidCallback onRefresh,
  required bool fixed,
  required ValueChanged<String> onMore,
}) {
  return BgmAppBar(
    title: '关联系列',
    showBackButton: true,
    actions: [
      BgmHeaderAction(
        tooltip: '刷新',
        icon: const Icon(Icons.refresh),
        onPressed: () async {
          final ok = await showBgmConfirm(
            context,
            title: '刷新关联系列',
            message: '刷新涉及大量请求与计算，若非必要请勿重复刷新，确定?',
          );
          if (ok) onRefresh();
        },
      ),
      BgmHeaderMore(
        items: seriesMoreItems(fixed: fixed),
        onSelected: onMore,
      ),
    ],
  );
}
