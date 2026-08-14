import 'package:flutter/material.dart';

import 'advance_list.dart';
import 'tinygrail_notes.dart';

/// 买入推荐
class TinygrailAdvanceAskScreen extends StatelessWidget {
  const TinygrailAdvanceAskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdvanceListScreen(
      title: '买入推荐',
      provider: advanceAskProvider,
      valueLabel: '回报',
      notePath: tinygrailAdvanceAskNotePath(),
    );
  }
}
