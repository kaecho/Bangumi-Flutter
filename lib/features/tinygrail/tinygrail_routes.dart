import 'package:go_router/go_router.dart';

import 'advance_ask_screen.dart';
import 'advance_auction2_screen.dart';
import 'advance_auction_screen.dart';
import 'advance_bid_screen.dart';
import 'advance_sacrifice_screen.dart';
import 'advance_screen.dart';
import 'advance_state_screen.dart';
import 'assets_screen.dart';
import 'auction_screen.dart';
import 'bid_screen.dart';
import 'chara_assets_screen.dart';
import 'chara_screen.dart';
import 'chara_temple_screen.dart';
import 'clipboard_screen.dart';
import 'deal_screen.dart';
import 'fantasy_screen.dart';
import 'ico_deal_screen.dart';
import 'ico_screen.dart';
import 'initial_screen.dart';
import 'items_screen.dart';
import 'login_screen.dart';
import 'logs_screen.dart';
import 'lottery_rank_screen.dart';
import 'new_bangumi_screen.dart';
import 'rank_screen.dart';
import 'relation_screen.dart';
import 'rich_screen.dart';
import 'sacrifice_screen.dart';
import 'search_screen.dart';
import 'star_logs_screen.dart';
import 'star_rank_screen.dart';
import 'star_screen.dart';
import 'temple_screen.dart';
import 'temples_screen.dart';
import 'top_week_screen.dart';
import 'trade_screen.dart';
import 'valhalla_screen.dart';

/// 小圣杯域路由
final List<GoRoute> tinygrailRoutes = [
  GoRoute(path: '/tinygrail/login', builder: (_, _) => const TinygrailLoginScreen()),
  GoRoute(path: '/tinygrail/trade', builder: (_, _) => const TinygrailTradeScreen()),
  GoRoute(path: '/tinygrail/chara/:id', builder: (_, state) {
    final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
    return TinygrailCharaScreen(monoId: id);
  }),
  GoRoute(path: '/tinygrail/chara/:id/temple', builder: (_, state) {
    final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
    return TinygrailCharaTempleScreen(monoId: id);
  }),
  GoRoute(path: '/tinygrail/chara/:id/valhalla', builder: (_, state) {
    final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
    return TinygrailCharaValhallaScreen(monoId: id);
  }),
  GoRoute(path: '/tinygrail/rank', builder: (_, _) => const TinygrailRankScreen()),
  GoRoute(path: '/tinygrail/rich', builder: (_, _) => const TinygrailRichScreen()),
  GoRoute(path: '/tinygrail/star', builder: (_, _) => const TinygrailStarScreen()),
  GoRoute(path: '/tinygrail/star-rank', builder: (_, _) => const TinygrailStarRankScreen()),
  GoRoute(path: '/tinygrail/star-logs', builder: (_, _) => const TinygrailStarLogsScreen()),
  GoRoute(path: '/tinygrail/fantasy', builder: (_, _) => const TinygrailFantasyScreen()),
  GoRoute(path: '/tinygrail/valhalla', builder: (_, _) => const TinygrailValhallaScreen()),
  GoRoute(path: '/tinygrail/temple', builder: (_, _) => const TinygrailTempleScreen()),
  GoRoute(path: '/tinygrail/temples', builder: (_, _) => const TinygrailTemplesScreen()),
  GoRoute(path: '/tinygrail/auction', builder: (_, _) => const TinygrailAuctionScreen()),
  GoRoute(path: '/tinygrail/assets', builder: (_, _) => const TinygrailAssetsScreen()),
  GoRoute(path: '/tinygrail/logs', builder: (_, _) => const TinygrailLogsScreen()),
  GoRoute(path: '/tinygrail/ico', builder: (_, _) => const TinygrailIcoScreen()),
  GoRoute(path: '/tinygrail/ico-deal/:id', builder: (_, state) {
    final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
    return TinygrailIcoDealScreen(monoId: id);
  }),
  GoRoute(path: '/tinygrail/initial', builder: (_, state) {
    final id = int.tryParse(state.uri.queryParameters['icoId'] ?? '') ?? 0;
    return TinygrailInitialScreen(icoId: id);
  }),
  GoRoute(path: '/tinygrail/sacrifice', builder: (_, _) => const TinygrailSacrificeScreen()),
  GoRoute(path: '/tinygrail/search', builder: (_, _) => const TinygrailSearchScreen()),
  GoRoute(path: '/tinygrail/top-week', builder: (_, _) => const TinygrailTopWeekScreen()),
  GoRoute(path: '/tinygrail/lottery-rank', builder: (_, _) => const TinygrailLotteryRankScreen()),
  GoRoute(path: '/tinygrail/new-bangumi', builder: (_, _) => const TinygrailNewBangumiScreen()),
  GoRoute(path: '/tinygrail/advance', builder: (_, _) => const TinygrailAdvanceScreen()),
  GoRoute(path: '/tinygrail/advance-ask', builder: (_, _) => const TinygrailAdvanceAskScreen()),
  GoRoute(path: '/tinygrail/advance-bid', builder: (_, _) => const TinygrailAdvanceBidScreen()),
  GoRoute(path: '/tinygrail/advance-sacrifice', builder: (_, _) => const TinygrailAdvanceSacrificeScreen()),
  GoRoute(path: '/tinygrail/advance-auction', builder: (_, _) => const TinygrailAdvanceAuctionScreen()),
  GoRoute(path: '/tinygrail/advance-auction2', builder: (_, _) => const TinygrailAdvanceAuction2Screen()),
  GoRoute(path: '/tinygrail/advance-state', builder: (_, _) => const TinygrailAdvanceStateScreen()),
  GoRoute(path: '/tinygrail/chara-assets', builder: (_, _) => const TinygrailCharaAssetsScreen()),
  GoRoute(path: '/tinygrail/relation', builder: (_, state) {
    final ids = (state.uri.queryParameters['ids'] ?? '')
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    return TinygrailRelationScreen(ids: ids);
  }),
  GoRoute(path: '/tinygrail/bid', builder: (_, _) => const TinygrailBidScreen()),
  GoRoute(path: '/tinygrail/deal/:id', builder: (_, state) {
    final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
    return TinygrailDealScreen(monoId: id);
  }),
  GoRoute(path: '/tinygrail/items', builder: (_, _) => const TinygrailItemsScreen()),
  GoRoute(path: '/tinygrail/clipboard', builder: (_, _) => const TinygrailClipboardScreen()),
];
