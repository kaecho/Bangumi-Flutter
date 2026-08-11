import 'package:flutter/material.dart';

import 'advance_list.dart';

/// 拍卖推荐 B
class TinygrailAdvanceAuction2Screen extends StatelessWidget {
  const TinygrailAdvanceAuction2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdvanceListScreen(
      title: '拍卖推荐 B',
      provider: advanceAuction2Provider,
      valueLabel: '回报',
    );
  }
}
