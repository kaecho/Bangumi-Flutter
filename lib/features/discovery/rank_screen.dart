import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../subject/collection_sheet.dart';
import 'widgets/discovery_html.dart';
import 'widgets/paged.dart';
import '../../shared/widgets/bgm_button.dart';

// ---------------------------------------------------------------------------
// 常量 (移植自原项目 src/constants/{model,data}/index.ts 的 RANK 相关列表)
// ---------------------------------------------------------------------------

/// 条目类型 (原项目含 全部)
const kRankTypes = <(String label, String title)>[
  ('all', '全部'),
  ('anime', '动画'),
  ('book', '书籍'),
  ('game', '游戏'),
  ('music', '音乐'),
  ('real', '三次元'),
];

/// 排序 (TAG_ORDERBY)
const kRankSorts = <(String value, String label)>[
  ('rank', '排名'),
  ('trends', '热度'),
  ('collects', '收藏'),
  ('date', '日期'),
  ('title', '名称'),
];

/// 一级分类 (DATA_FILTER): typeCn → (label, value) 列表, 首项为 全部/空
const kRankFilter = <String, List<(String, String)>>{
  '动画': [
    ('全部', ''),
    ('TV', 'tv'),
    ('WEB', 'web'),
    ('OVA', 'ova'),
    ('剧场版', 'movie'),
    ('动态漫画', 'anime_comic'),
    ('其他', 'misc'),
  ],
  '书籍': [
    ('全部', ''),
    ('漫画', 'comic'),
    ('小说', 'novel'),
    ('绘本', 'picture'),
    ('公式书', 'official'),
    ('写真', 'photo'),
    ('其他', 'misc'),
  ],
  '游戏': [
    ('全部', ''),
    ('游戏', 'games'),
    ('扩展包', 'dlc'),
    ('软件', 'software'),
    ('桌游', 'tabletop'),
  ],
  '三次元': [
    ('全部', ''),
    ('日剧', 'jp'),
    ('欧美剧', 'en'),
    ('华语剧', 'cn'),
    ('电视剧', 'tv'),
    ('电影', 'movie'),
    ('演出', 'live'),
    ('综艺', 'show'),
    ('其他', 'misc'),
  ],
};

/// 二级分类 (DATA_FILTER_SUB): typeCn → (label, value), 仅 书籍/游戏
const kRankFilterSub = <String, List<(String, String)>>{
  '书籍': [('全部', ''), ('系列', 'series'), ('单行本', 'offprint')],
  '游戏': [
    ('全部', ''),
    ('PC', 'PC'),
    ('Web', 'Web'),
    ('Mac', 'Mac'),
    ('Linux', 'Linux'),
    ('PS5', 'PS5'),
    ('Xbox Series X/S', 'XSX'),
    ('Nintendo Switch', 'NS'),
    ('iOS', 'iOS'),
    ('Android', 'Android'),
    ('VR', 'VR'),
    ('PSVR2', 'PSVR2'),
    ('街机', '街机'),
    ('Xbox One', 'XboxOne'),
    ('Xbox', 'Xbox'),
    ('Xbox 360', 'Xbox360'),
    ('GBA', 'GBA'),
    ('Wii', 'Wii'),
    ('NDS', 'NDS'),
    ('FC', 'FC'),
    ('3DS', '3DS'),
    ('GBC', 'GBC'),
    ('GB', 'GB'),
    ('N64', 'N64'),
    ('NGC', 'NGC'),
    ('SFC', 'SFC'),
    ('Wii U', 'WiiU'),
    ('PS4', 'PS4'),
    ('PSVR', 'PSVR'),
    ('PS Vita', 'PSV'),
    ('PS3', 'PS3'),
    ('PSP', 'PSP'),
    ('PS2', 'PS2'),
    ('PS', 'PS'),
    ('Dreamcast', 'DC'),
    ('Sega Saturn', 'SS'),
    ('MD', 'MD'),
    ('Apple II', 'AppleII'),
    ('DOS', 'DOS'),
    ('Symbian', 'Symbian'),
  ],
};

/// 二级分类显示名
const kRankFilterSubText = <String, String>{'书籍': '系列', '游戏': '平台'};

/// 来源 (DATA_SOURCE): 仅 动画
const kRankSource = <String>['全部', '原创', '漫画改', '游戏改', '小说改'];

/// 公共标签 (DATA_TAG): 动画 + 游戏
const kRankTag = <String, List<String>>{
  '动画': [
    '全部',
    '科幻',
    '喜剧',
    '百合',
    '校园',
    '惊悚',
    '后宫',
    '机战',
    '悬疑',
    '恋爱',
    '奇幻',
    '推理',
    '运动',
    '耽美',
    '音乐',
    '战斗',
    '冒险',
    '萌系',
    '穿越',
    '玄幻',
    '乙女',
    '恐怖',
    '历史',
    '日常',
    '剧情',
    '武侠',
    '美食',
    '职场',
  ],
  '游戏': [
    '全部',
    'AAVG',
    'ACT',
    'ADV',
    'ARPG',
    'AVG',
    'CRPG',
    'DBG',
    'DRPG',
    'EDU',
    'FPS',
    'FTG',
    'Fly',
    'Horror',
    'JRPG',
    'MMORPG',
    'MOBA',
    'MUG',
    'PUZ',
    'Platform',
    'RAC',
    'RPG',
    'RTS',
    'RTT',
    'Roguelike',
    'SIM',
    'SLG',
    'SPG',
    'SRPG',
    'STG',
    'Sandbox',
    'Survival',
    'TAB',
    'TPS',
    'VN',
    '休闲',
    '卡牌对战',
  ],
};

/// 地区 (DATA_AREA): 动画 + 三次元
const kRankArea = <String, List<String>>{
  '动画': [
    '全部',
    '欧美',
    '日本',
    '美国',
    '中国',
    '法国',
    '韩国',
    '俄罗斯',
    '英国',
    '苏联',
    '中国香港',
    '捷克',
    '中国台湾',
  ],
  '三次元': [
    '全部',
    '日本',
    '欧美',
    '美国',
    '中国',
    '华语',
    '英国',
    '韩国',
    '中国香港',
    '中国台湾',
    '法国',
    '俄罗斯',
    '意大利',
    '加拿大',
    '新西兰',
    '泰国',
  ],
};

/// 受众 (DATA_TARGET): 动画 + 游戏
const kRankTarget = <String, List<String>>{
  '动画': ['全部', 'BL', 'GL', '子供向', '女性向', '少女向', '少年向', '青年向'],
  '游戏': ['全部', 'Galgame', 'BL', '乙女'],
};

/// 题材 (DATA_THEME): 仅 三次元
const kRankTheme = <String>[
  '全部',
  '犯罪',
  '悬疑',
  '推理',
  '喜剧',
  '爱情',
  '特摄',
  '科幻',
  '音乐',
  '校园',
  '美食',
  '奇幻',
  '动作',
  '家庭',
  '战争',
  '玄幻',
  '西部',
  '歌舞',
  '历史',
  '传记',
  '剧情',
  '纪录片',
  '恐怖',
  '惊悚',
  '职场',
  '武侠',
  '古装',
  '布袋戏',
  '灾难',
  '冒险',
  '少儿',
  '运动',
  '同性',
];

/// 分级 (DATA_CLASSIFICATION): 仅 游戏
const kRankClassification = <String>['全部', '全年龄', 'R18'];

/// 年 (DATA_AIRTIME): ['全部', 当前年..1980]
List<String> get kRankYears => [
  '全部',
  for (var y = DateTime.now().year; y >= 1980; y--) y.toString(),
];

/// 月 (DATA_MONTH): ['全部', '1'..'12']
const kRankMonths = [
  '全部',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  '11',
  '12',
];

// ---------------------------------------------------------------------------
// 状态 / 查询
// ---------------------------------------------------------------------------

/// 原版排行榜 HeaderV2Popover: 浏览器查看 + 网页版查看 + toolBar
List<(String, String)> rankMoreItems({
  required bool fixed,
  required bool pagination,
  required bool list,
  required bool collected,
  required bool fixedPagination,
}) => [
  ('browser', '浏览器查看'),
  ('spa', '网页版查看'),
  ('toolbar', '工具栏〔${fixed ? '锁定' : '浮动'}〕'),
  ('loaded', '加　载〔${pagination ? '分页加载' : '到底加载'}〕'),
  ('layout', '布　局〔${list ? '列表' : '网格'}〕'),
  ('favor', '收　藏〔${collected ? '显示' : '不显示'}〕'),
  if (pagination) ('pager', '分页器〔${fixedPagination ? '锁定' : '浮动'}〕'),
];

/// 排行榜工具栏状态 (对照 rank/store/ds.ts STATE; '全部' 统一映射为 '')
class RankState {
  final String type; // label: anime|book|game|music|real
  final String sort; // rank|trends|collects|date|title
  final String airtime; // 年 '全部' | '2026'
  final String month; // '全部' | '1'..'12'
  final String filter; // 一级分类 value ('' = 全部)
  final String filterSub; // 二级分类 value ('' = 全部)
  final String source; // '全部' | 原创/漫画改...
  final String tag;
  final String area;
  final String target;
  final String classification;
  final String theme;
  final bool expand;
  final bool list; // 列表布局?
  final bool pagination; // 分页模式?
  final bool collected; // 显示收藏?
  final bool fixed; // 工具栏锁定?
  final bool fixedPagination; // 分页器锁定?

  const RankState({
    this.type = 'anime',
    this.sort = 'rank',
    this.airtime = '全部',
    this.month = '全部',
    this.filter = '',
    this.filterSub = '',
    this.source = '全部',
    this.tag = '全部',
    this.area = '全部',
    this.target = '全部',
    this.classification = '全部',
    this.theme = '全部',
    this.expand = false,
    this.list = true,
    this.pagination = true,
    this.collected = true,
    this.fixed = true,
    this.fixedPagination = true,
  });

  String get typeCn =>
      const {
        'all': '全部',
        'anime': '动画',
        'book': '书籍',
        'game': '游戏',
        'music': '音乐',
        'real': '三次元',
      }[type] ??
      '动画';

  String get airtimeValue => airtime == '全部' ? '' : airtime;
  String get monthValue => month == '全部' ? '' : month;
  String get sourceValue => source == '全部' ? '' : source;
  String get tagValue => tag == '全部' ? '' : tag;
  String get areaValue => area == '全部' ? '' : area;
  String get targetValue => target == '全部' ? '' : target;
  String get classificationValue =>
      classification == '全部' ? '' : classification;
  String get themeValue => theme == '全部' ? '' : theme;

  /// airtime 段: month 存在时 `${year}-${month}`
  String get airtimeSegment =>
      monthValue.isEmpty ? airtimeValue : '$airtimeValue-$monthValue';

  bool get hasActiveSubFilter =>
      filter.isNotEmpty ||
      filterSub.isNotEmpty ||
      tag != '全部' ||
      source != '全部' ||
      area != '全部' ||
      target != '全部' ||
      classification != '全部' ||
      theme != '全部';

  RankState copyWith({
    String? type,
    String? sort,
    String? airtime,
    String? month,
    String? filter,
    String? filterSub,
    String? source,
    String? tag,
    String? area,
    String? target,
    String? classification,
    String? theme,
    bool? expand,
    bool? list,
    bool? pagination,
    bool? collected,
    bool? fixed,
    bool? fixedPagination,
  }) => RankState(
    type: type ?? this.type,
    sort: sort ?? this.sort,
    airtime: airtime ?? this.airtime,
    month: month ?? this.month,
    filter: filter ?? this.filter,
    filterSub: filterSub ?? this.filterSub,
    source: source ?? this.source,
    tag: tag ?? this.tag,
    area: area ?? this.area,
    target: target ?? this.target,
    classification: classification ?? this.classification,
    theme: theme ?? this.theme,
    expand: expand ?? this.expand,
    list: list ?? this.list,
    pagination: pagination ?? this.pagination,
    collected: collected ?? this.collected,
    fixed: fixed ?? this.fixed,
    fixedPagination: fixedPagination ?? this.fixedPagination,
  );
}

/// 排行榜查询参数 (family key; 切换任意筛选条件会触发重新拉取)
class RankQuery {
  final String type;
  final String filter;
  final String filterSub;
  final String source;
  final String theme;
  final String tag;
  final String area;
  final String target;
  final String classification;
  final String airtime; // 已合并 year-month
  final String order;
  final bool collected; // 显示收藏? (false 时客户端过滤已收藏)

  const RankQuery({
    required this.type,
    required this.filter,
    required this.filterSub,
    required this.source,
    required this.theme,
    required this.tag,
    required this.area,
    required this.target,
    required this.classification,
    required this.airtime,
    required this.order,
    required this.collected,
  });

  factory RankQuery.fromState(RankState s) => RankQuery(
    type: s.type,
    filter: s.filter,
    filterSub: s.filterSub,
    source: s.sourceValue,
    theme: s.themeValue,
    tag: s.tagValue,
    area: s.areaValue,
    target: s.targetValue,
    classification: s.classificationValue,
    airtime: s.airtimeSegment,
    order: s.sort,
    collected: s.collected,
  );

  @override
  bool operator ==(Object other) =>
      other is RankQuery &&
      other.type == type &&
      other.filter == filter &&
      other.filterSub == filterSub &&
      other.source == source &&
      other.theme == theme &&
      other.tag == tag &&
      other.area == area &&
      other.target == target &&
      other.classification == classification &&
      other.airtime == airtime &&
      other.order == order &&
      other.collected == collected;

  @override
  int get hashCode => Object.hash(
    type,
    filter,
    filterSub,
    source,
    theme,
    tag,
    area,
    target,
    classification,
    airtime,
    order,
    collected,
  );
}

// ---------------------------------------------------------------------------
// 数据源
// ---------------------------------------------------------------------------

class RankResults extends PagedNotifier<RankSubject, RankQuery> {
  @override
  Future<PagedData<RankSubject>> build(RankQuery arg) {
    ref.watch(settingsStoreProvider.select((s) => s.filter18x));
    return super.build(arg);
  }

  @override
  Future<List<RankSubject>> fetchPage(RankQuery q, int page) async {
    final client = ref.read(apiClientProvider);
    Future<List<RankSubject>> load(String type) async {
      final path = htmlRankBrowserV2(
        type: type,
        filter: q.filter,
        filterSub: q.filterSub,
        source: q.source,
        theme: q.theme,
        tag: q.tag,
        area: q.area,
        target: q.target,
        classification: q.classification,
        airtime: q.airtime,
        order: q.order,
        page: page,
      );
      final html = await client.fetchHtml('$kHost$path');
      return parseRankList(html);
    }

    final types = q.type == 'all'
        ? const ['anime', 'book', 'music', 'game', 'real']
        : [q.type];
    final chunks = await Future.wait(types.map(load));
    final list = [for (final chunk in chunks) ...chunk];
    final visible = SettingsStore.instance.filter18x
        ? [
            for (final e in list)
              if (!isSensitiveSubject(
                name: e.name,
                nameCn: e.nameCn,
                extra: e.tip,
              ))
                e,
          ]
        : list;
    if (!q.collected) return visible.where((e) => !e.collected).toList();
    return visible;
  }
}

final rankResultsProvider =
    AsyncNotifierProvider.family<
      RankResults,
      PagedData<RankSubject>,
      RankQuery
    >(RankResults.new);

// ---------------------------------------------------------------------------
// 界面
// ---------------------------------------------------------------------------

/// 排行榜
class RankScreen extends ConsumerStatefulWidget {
  const RankScreen({super.key});

  @override
  ConsumerState<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends ConsumerState<RankScreen> {
  RankState _s = const RankState();

  void _setState(RankState Function(RankState) fn) =>
      setState(() => _s = fn(_s));

  @override
  Widget build(BuildContext context) {
    final query = RankQuery.fromState(_s);
    final toolBar = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PrimaryBar(state: _s, onSelect: _setState),
        if (_s.typeCn != '音乐' && _s.typeCn != '全部' && _s.expand)
          _ExpandedBar(state: _s, onSelect: _setState),
      ],
    );
    final pager = _s.pagination ? _RankPagination(query: query) : null;
    final list = _s.list
        ? PagedListView<RankSubject, RankQuery>(
            provider: rankResultsProvider,
            arg: query,
            emptyText: '暂无数据',
            autoLoadMore: !_s.pagination,
            header: _s.fixed ? null : toolBar,
            footer: _s.pagination && !_s.fixedPagination ? pager : null,
            itemBuilder: (context, item, index) => _RankListRow(
              item: item,
              rank: item.rank > 0 ? item.rank : index + 1,
            ),
          )
        : PagedGridView<RankSubject, RankQuery>(
            provider: rankResultsProvider,
            arg: query,
            childAspectRatio: 0.58,
            emptyText: '暂无数据',
            autoLoadMore: !_s.pagination,
            header: _s.fixed ? null : toolBar,
            footer: _s.pagination && !_s.fixedPagination ? pager : null,
            itemBuilder: (context, item, index) => _RankGridCard(
              item: item,
              rank: item.rank > 0 ? item.rank : index + 1,
            ),
          );

    return Scaffold(
      appBar: BgmAppBar(
        title: '排行榜',
        showBackButton: true,
        actions: [
          BgmHeaderMore(
            items: rankMoreItems(
              fixed: _s.fixed,
              pagination: _s.pagination,
              list: _s.list,
              collected: _s.collected,
              fixedPagination: _s.fixedPagination,
            ),
            onSelected: _onMore,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_s.fixed) toolBar,
          Expanded(child: list),
          if (_s.pagination && _s.fixedPagination) pager!,
        ],
      ),
    );
  }

  void _onMore(String value) {
    switch (value) {
      case 'browser':
        openExternalUrl(
          '$kHost${htmlRankBrowserV2(type: _s.type == 'all' ? 'anime' : _s.type, filter: _s.filter, filterSub: _s.filterSub, source: _s.sourceValue, theme: _s.themeValue, tag: _s.tagValue, area: _s.areaValue, target: _s.targetValue, classification: _s.classificationValue, airtime: _s.airtimeSegment, order: _s.sort)}',
        );
      case 'spa':
        openExternalUrl(htmlSpa('Rank'));
      case 'toolbar':
        _setState((s) => s.copyWith(fixed: !s.fixed));
      case 'loaded':
        _setState((s) => s.copyWith(pagination: !s.pagination));
      case 'layout':
        _setState((s) => s.copyWith(list: !s.list));
      case 'favor':
        _setState((s) => s.copyWith(collected: !s.collected));
      case 'pager':
        _setState((s) => s.copyWith(fixedPagination: !s.fixedPagination));
    }
  }
}

// ---------------------------------------------------------------------------
// 工具栏
// ---------------------------------------------------------------------------

/// 第一行: 类型 / 排序 / 年 / 月 / 展开
class _PrimaryBar extends StatelessWidget {
  final RankState state;
  final ValueChanged<RankState Function(RankState)> onSelect;

  const _PrimaryBar({required this.state, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _ToolBarRow(
      children: [
        _PopoverChip(
          text: state.typeCn,
          icon: Icons.filter_list,
          options: [for (final t in kRankTypes) t.$2],
          selected: state.typeCn,
          onSelected: (title) {
            final type = kRankTypes.firstWhere((e) => e.$2 == title).$1;
            onSelect(
              (s) => s.copyWith(
                type: type,
                filter: '',
                filterSub: '',
                source: '全部',
                tag: '全部',
                area: '全部',
                target: '全部',
                classification: '全部',
                theme: '全部',
              ),
            );
          },
        ),
        _PopoverChip(
          text: kRankSorts
              .where((e) => e.$1 == state.sort)
              .map((e) => e.$2)
              .firstWhere((_) => true, orElse: () => '收藏'),
          icon: Icons.sort,
          options: [for (final (_, l) in kRankSorts) l],
          selected: kRankSorts
              .where((e) => e.$1 == state.sort)
              .map((e) => e.$2)
              .firstWhere((_) => true, orElse: () => ''),
          onSelected: (label) {
            final value = kRankSorts.firstWhere((e) => e.$2 == label).$1;
            onSelect((s) => s.copyWith(sort: value));
          },
        ),
        _PopoverChip(
          text: state.airtimeValue.isEmpty ? '时间' : state.airtimeValue,
          options: kRankYears,
          selected: state.airtime,
          onSelected: (y) =>
              onSelect((s) => s.copyWith(airtime: y, month: '全部')),
        ),
        if (state.airtimeValue.isNotEmpty)
          _PopoverChip(
            text: state.monthValue.isEmpty ? '月' : '${state.monthValue}月',
            options: kRankMonths,
            selected: state.month,
            onSelected: (m) => onSelect((s) => s.copyWith(month: m)),
          ),
        if (state.typeCn != '音乐' && state.typeCn != '全部')
          BgmHeaderAction(
            icon: Icon(
              state.expand
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: state.hasActiveSubFilter
                  ? context.ds.accent
                  : context.ds.textHint,
              size: 20,
            ),
            onPressed: () => onSelect((s) => s.copyWith(expand: !s.expand)),
          ),
      ],
    );
  }
}

/// 第二行 (展开): 一级分类 / 二级分类 / 来源 / 标签 / 题材 / 地区 / 受众 / 分级
class _ExpandedBar extends StatelessWidget {
  final RankState state;
  final ValueChanged<RankState Function(RankState)> onSelect;

  const _ExpandedBar({required this.state, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final typeCn = state.typeCn;
    final children = <Widget>[];

    // 一级分类 (动画/书籍/游戏/三次元)
    final filterOptions = kRankFilter[typeCn];
    if (filterOptions != null) {
      children.add(
        _PopoverChip(
          text: _filterLabel(filterOptions, state.filter) == '全部'
              ? '分类'
              : _filterLabel(filterOptions, state.filter),
          options: [for (final (l, _) in filterOptions) l],
          selected: _filterLabel(filterOptions, state.filter),
          onSelected: (label) {
            final value = filterOptions.firstWhere((e) => e.$1 == label).$2;
            onSelect((s) => s.copyWith(filter: value));
          },
        ),
      );
    }

    // 二级分类 (书籍=系列 / 游戏=平台)
    final filterSubOptions = kRankFilterSub[typeCn];
    if (filterSubOptions != null) {
      final text = _filterLabel(filterSubOptions, state.filterSub);
      children.add(
        _PopoverChip(
          text: text == '全部' ? (kRankFilterSubText[typeCn] ?? '二级') : text,
          options: [for (final (l, _) in filterSubOptions) l],
          selected: text,
          onSelected: (label) {
            final value = filterSubOptions.firstWhere((e) => e.$1 == label).$2;
            onSelect((s) => s.copyWith(filterSub: value));
          },
        ),
      );
    }

    // 来源 (动画)
    if (typeCn == '动画') {
      children.add(
        _PopoverChip(
          text: state.sourceValue.isEmpty ? '来源' : state.source,
          options: kRankSource,
          selected: state.source,
          onSelected: (v) => onSelect((s) => s.copyWith(source: v)),
        ),
      );
    }

    // 公共标签 (动画 + 游戏)
    final tagOptions = kRankTag[typeCn];
    if (tagOptions != null) {
      children.add(
        _PopoverChip(
          text: state.tagValue.isEmpty ? '类型' : state.tag,
          options: tagOptions,
          selected: state.tag,
          onSelected: (v) => onSelect((s) => s.copyWith(tag: v)),
        ),
      );
    }

    // 题材 (三次元)
    if (typeCn == '三次元') {
      children.add(
        _PopoverChip(
          text: state.themeValue.isEmpty ? '题材' : state.theme,
          options: kRankTheme,
          selected: state.theme,
          onSelected: (v) => onSelect((s) => s.copyWith(theme: v)),
        ),
      );
    }

    // 地区 (动画 + 三次元)
    final areaOptions = kRankArea[typeCn];
    if (areaOptions != null) {
      children.add(
        _PopoverChip(
          text: state.areaValue.isEmpty ? '地区' : state.area,
          options: areaOptions,
          selected: state.area,
          onSelected: (v) => onSelect((s) => s.copyWith(area: v)),
        ),
      );
    }

    // 受众 (动画 + 游戏)
    final targetOptions = kRankTarget[typeCn];
    if (targetOptions != null) {
      children.add(
        _PopoverChip(
          text: state.targetValue.isEmpty ? '受众' : state.target,
          options: targetOptions,
          selected: state.target,
          onSelected: (v) => onSelect((s) => s.copyWith(target: v)),
        ),
      );
    }

    // 分级 (游戏)
    if (typeCn == '游戏') {
      children.add(
        _PopoverChip(
          text: state.classificationValue.isEmpty ? '分级' : state.classification,
          options: kRankClassification,
          selected: state.classification,
          onSelected: (v) => onSelect((s) => s.copyWith(classification: v)),
        ),
      );
    }

    return _ToolBarRow(children: children);
  }

  String _filterLabel(List<(String, String)> options, String value) {
    for (final (l, v) in options) {
      if (v == value) return l;
    }
    return '全部';
  }
}

/// 工具栏一行的水平滚动容器
class _ToolBarRow extends StatelessWidget {
  final List<Widget> children;
  const _ToolBarRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Popover 筛选 chip (点击弹出选项菜单)
class _PopoverChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _PopoverChip({
    required this.text,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final active =
        selected != '全部' && options.isNotEmpty && selected != options.first;
    return PopupMenuButton<String>(
      tooltip: text,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem(
            value: o,
            child: Text(
              o,
              style: TextStyle(
                fontWeight: o == selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(minWidth: 32, minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: ds.surfaceCard.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: ds.textPrimary),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: ds.caption.copyWith(
                color: active ? ds.textPrimary : ds.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 列表/网格 渲染
// ---------------------------------------------------------------------------

/// 列表行: 排名 + 封面 + 名(CN优先) + 评分/人数 + tip + 收藏标记
class _RankListRow extends StatelessWidget {
  final RankSubject item;
  final int rank;
  const _RankListRow({required this.item, required this.rank});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return InkWell(
      onTap: () => context.push('/subject/${item.id}'),
      onLongPress: () => showCollectionSheet(context, item.id),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: ds.title.copyWith(
                  color: rank <= 3 ? ds.accent : ds.textHint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Cover(url: item.cover, width: 56, height: 76, radius: 4),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ds.label.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: visualFontSize(item.displayName, const [
                        (18, 14),
                        (0, 15),
                      ]),
                    ),
                  ),
                  if (item.name != item.displayName &&
                      item.name.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ds.caption,
                    ),
                  ],
                  if (!SettingsStore.instance.hideScore && item.score > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          item.score.toStringAsFixed(1),
                          style: ds.caption.copyWith(
                            color: ds.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.total > 0) ...[
                          const SizedBox(width: 6),
                          Text('${item.total}人评分', style: ds.meta),
                        ],
                      ],
                    ),
                  ],
                  if (item.tip.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.tip,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ds.meta,
                    ),
                  ],
                ],
              ),
            ),
            BgmHeaderAction(
              tooltip: item.collected ? '修改收藏' : '收藏',
              icon: Icon(
                item.collected ? Icons.bookmark : Icons.bookmark_add_outlined,
                size: 18,
                color: item.collected ? ds.accent : ds.textHint,
              ),
              onPressed: () => showCollectionSheet(context, item.id),
            ),
          ],
        ),
      ),
    );
  }
}

/// 网格卡片: 复用布局 (封面 + 排名角标 + 名 + 评分)
class _RankGridCard extends StatelessWidget {
  final RankSubject item;
  final int rank;
  const _RankGridCard({required this.item, required this.rank});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return InkWell(
      onTap: () => context.push('/subject/${item.id}'),
      onLongPress: () => showCollectionSheet(context, item.id),

      borderRadius: BorderRadius.circular(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Cover(
                  url: item.cover,
                  width: double.infinity,
                  height: double.infinity,
                  radius: 6,
                ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rank <= 3
                          ? ds.accent
                          : Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (item.collected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(Icons.bookmark, size: 16, color: ds.accent),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ds.caption.copyWith(
              height: 1.25,
              fontSize: visualFontSize(item.displayName, const [
                (18, 10),
                (14, 11),
                (0, 12),
              ]),
            ),
          ),

          if (!SettingsStore.instance.hideScore && item.score > 0) ...[
            const SizedBox(height: 3),
            Text(
              '${item.score.toStringAsFixed(1)}分',
              maxLines: 1,
              style: ds.meta.copyWith(
                color: ds.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 原版 Pagination: 上一页 / 页码输入 / 下一页
class _RankPagination extends ConsumerStatefulWidget {
  final RankQuery query;

  const _RankPagination({required this.query});

  @override
  ConsumerState<_RankPagination> createState() => _RankPaginationState();
}

class _RankPaginationState extends ConsumerState<_RankPagination> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int get _page => int.tryParse(_ctrl.text.trim()) ?? 1;

  Future<void> _go(int page) async {
    if (page < 1) return;
    _ctrl.text = '$page';
    await ref.read(rankResultsProvider(widget.query).notifier).loadPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final page =
        ref.watch(rankResultsProvider(widget.query)).valueOrNull?.page ?? 1;
    if (_ctrl.text != '$page' && !_ctrl.value.composing.isValid) {
      _ctrl.text = '$page';
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: BgmHeaderAction(
                tooltip: '上一页',
                icon: const Icon(Icons.navigate_before, size: 22),
                onPressed: page <= 1 ? null : () => _go(page - 1),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _ctrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '页',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _go(_page),
              ),
            ),
            Expanded(
              child: BgmHeaderAction(
                tooltip: '下一页',
                icon: const Icon(Icons.navigate_next, size: 22),
                onPressed: () => _go(page + 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
