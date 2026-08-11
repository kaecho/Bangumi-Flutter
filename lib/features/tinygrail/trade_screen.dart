import 'package:flutter/material.dart';

import 'tinygrail_widgets.dart';

/// 交易大厅: 角色列表 (热门/涨幅/跌幅/市值/股息/最近活跃)
class TinygrailTradeScreen extends StatelessWidget {
  const TinygrailTradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TinygrailCharaListScreen(
      title: '交易大厅',
      tabs: [
        ('最高市值', 'mvc'),
        ('最大涨幅', 'mrc'),
        ('最大跌幅', 'mfc'),
        ('最高股息', 'msrc'),
        ('最近活跃', 'recent'),
      ],
    );
  }
}
