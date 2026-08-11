import 'package:flutter/material.dart';

import 'advance_list.dart';

/// 拍卖推荐
class TinygrailAdvanceAuctionScreen extends StatelessWidget {
  const TinygrailAdvanceAuctionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdvanceListScreen(
      title: '拍卖推荐',
      provider: advanceAuctionProvider,
      valueLabel: '回报',
    );
  }
}
