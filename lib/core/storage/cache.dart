import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// 轻量缓存层 (hive_ce)
/// 用法: `Cache.instance.box('subject')` 返回 Box(dynamic)
class Cache {
  Cache._();

  static final Cache instance = Cache._();

  static const _kBoxes = <String>[
    'settings',
    'subject',
    'user',
    'collection',
    'timeline',
    'topic',
    'rakuen',
    'tinygrail',
  ];

  Future<void> init() async {
    await Hive.initFlutter();
    for (final name in _kBoxes) {
      await Hive.openBox<dynamic>(name);
    }
  }

  Box<dynamic> box(String name) => Hive.box<dynamic>(name);

  /// 读取缓存, 带过期时间 (秒)
  dynamic get(String boxName, String key, {Duration? maxAge}) {
    final box = Hive.box<dynamic>(boxName);
    if (!box.containsKey(key)) return null;
    final entry = box.get(key) as Map?;
    if (entry == null) return null;
    if (maxAge != null) {
      final savedAt = entry['_t'] as int? ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - savedAt > maxAge.inMilliseconds) {
        return null;
      }
    }
    return entry['_v'];
  }

  Future<void> put(String boxName, String key, dynamic value) async {
    await Hive.box<dynamic>(boxName).put(key, {
      '_t': DateTime.now().millisecondsSinceEpoch,
      '_v': value,
    });
  }

  Future<void> remove(String boxName, String key) async {
    await Hive.box<dynamic>(boxName).delete(key);
  }

  Future<void> clear(String boxName) async {
    await Hive.box<dynamic>(boxName).clear();
  }
}

final cacheProvider = Provider<Cache>((ref) => Cache.instance);
