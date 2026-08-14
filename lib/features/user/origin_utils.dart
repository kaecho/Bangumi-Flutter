import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'origin_setting_screen.dart';

/// 原项目内置源头 (只取默认 active=1, 不含需云端 OTA 的备用域名)
const kDefaultOrigins = <String, List<OriginItem>>{
  'anime': [
    OriginItem(
      uuid: 'anime|age',
      name: 'AGE动漫',
      url: 'https://www.agedm.io/search?query=[CN]&page=1',
    ),
    OriginItem(
      uuid: 'anime|bilibili',
      name: '哔哩哔哩',
      url: 'bilibili://search?keyword=[CN_DECODE]',
    ),
    OriginItem(
      uuid: 'anime|cycanime',
      name: '次元城动画',
      url: 'https://www.cycani.org/search.html?wd=[CN]',
    ),
    OriginItem(
      uuid: 'anime|libvio',
      name: 'LIBVIO',
      url: 'https://www.libvio.pw/search/-------------.html?wd=[CN]',
    ),
  ],
  'hanime': [
    OriginItem(
      uuid: 'hanime|hanime1',
      name: 'Hanime1',
      url: 'https://hanime1.me/search?query=[JP]',
    ),
  ],
  'manga': [
    OriginItem(
      uuid: 'manga|mangacopy',
      name: '拷贝漫画',
      url: 'https://www.mangacopy.com/search?q=[CN]&q_type=',
    ),
    OriginItem(
      uuid: 'manga|komiic',
      name: 'Komiic漫画',
      url: 'https://komiic.com/search/[CN]',
    ),
    OriginItem(
      uuid: 'manga|hisoman',
      name: '搜漫',
      url: 'https://www.hisoman.com/search.html?keyword=[CN]',
    ),
    OriginItem(
      uuid: 'manga|moxmoe',
      name: '[DL] Kox.moe',
      url: 'https://kox.moe/list.php?s=[CN]',
    ),
  ],
  'wenku': [
    OriginItem(
      uuid: 'wenku|wk8',
      name: '轻小说文库',
      url:
          'https://www.wenku8.net/modules/article/search.php?searchtype=articlename&searchkey=[CN]',
    ),
    OriginItem(
      uuid: 'wenku|linovelib',
      name: '哔哩轻小说',
      url: 'https://www.bilinovel.com/search.html?searchkey=[JP]',
    ),
    OriginItem(
      uuid: 'wenku|cijoc',
      name: 'CIJOC',
      url: 'https://cijoc.com/search/?s=[JP]',
    ),
    OriginItem(
      uuid: 'wenku|legado',
      name: 'Legado阅读',
      url: 'legado://search?keyword=[CN_DECODE]',
    ),
  ],
  'music': [
    OriginItem(
      uuid: 'music|163',
      name: '网易云',
      url:
          'https://www.baidu.com/s?word=site%3Amusic.163.com+%E4%B8%93%E8%BE%91+[JP]',
    ),
    OriginItem(
      uuid: 'music|qq',
      name: 'QQ音乐',
      url:
          'https://www.baidu.com/s?word=site%3Ay.qq.com+%E4%B8%93%E8%BE%91+[JP]',
    ),
  ],
  'game': [
    OriginItem(
      uuid: 'game|psnine',
      name: 'PSNINE',
      url: 'https://psnine.com/psngame?title=[CN]',
    ),
    OriginItem(
      uuid: 'game|vndb',
      name: '[GAL] vndb.org',
      url: 'https://vndb.org/v?sq=[JP]',
    ),
    OriginItem(
      uuid: 'game|sakustar',
      name: '[GAL] 稻荷ACG',
      url: 'https://sakustar.top/?s=[JP]&type=post',
    ),
    OriginItem(
      uuid: 'game|xxacg',
      name: '[GAL] xxacg',
      url: 'https://xxacg.net/?s=[JP]',
    ),
  ],
  'real': [
    OriginItem(
      uuid: 'real|libvio',
      name: 'LIBVIO',
      url: 'https://www.libvio.me/search/-------------.html?wd=[CN]',
    ),
  ],
};

/// 替换源头地址参数 (移植自 origin-setting/utils.replaceOriginUrl)
String replaceOriginUrl(
  String url, {
  required String cn,
  required String jp,
  required int id,
  String year = '',
}) {
  final replacements = <String, String>{
    'CN': cn,
    'JP': jp,
    'ID': '$id',
    'YEAR': year,
    'CN_DECODE': cn,
    'JP_DECODE': jp,
    'CN_S2T': cn,
    'TIME': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
  };
  return url.replaceAllMapped(RegExp(r'\[([A-Z_]+)\]'), (m) {
    final key = m.group(1) ?? '';
    final val = replacements[key] ?? '';
    return key.endsWith('_DECODE') ? val : Uri.encodeComponent(val);
  });
}

/// 条目类型 → 源头分类; 书籍同时给漫画 + 文库
List<OriginItem> originsForType(
  Map<String, List<OriginItem>> config,
  String subjectType,
) {
  if (subjectType == 'book') {
    return [
      ...?config['manga'],
      ...?config['wenku'],
    ].where((e) => e.active).toList();
  }
  final key = switch (subjectType) {
    'real' => 'real',
    'game' => 'game',
    'music' => 'music',
    _ => 'anime',
  };
  return [...?config[key]].where((e) => e.active).toList();
}

Future<Map<String, List<OriginItem>>> loadMergedOrigins() async {
  final custom = await OriginStore().load();
  return {
    for (final key in {...kDefaultOrigins.keys, ...custom.keys})
      key: [...?kDefaultOrigins[key], ...?custom[key]],
  };
}

final originConfigProvider = FutureProvider<Map<String, List<OriginItem>>>((
  ref,
) {
  return loadMergedOrigins();
});
