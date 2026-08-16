import 'package:flutter/material.dart';

import 'advance_list.dart';
import 'tinygrail_notes.dart';


/// 卖出推荐
class TinygrailAdvanceBidScreen extends StatelessWidget {
  const TinygrailAdvanceBidScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdvanceListScreen(
      title: '卖出推荐',
      provider: advanceBidProvider,
      valueLabel: '评分',
      notePath: tinygrailAdvanceBidNotePath(),
    );
  }
}
