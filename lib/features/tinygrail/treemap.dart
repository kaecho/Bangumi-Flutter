/// 矩形树图 (squarified treemap) — 移植自原项目 utils/thirdParty/treemap.ts
///
/// (https://github.com/nicopolyptic/treemap, Bruls et al. 经典算法)
/// 单层节点布局: 按权重降序, 逐行放置, 每行取最坏长宽比最小者。
library;

class TreemapRect {
  final double x;
  final double y;
  final double w;
  final double h;

  const TreemapRect(this.x, this.y, this.w, this.h);
}

/// 按权重为 [weights] (与 [data] 一一对应) 在 (0,0,width,height) 内布局,
/// 返回每个条目对应的矩形。权重非正或总权重为 0 的条目返回空矩形。
List<TreemapRect?> squarify(List<double> weights, double width, double height) {
  final n = weights.length;
  if (n == 0 || width <= 0 || height <= 0) return List.filled(n, null);

  final total = weights.fold<double>(0, (a, b) => a + b);
  if (total <= 0) return List.filled(n, null);

  // 缩放权重为面积 (总面积 = width * height)
  final scale = width * height / total;
  final order = List<int>.generate(n, (i) => i)
    ..sort((a, b) => weights[b].compareTo(weights[a]));
  final rects = List<TreemapRect?>.filled(n, null);

  double worst(double s, double min, double max, double w) =>
      (w * w * max) / (s * s) > (s * s) / (w * w * min)
      ? (w * w * max) / (s * s)
      : (s * s) / (w * w * min);

  var vertical = height < width;
  var w = vertical ? height : width;
  var x = 0.0, y = 0.0;
  var rw = width, rh = height;
  final row = <int>[]; // 当前行 (order 下标)

  for (var k = 0; k <= n; k++) {
    // 哨兵 (权重 0) 用于强制 flush 最后一行
    final r = k < n ? weights[order[k]] * scale : 0.0;
    var s = 0.0, min = double.infinity, max = 0.0;
    for (final i in row) {
      final wi = weights[order[i]] * scale;
      s += wi;
      if (wi < min) min = wi;
      if (wi > max) max = wi;
    }
    final wit = row.isEmpty
        ? double.infinity
        : worst(s + r, min < r ? min : r, max > r ? max : r, w);
    final without = row.isEmpty ? double.infinity : worst(s, min, max, w);

    if (row.isEmpty || wit < without) {
      if (k < n) row.add(k);
      continue;
    }

    // flush 当前行
    final z = s / w;
    var rx = x, ry = y;
    for (final i in row) {
      final d = (weights[order[i]] * scale) / z;
      rects[order[i]] = vertical
          ? TreemapRect(rx, ry, z, d)
          : TreemapRect(rx, ry, d, z);
      if (vertical) {
        ry += d;
      } else {
        rx += d;
      }
    }
    if (vertical) {
      x += z;
      rw -= z;
    } else {
      y += z;
      rh -= z;
    }
    vertical = rh < rw;
    w = vertical ? rh : rw;
    row.clear();

    // 哨兵后结束
    if (k == n) break;
    k--; // 当前元素重新进入判断
  }
  return rects;
}
