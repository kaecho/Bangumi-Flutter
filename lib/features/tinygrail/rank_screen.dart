import 'package:flutter/material.dart';

import 'tinygrail_widgets.dart';

/// 排行榜: 热门/涨幅/跌幅/资金榜单
class TinygrailRankScreen extends StatelessWidget {
  const TinygrailRankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TinygrailCharaListScreen(
      title: '排行榜',
      tabs: [
        ('最高市值', 'mvc'),
        ('最大涨幅', 'mrc'),
        ('最大跌幅', 'mfc'),
        ('最高股息', 'msrc'),
      ],
    );
  }
}
