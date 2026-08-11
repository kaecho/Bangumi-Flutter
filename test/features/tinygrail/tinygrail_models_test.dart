import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/features/tinygrail/tinygrail_models.dart';

void main() {
  group('TinygrailChara.fromJson', () {
    test('parses list item shape (CharacterId top-level)', () {
      final chara = TinygrailChara.fromJson({
        'CharacterId': 3589,
        'Id': 3589,
        'Name': '梅德尔',
        'Icon': '//lain.bgm.tv/pic/crt/g/7b/3a/1_crt_OcGjC.jpg',
        'Level': 4,
        'Current': 50,
        'Total': 17385,
        'Users': 123,
        'State': 0,
        'Change': 0,
        'Fluctuation': 0.5,
        'Asks': 99,
        'Bids': 5403,
        'MarketValue': 4643300,
        'Rate': 5.88,
        'Rank': 4459,
        'StarForces': 27,
        'Stars': 3,
        'Sacrifices': 75510,
      });

      expect(chara.id, 3589);
      expect(chara.monoId, 3589);
      expect(chara.name, '梅德尔');
      expect(chara.level, 4);
      expect(chara.current, 50);
      expect(chara.total, 17385);
      expect(chara.users, 123);
      expect(chara.asks, 99);
      expect(chara.bids, 5403);
      expect(chara.marketValue, 4643300);
      expect(chara.rate, closeTo(5.88, 0.001));
      expect(chara.rank, 4459);
      expect(chara.starForces, 27);
      expect(chara.stars, 3);
      expect(chara.sacrifices, 75510);
    });

    test('treats fluctuation as percentage when small (detail shape)', () {
      final chara = TinygrailChara.fromJson({'Fluctuation': 0.12});
      expect(chara.fluctuation, closeTo(12, 0.001));
    });

    test('keeps fluctuation as-is when already percentage (list shape)', () {
      final chara = TinygrailChara.fromJson({'Fluctuation': 12.5});
      expect(chara.fluctuation, closeTo(12.5, 0.001));
    });

    test('defaults missing fields', () {
      final chara = TinygrailChara.fromJson({});
      expect(chara.id, 0);
      expect(chara.name, '');
      expect(chara.current, 0);
    });
  });

  group('TinygrailUser.fromJson', () {
    test('parses user assets', () {
      final user = TinygrailUser.fromJson({
        'Hash': 'abc123',
        'Nickname': '测试用户',
        'Balance': 10000,
        'Principal': 5000,
        'Amount': 20000,
        'Total': 30000,
        'LastIndex': 42,
      });
      expect(user.hash, 'abc123');
      expect(user.nickname, '测试用户');
      expect(user.balance, 10000);
      expect(user.total, 30000);
      expect(user.lastIndex, 42);
    });
  });

  group('TinygrailDepth.fromJson', () {
    test('parses bids and asks', () {
      final depth = TinygrailDepth.fromJson({
        'Bids': [
          {'Price': 50, 'Amount': 1093},
          {'Price': 23, 'Amount': 2500},
        ],
        'Asks': [
          {'Price': 51, 'Amount': 100},
        ],
      });
      expect(depth.bids.length, 2);
      expect(depth.bids.first.price, 50);
      expect(depth.bids.first.amount, 1093);
      expect(depth.asks.length, 1);
      expect(depth.asks.first.price, 51);
    });
  });

  group('TinygrailKline.fromJson', () {
    test('parses kline item', () {
      final kline = TinygrailKline.fromJson({
        'Time': '2026-08-11T10:00:00',
        'Begin': 40,
        'End': 45,
        'Low': 39,
        'High': 46,
        'Amount': 900,
        'Price': 4050,
      });
      expect(kline.begin, 40);
      expect(kline.end, 45);
      expect(kline.high, 46);
      expect(kline.amount, 900);
      expect(kline.price, 4050);
    });
  });

  group('TinygrailAuctionItem.fromJson', () {
    test('parses auction item with nested status', () {
      final item = TinygrailAuctionItem.fromJson({
        'Id': 1,
        'CharacterId': 3589,
        'Name': '梅德尔',
        'MarketValue': 1000,
        'Amount': 100,
        'Price': 50,
        'State': 0,
        'Auction': {'State': 3, 'Type': 200},
      });
      expect(item.monoId, 3589);
      expect(item.amount, 100);
      expect(item.price, 50);
      expect(item.auctionState, 3);
      expect(item.auctionType, 200);
    });
  });

  group('TinygrailTopWeek.fromJson', () {
    test('parses top week item', () {
      final item = TinygrailTopWeek.fromJson({
        'CharacterId': 111328,
        'CharacterName': '八奈见杏菜',
        'Avatar': '//lain.bgm.tv/pic/crt/g/87/fc/111328_crt_6NmPl.jpg',
        'CharacterLevel': 15,
        'Price': 400,
        'Rate': 44.12,
        'Sacrifices': 100,
        'Extra': 24000800,
        'Type': 1,
      }, rank: 3);
      expect(item.id, 111328);
      expect(item.name, '八奈见杏菜');
      expect(item.level, 15);
      expect(item.price, 400);
      expect(item.rank, 3);
    });
  });

  group('TinygrailSearchItem.fromJson', () {
    test('parses search result', () {
      final item = TinygrailSearchItem.fromJson({
        'Id': 1,
        'Name': '鲁路修·兰佩路基',
        'Level': 4,
        'ICO': false,
      });
      expect(item.id, 1);
      expect(item.name, '鲁路修·兰佩路基');
      expect(item.level, 4);
      expect(item.ico, false);
    });
  });
}
