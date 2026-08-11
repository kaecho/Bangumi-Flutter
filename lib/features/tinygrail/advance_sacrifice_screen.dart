import 'package:flutter/material.dart';

import 'advance_list.dart';

/// 献祭推荐
class TinygrailAdvanceSacrificeScreen extends StatelessWidget {
  const TinygrailAdvanceSacrificeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdvanceListScreen(
      title: '献祭推荐',
      provider: advanceSacrificeProvider,
      valueLabel: '增益',
    );
  }
}
