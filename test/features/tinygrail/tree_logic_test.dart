import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/features/tinygrail/tinygrail_models.dart';
import 'package:bangumi/features/tinygrail/tree_screen.dart';

TinygrailChara _chara({
  int id = 1,
  String name = 'A',
  int state = 100,
  int current = 50,
  double rate = 5,
  int level = 3,
  int sacrifices = 0,
}) =>
    TinygrailChara(
      id: id,
      monoId: id,
      name: name,
      icon: '//lain.bgm.tv/icon/$id.jpg',
      state: state,
      current: current,
      rate: rate,
      level: level,
      sacrifices: sacrifices,
    );

TinygrailTemple _temple({
  int id = 1,
  String name = 'A',
  double rate = 5,
  int level = 3,
  int sacrifices = 200,
}) =>
    TinygrailTemple(
      id: id,
      name: name,
      cover: '//lain.bgm.tv/cover/$id.jpg',
      rate: rate,
      level: level,
      sacrifices: sacrifices,
    );

void main() {
  group('mergeTreeItems', () {
    test('所有: 角色字段优先, 圣殿多余项追加', () {
      final chara = [_chara(id: 1, sacrifices: 100), _chara(id: 2)];
      final temple = [_temple(id: 1, sacrifices: 200), _temple(id: 3, sacrifices: 50)];
      final items = mergeTreeItems(chara, temple, '所有');
      expect(items.length, 3);
      expect(items[0].id, 1);
      expect(items[0].sacrifices, 100); // 角色覆盖圣殿
      expect(items[1].id, 2);
      expect(items[2].id, 3); // 圣殿追加
      expect(items[2].sacrifices, 50);
    });

    test('流动股只含角色, 圣殿股只含圣殿', () {
      final chara = [_chara(id: 1)];
      final temple = [_temple(id: 2)];
      expect(mergeTreeItems(chara, temple, '流动股').length, 1);
      expect(mergeTreeItems(chara, temple, '流动股').first.id, 1);
      expect(mergeTreeItems(chara, temple, '圣殿股').length, 1);
      expect(mergeTreeItems(chara, temple, '圣殿股').first.id, 2);
    });
  });

  group('caculateTreeValue', () {
    test('周股息: 活股 + 献祭加成', () {
      final item = TreeItem.fromChara(_chara(state: 100, rate: 5, level: 3, sacrifices: 200));
      // 100*5 + 200*5*(3+1)*0.3 = 500 + 1200
      expect(caculateTreeValue(item, '周股息'), closeTo(1700, 0.001));
    });

    test('持仓价值: 圣殿按底价 10 折半', () {
      final item = TreeItem.fromTemple(_temple(sacrifices: 200));
      // 200 * 10 * 0.5
      expect(caculateTreeValue(item, '持仓价值', isTemple: true), closeTo(1000, 0.001));
    });
  });

  group('buildTreeNodes', () {
    test('小占比条目聚合为其他', () {
      final items = [
        TreeItem.fromChara(_chara(id: 1, state: 9000)),
        TreeItem.fromChara(_chara(id: 2, state: 100)),
        TreeItem.fromChara(_chara(id: 3, state: 50)),
      ];
      final nodes = buildTreeNodes(items, '持股数');
      // 9000/9150≈98.4% 保留; 100/9150≈1.09% > 0.72% 保留; 50/9150≈0.55% < 0.72% 被聚合
      expect(nodes.length, 3);
      expect(nodes.last.id, 0);
      expect(nodes.last.name, contains('其他'));
      expect(nodes.last.name, contains('1'));
    });

    test('隐藏后过滤比例下降', () {
      final items = [
        TreeItem.fromChara(_chara(id: 1, state: 800)),
        TreeItem.fromChara(_chara(id: 2, state: 100)),
        TreeItem.fromChara(_chara(id: 3, state: 60)),
        TreeItem.fromChara(_chara(id: 4, state: 40)),
      ];
      final nodes = buildTreeNodes(items, '持股数', hiddenIds: {1});
      // 100/200=50% 保留; 60/200=30% 保留; 40/200=20% 保留 (过滤率 0.7%)
      expect(nodes.length, 3);
      expect(nodes.any((n) => n.id == 1), isFalse);
    });
  });
}
