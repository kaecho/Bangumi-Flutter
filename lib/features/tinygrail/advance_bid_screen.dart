import 'package:flutter/material.dart';

import 'advance_list.dart';

/// 卖出推荐
class TinygrailAdvanceBidScreen extends StatelessWidget {
  const TinygrailAdvanceBidScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdvanceListScreen(
      title: '卖出推荐',
      provider: advanceBidProvider,
      valueLabel: '评分',
    );
  }
}
