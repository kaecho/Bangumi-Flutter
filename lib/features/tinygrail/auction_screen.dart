import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bid_screen.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';

/// Extra: 我的拍卖 is bid tab type=auction
class TinygrailAuctionScreen extends StatelessWidget {
  const TinygrailAuctionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TinygrailBidScreen(initialType: 'auction');
  }
}

final myAuctionProvider = FutureProvider<List<TinygrailAuctionItem>>((
  ref,
) async {
  return ref.read(tinygrailApiProvider).fetchMyAuction();
});
