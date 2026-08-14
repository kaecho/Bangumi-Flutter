import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/features/tinygrail/treemap.dart';

void main() {
  group('squarify', () {
    test('面积守恒: 所有矩形面积之和等于画布面积', () {
      const width = 400.0, height = 300.0;
      final rects = squarify([1, 2, 3, 4, 5, 6, 7, 8], width, height);
      var total = 0.0;
      for (final r in rects) {
        expect(r, isNotNull);
        total += r!.w * r.h;
      }
      expect(total, closeTo(width * height, 0.5));
    });

    test('矩形不越界且互不重叠', () {
      final rects = squarify([3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5], 500, 400);
      final placed = <TreemapRect>[];
      for (final r in rects) {
        expect(r, isNotNull);
        expect(r!.x, greaterThanOrEqualTo(0));
        expect(r.y, greaterThanOrEqualTo(0));
        expect(r.x + r.w, lessThanOrEqualTo(500.5));
        expect(r.y + r.h, lessThanOrEqualTo(400.5));
        for (final p in placed) {
          final overlapX = r.x < p.x + p.w && p.x < r.x + r.w;
          final overlapY = r.y < p.y + p.h && p.y < r.y + r.h;
          expect(overlapX && overlapY, isFalse,
              reason: 'rect ($r) overlaps ($p)');
        }
        placed.add(r);
      }
    });

    test('权重越大面积越大', () {
      final rects = squarify([10, 1], 300, 200);
      final area0 = rects[0]!.w * rects[0]!.h;
      final area1 = rects[1]!.w * rects[1]!.h;
      expect(area0, greaterThan(area1 * 5));
    });

    test('权重全零返回空矩形列表', () {
      final rects = squarify([0, 0, 0], 100, 100);
      expect(rects, everyElement(isNull));
    });

    test('空列表返回空', () {
      expect(squarify(const [], 100, 100), isEmpty);
    });
  });
}
