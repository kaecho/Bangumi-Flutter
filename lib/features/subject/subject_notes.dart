import '../webview/note_screen.dart';
import 'subject_models.dart';

String ratingDeviationNotePath() {
  return extraNotePath(
    title: '标准差',
    message: const [
      '0-1 异口同声',
      '1.15 基本一致',
      '1.3 略有分歧',
      '1.45 莫衷一是',
      '1.6 各执一词',
      '1.75 你死我活',
    ],
  );
}

/// Extra HeaderV2: `{name}的…` when a name is known, else alias.
String extraNamedTitle(
  String? name,
  String fallback, {
  String Function(String name)? named,
  int? count,
}) {
  final n = name?.trim() ?? '';
  var title = n.isEmpty ? fallback : (named ?? (v) => v)(n);
  if (count != null && count > 0) title = '$title ($count)';
  return title;
}

/// 原版本集讨论: `ep{sort}.{name || name_cn}`
String epCommentsTitle({int? sort, String? name}) {
  final n = name?.trim() ?? '';
  if (sort == null || sort <= 0) return n.isEmpty ? '章节吐槽' : n;
  return n.isEmpty ? 'ep$sort' : 'ep$sort.$n';
}

/// 原版 Voices Header: `{name}的角色 (N)` / 角色; 快照 24 条不显示计数
String voicesTitle(String? name, int? count) => extraNamedTitle(
  name,
  '角色',
  named: (n) => '$n的角色',
  count: count == null || count == 0 || count == kVoicesSnapshotLimit
      ? null
      : count,
);

/// 原版作品 HeaderV2Popover: 浏览器查看 + toolBar
List<(String, String)> worksMoreItems({
  required bool fixed,
  required bool list,
  required bool collected,
}) => [
  ('browser', '浏览器查看'),
  ('toolbar', '工具栏〔${fixed ? '锁定' : '浮动'}〕'),
  ('layout', '布　局〔${list ? '列表' : '网格'}〕'),
  ('favor', '收　藏〔${collected ? '显示' : '不显示'}〕'),
];

/// 原版 Persons Extra Filter: 全部职位 + 职位计数, 动画制作排最前
const kPersonsLabelAll = '全部职位';

const kPersonsSortPositions = <String>[
  '原作',
  '导演',
  '系列构成',
  '脚本',
  '动画制作',
  '动画制片人',
  '制片人',
  '分镜',
  '演出',
  '人物设定',
  '设定',
  '美术监督',
  '色彩设计',
  '总作画监督',
  '作画监督',
  '原画',
  '第二原画',
  '动画检查',
  '补间动画',
  '色彩指定',
  '摄影监督',
  '摄影',
  'CG 导演',
  '特效',
  '剪辑',
  '音乐',
  '音响监督',
  '音效',
  '主题歌作曲',
  '主题歌作词',
  '主题歌编曲',
  '主题歌演出',
  '企画',
  '制作管理',
  '制作',
  '製作',
];

List<({String title, int value})> personsFilters(List<PersonVo> list) {
  final map = <String, int>{};
  for (final item in list) {
    for (final job in item.jobs) {
      map[job] = (map[job] ?? 0) + 1;
    }
  }
  final entries = map.entries.toList()
    ..sort((a, b) {
      var indexA = kPersonsSortPositions.indexOf(a.key);
      var indexB = kPersonsSortPositions.indexOf(b.key);
      if (indexA < 0) indexA = 9999;
      if (indexB < 0) indexB = 9999;
      return indexA.compareTo(indexB);
    });
  return [
    (title: kPersonsLabelAll, value: list.length),
    for (final e in entries) (title: e.key, value: e.value),
  ];
}

String personsFilterValue(String title, int value) => '$title ($value)';

String personsFilterTitle(String selected) {
  final cut = selected.split(' (').first;
  return cut.isEmpty ? kPersonsLabelAll : cut;
}

List<PersonVo> filterPersons(List<PersonVo> list, String selected) {
  final title = personsFilterTitle(selected);
  final filtered = title == kPersonsLabelAll
      ? list
      : [
          for (final item in list)
            if (item.jobs.contains(title)) item,
        ];
  return [
    ...filtered.where((e) => e.jobs.contains('动画制作')),
    ...filtered.where((e) => !e.jobs.contains('动画制作')),
  ];
}

/// 原版概览 Extra Filter: 全部 (N) + Disc 计数
String overviewDiscLabel(int disc) => disc > 0 ? 'Disc $disc' : '本篇';

List<({String title, int value})> overviewDiscFilters(Iterable<int> discs) {
  final list = discs.toList();
  final map = <int, int>{};
  for (final disc in list) {
    map[disc] = (map[disc] ?? 0) + 1;
  }
  final keys = map.keys.toList()..sort();
  return [
    (title: '全部', value: list.length),
    for (final key in keys) (title: overviewDiscLabel(key), value: map[key]!),
  ];
}

String overviewFilterValue(String title, int value) => '$title ($value)';

int? overviewDiscFromFilter(String selected) {
  final title = selected.split(' (').first;
  if (title == '全部' || title.isEmpty) return null;
  if (title == '本篇') return 0;
  return int.tryParse(title.replaceFirst('Disc ', ''));
}
