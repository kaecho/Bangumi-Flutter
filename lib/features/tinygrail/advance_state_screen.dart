import 'package:flutter/material.dart';

import 'advance_list.dart';

/// 低价股
class TinygrailAdvanceStateScreen extends StatelessWidget {
  const TinygrailAdvanceStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdvanceListScreen(
      title: '低价股',
      provider: advanceStateProvider,
      valueLabel: '一档价',
    );
  }
}
