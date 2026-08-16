import 'package:flutter/material.dart';

import 'tinygrail_widgets.dart';

/// 新番角色: 最近活跃/最高市值
class TinygrailNewBangumiScreen extends StatelessWidget {
  const TinygrailNewBangumiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TinygrailCharaListScreen(
      title: '新番榜单',
      showIconGo: true,
      tabs: [('最近活跃', 'nbc'), ('最高市值', 'tnbc')],
    );
  }
}
