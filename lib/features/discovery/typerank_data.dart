import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/storage/packed_json.dart';
import '../subject/subject_models.dart';
import 'typerank_screen.dart';

const kTypeRankPackedTypes = ['anime', 'book', 'music', 'game', 'real'];

String typeRankIdsAsset(String type) =>
    'assets/data/typerank/${typeRankPackedType(type)}-ids.json';

String typeRankRanksAsset(String type) =>
    'assets/data/typerank/${typeRankPackedType(type)}.json';

String typeRankPackedType(String type) =>
    kTypeRankPackedTypes.contains(type) ? type : 'anime';

/// 原版分类排行标题: `分类排行 · {typeCn} · {tag} (N)`
String typeRankTitle(String type, String tag, {int? total}) {
  final base = '分类排行 · ${typeRankTypeCn(type)} · $tag';
  return total == null ? base : '$base ($total)';
}

List<int> typeRankIdsFromMap(Map<String, dynamic> map, String tag) {
  final raw = map[tag];
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is num) e.toInt() else int.tryParse('$e') ?? 0,
  ].where((id) => id > 0).toList();
}

Future<List<int>> loadTypeRankIds(String type, String tag) async {
  if (tag.trim().isEmpty) return const [];
  final map = await PackedJson.loadMap(typeRankIdsAsset(type));
  return typeRankIdsFromMap(map, tag);
}

Future<int> loadTypeRankCount(String type, String tag) async {
  final ids = await loadTypeRankIds(type, tag);
  return ids.length;
}

Future<Map<String, int>> loadTypeRankCounts(String type) async {
  final map = await PackedJson.loadMap(typeRankIdsAsset(type));
  return {
    for (final e in map.entries)
      if (e.value is List) e.key: (e.value as List).length,
  };
}

bool typeRankExistsIn(Map<String, dynamic> ranks, String tag) =>
    ranks[tag] is List && (ranks[tag] as List).isNotEmpty;

/// 原版 tags/utils calc: 优于百分比, 夹在 1-99
int typeRankBetterPercent(List<num> ranks, int value) {
  if (ranks.isEmpty) return 0;
  if (value <= ranks.first.toInt()) return 99;
  var index = 0;
  for (var i = 0; i < ranks.length; i += 1) {
    if (value < ranks[i].toInt()) break;
    index += 1;
  }
  final percent = ((1 - index / ranks.length) * 100).floor();
  if (percent > 99) return 99;
  if (percent < 1) return 1;
  return percent;
}

String typeRankBetterLabel(int? percent) {
  if (percent == null) return '--';
  return '优于$percent%';
}

Future<int?> loadTypeRankBetterPercent(
  String type,
  String tag,
  int rank,
) async {
  if (tag.isEmpty || rank <= 0) return null;
  final map = await PackedJson.loadMap(typeRankRanksAsset(type));
  final raw = map[tag];
  if (raw is! List || raw.isEmpty) return null;
  return typeRankBetterPercent([
    for (final e in raw)
      if (e is num) e,
  ], rank);
}

/// 打包 ID 对应的条目卡片: 走 v0 详情, 6 路并发
Future<List<SubjectListItem>> fetchTypeRankSubjects(
  ApiClient client,
  List<int> ids,
) async {
  if (ids.isEmpty) return const [];
  final out = <SubjectListItem>[];
  for (var i = 0; i < ids.length; i += 6) {
    final chunk = ids.sublist(i, i + 6 > ids.length ? ids.length : i + 6);
    final part = await Future.wait([
      for (final id in chunk) _fetchTypeRankSubject(client, id),
    ]);
    out.addAll(part.whereType<SubjectListItem>());
  }
  return out;
}

Future<SubjectListItem?> _fetchTypeRankSubject(ApiClient client, int id) async {
  try {
    final raw = await client.get(apiV0Subject(id));
    if (raw is! Map) return SubjectListItem(id: id);
    return SubjectListItem.fromJson(Map<String, dynamic>.from(raw));
  } catch (_) {
    return SubjectListItem(id: id);
  }
}
