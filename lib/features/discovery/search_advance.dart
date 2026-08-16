import '../../core/storage/packed_json.dart';
import '../../core/utils/display.dart';

const kSearchAdvanceMax = 10;

const kSearchAdvanceSubjectAssets = {
  'subject_1': ['assets/data/substrings/book.json'],
  'subject_4': ['assets/data/substrings/game.json'],
  'subject_6': ['assets/data/substrings/real.json'],
};

const kSearchAdvanceAnimeAssets = [
  'assets/data/substrings/anime.json',
  'assets/data/substrings/alias.json',
];

const kSearchAdvanceMonoAsset = 'assets/data/mono.json';

/// 原版 advance/hooks normalizeSearch
String normalizeSearch(String value) =>
    t2s(value).toUpperCase().replaceAll(RegExp(r'\s+'), '');

bool isSearchAdvanceId(String value) => RegExp(r'^\d+$').hasMatch(value.trim());

class SearchAdvanceHit {
  final String title;
  final int id;

  const SearchAdvanceHit({required this.title, required this.id});
}

class SearchAdvanceMonoHit {
  final int id;
  final String name;
  final String cover;
  final int replies;
  final bool person;

  const SearchAdvanceMonoHit({
    required this.id,
    required this.name,
    this.cover = '',
    this.replies = 0,
    this.person = false,
  });

  String get path => person ? '/mono/person/$id' : '/mono/character/$id';
}

List<String> searchAdvanceAssetsFor(String cat) =>
    kSearchAdvanceSubjectAssets[cat] ?? kSearchAdvanceAnimeAssets;

Future<Map<String, int>> loadSearchAdvanceMap(String cat) async {
  final merged = <String, int>{};
  for (final asset in searchAdvanceAssetsFor(cat)) {
    final raw = await PackedJson.loadMap(asset);
    raw.forEach((title, value) {
      final id = (value as num?)?.toInt() ?? 0;
      if (id > 0) merged[title] = id;
    });
  }
  return merged;
}

/// 原版 useResult: 条目联想, 关键字至少 2 字, 最多 10 条
List<SearchAdvanceHit> matchSearchAdvance(Map<String, int> map, String value) {
  final q = normalizeSearch(value);
  if (q.length < 2) return const [];
  final hits = <SearchAdvanceHit>[];
  for (final entry in map.entries) {
    if (hits.length >= kSearchAdvanceMax) break;
    if (normalizeSearch(entry.key).contains(q)) {
      hits.add(SearchAdvanceHit(title: entry.key, id: entry.value));
    }
  }
  hits.sort((a, b) => b.id.compareTo(a.id));
  return hits;
}

Future<List<SearchAdvanceHit>> searchAdvanceSubjects(
  String cat,
  String value,
) async {
  if (cat == 'mono_all' || cat == 'user' || cat == 'catalog') {
    return const [];
  }
  final map = await loadSearchAdvanceMap(cat);
  return matchSearchAdvance(map, value);
}

SearchAdvanceMonoHit? parseSearchAdvanceMono(Map<String, dynamic> json) {
  final id = (json['i'] as num?)?.toInt() ?? 0;
  if (id <= 0) return null;
  final coverKey = json['c'] as String? ?? '';
  return SearchAdvanceMonoHit(
    id: id,
    name: json['n'] as String? ?? '',
    cover: coverKey.isEmpty
        ? ''
        : 'https://lain.bgm.tv/pic/crt/g/$coverKey.jpg',
    replies: (json['r'] as num?)?.toInt() ?? 0,
    person: json['p'] == 1 || json['p'] == true,
  );
}

/// 原版 useMonoResult: 人物联想, 关键字至少 1 字
List<SearchAdvanceMonoHit> matchSearchAdvanceMono(
  List<SearchAdvanceMonoHit> all,
  String value,
) {
  final q = normalizeSearch(value);
  if (q.isEmpty) return const [];
  final hits = <SearchAdvanceMonoHit>[];
  for (final item in all) {
    if (hits.length >= kSearchAdvanceMax) break;
    if (normalizeSearch(item.name).contains(q)) hits.add(item);
  }
  return hits;
}

Future<List<SearchAdvanceMonoHit>> searchAdvanceMono(String value) async {
  final raw = await PackedJson.loadList(kSearchAdvanceMonoAsset);
  final all = [
    for (final e in raw)
      if (e is Map) ?parseSearchAdvanceMono(Map<String, dynamic>.from(e)),
  ];
  return matchSearchAdvanceMono(all, value);
}
