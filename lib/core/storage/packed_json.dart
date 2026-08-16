import 'dart:convert';

import 'package:flutter/services.dart';

/// 原版 `src/assets/json` 打包数据 (标签联想 / 分类排行 / 人物联想)
class PackedJson {
  static final Map<String, Object> _cache = {};

  static Future<Map<String, dynamic>> loadMap(String asset) async {
    final cached = _cache[asset];
    if (cached is Map<String, dynamic>) return cached;
    final decoded = jsonDecode(await rootBundle.loadString(asset));
    final map = Map<String, dynamic>.from(decoded as Map);
    _cache[asset] = map;
    return map;
  }

  static Future<List<dynamic>> loadList(String asset) async {
    final cached = _cache[asset];
    if (cached is List<dynamic>) return cached;
    final decoded = jsonDecode(await rootBundle.loadString(asset));
    final list = List<dynamic>.from(decoded as List);
    _cache[asset] = list;
    return list;
  }
}

/// 测试注入
void seedPackedJson(String asset, Object data) {
  PackedJson._cache[asset] = data;
}

void clearPackedJson() {
  PackedJson._cache.clear();
}
