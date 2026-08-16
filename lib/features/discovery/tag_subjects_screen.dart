import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';
import '../../shared/models/subject.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/cover.dart';
import '../subject/collection_sheet.dart';
import 'tags_screen.dart';
import 'widgets/discovery_html.dart';
import 'widgets/paged.dart';
import 'widgets/subject_card.dart';

/// 原版用户标签标题: `{typeCn} · {tag}` / `{typeCn}标签`
String tagTypeCn(String type) =>
    kTagTypes.where((e) => e.$1 == type).firstOrNull?.$2 ?? '动画';

String tagSubjectsTitle(String type, String tag) {
  final cn = tagTypeCn(type);
  return tag.isEmpty ? '$cn标签' : '$cn · $tag';
}

/// 原版 HeaderV2Popover: 浏览器查看 + 工具栏/布局/收藏
List<(String, String)> tagSubjectsMoreItems({
  required bool fixed,
  required bool list,
  required bool collected,
}) => [
  ('browser', '浏览器查看'),
  ('toolbar', '工具栏〔${fixed ? '锁定' : '浮动'}〕'),
  ('layout', '布　局〔${list ? '列表' : '网格'}〕'),
  ('favor', '收　藏〔${collected ? '显示' : '不显示'}〕'),
];

/// 原版 TAG_ORDERBY
const kTagOrders = <(String, String)>[
  ('rank', '排名'),
  ('trends', '热度'),
  ('collects', '收藏'),
  ('date', '日期'),
  ('title', '名称'),
];

const kTagMonths = [
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

List<String> tagAirtimeYears() => [
  '全部',
  for (var y = DateTime.now().year; y >= 1980; y--) '$y',
];

String tagOrderLabel(String order) =>
    kTagOrders.where((e) => e.$1 == order).firstOrNull?.$2 ?? '收藏';

/// 原版 HTML_TAG airtime: 有月则 `年-月`
String tagSubjectsAirtime(String year, String month) {
  if (year.isEmpty) return '';
  if (month.isEmpty) return year;
  return '$year-$month';
}

/// 标签条目查询参数 (作为 family key)
class TagSubjectsQuery {
  final String type; // anime | book | real | game
  final String tag;
  final bool collected;
  final String sort;
  final String year;
  final String month;
  final bool meta;

  const TagSubjectsQuery(
    this.type,
    this.tag, {
    this.collected = true,
    this.sort = 'collects',
    this.year = '',
    this.month = '',
    this.meta = false,
  });

  String get airtime => tagSubjectsAirtime(year, month);

  @override
  bool operator ==(Object other) =>
      other is TagSubjectsQuery &&
      other.type == type &&
      other.tag == tag &&
      other.collected == collected &&
      other.sort == sort &&
      other.year == year &&
      other.month == month &&
      other.meta == meta;

  @override
  int get hashCode =>
      Object.hash(type, tag, collected, sort, year, month, meta);
}

class TagSubjects extends PagedNotifier<Subject, TagSubjectsQuery> {
  @override
  Future<List<Subject>> fetchPage(TagSubjectsQuery arg, int page) async {
    final client = ref.read(apiClientProvider);
    final body = await client.get(
      htmlTagSubjects(
        arg.type,
        arg.tag,
        page: page,
        sort: arg.sort,
        airtime: arg.airtime,
        meta: arg.meta,
      ),
      host: kHost,
    );
    final items = parseSubjectList(body as String);
    if (arg.collected) return items;
    return [
      for (final item in items)
        if (!item.collected) item,
    ];
  }
}

final tagSubjectsProvider =
    AsyncNotifierProvider.family<
      TagSubjects,
      PagedData<Subject>,
      TagSubjectsQuery
    >(TagSubjects.new);

/// 标签条目列表 (/tags/:type/:tag)
class TagSubjectsScreen extends ConsumerStatefulWidget {
  final String type;
  final String tag;

  const TagSubjectsScreen({super.key, required this.type, required this.tag});

  @override
  ConsumerState<TagSubjectsScreen> createState() => _TagSubjectsScreenState();
}

class _TagSubjectsScreenState extends ConsumerState<TagSubjectsScreen> {
  bool _fixed = false;
  bool _list = false;
  bool _collected = true;
  String _sort = 'collects';
  String _year = '';
  String _month = '';
  bool _meta = false;

  TagSubjectsQuery get _arg => TagSubjectsQuery(
    widget.type,
    widget.tag,
    collected: _collected,
    sort: _sort,
    year: _year,
    month: _month,
    meta: _meta,
  );

  @override
  Widget build(BuildContext context) {
    final toolBar = _TagSubjectsToolBar(
      list: _list,
      collected: _collected,
      sort: _sort,
      year: _year,
      month: _month,
      meta: _meta,
      onToggleList: () => setState(() => _list = !_list),
      onToggleCollected: () => setState(() => _collected = !_collected),
      onSort: (v) => setState(() => _sort = v),
      onYear: (v) => setState(() {
        _year = v;
        if (v.isEmpty) _month = '';
      }),
      onMonth: (v) {
        if (_year.isEmpty) {
          showBgmToast(context, '请先选择年');
          return;
        }
        setState(() => _month = v);
      },
      onMeta: (v) => setState(() => _meta = v),
    );
    final list = _list
        ? PagedListView<Subject, TagSubjectsQuery>(
            provider: tagSubjectsProvider,
            arg: _arg,
            emptyText: '该标签下暂无条目',
            itemBuilder: (context, subject, index) =>
                _TagSubjectRow(subject: subject),
          )
        : PagedGridView<Subject, TagSubjectsQuery>(
            provider: tagSubjectsProvider,
            arg: _arg,
            childAspectRatio: 0.58,
            emptyText: '该标签下暂无条目',
            itemBuilder: (context, subject, index) => SubjectCard(
              subject: subject,
              rank: subject.rank > 0 ? subject.rank : null,
            ),
          );
    return Scaffold(
      appBar: BgmAppBar(
        title: tagSubjectsTitle(widget.type, widget.tag),
        showBackButton: true,
        actions: [
          BgmHeaderAction(
            tooltip: '分类排行',
            icon: const Icon(Icons.equalizer, size: 20),
            onPressed: () => context.push(
              '/typerank?type=${Uri.encodeQueryComponent(widget.type)}'
              '&tag=${Uri.encodeQueryComponent(widget.tag)}',
            ),
          ),
          BgmHeaderMore(
            items: tagSubjectsMoreItems(
              fixed: _fixed,
              list: _list,
              collected: _collected,
            ),
            onSelected: (value) {
              switch (value) {
                case 'browser':
                  openExternalUrl(
                    '$kHost${htmlTagSubjects(widget.type, widget.tag, sort: _sort, airtime: tagSubjectsAirtime(_year, _month), meta: _meta)}',
                  );
                case 'toolbar':
                  setState(() => _fixed = !_fixed);
                case 'layout':
                  setState(() => _list = !_list);
                case 'favor':
                  setState(() => _collected = !_collected);
              }
            },
          ),
        ],
      ),
      body: _fixed
          ? Column(
              children: [
                toolBar,
                Expanded(child: list),
              ],
            )
          : Stack(
              children: [
                Positioned.fill(child: list),
                Positioned(left: 0, right: 0, top: 0, child: toolBar),
              ],
            ),
    );
  }
}

class _TagSubjectsToolBar extends StatelessWidget {
  final bool list;
  final bool collected;
  final String sort;
  final String year;
  final String month;
  final bool meta;
  final VoidCallback onToggleList;
  final VoidCallback onToggleCollected;
  final ValueChanged<String> onSort;
  final ValueChanged<String> onYear;
  final ValueChanged<String> onMonth;
  final ValueChanged<bool> onMeta;

  const _TagSubjectsToolBar({
    required this.list,
    required this.collected,
    required this.sort,
    required this.year,
    required this.month,
    required this.meta,
    required this.onToggleList,
    required this.onToggleCollected,
    required this.onSort,
    required this.onYear,
    required this.onMonth,
    required this.onMeta,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.ds.surfaceBase,
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            BgmSelect<String>(
              value: sort,
              items: kTagOrders,
              onChanged: onSort,
              tooltip: '排序',
            ),
            const SizedBox(width: 8),
            BgmSelect<String>(
              value: year.isEmpty ? '全部' : year,
              items: [
                for (final y in tagAirtimeYears()) (y, y == '全部' ? '年' : y),
              ],
              onChanged: (v) => onYear(v == '全部' ? '' : v),
              tooltip: '年',
            ),
            const SizedBox(width: 8),
            BgmSelect<String>(
              value: month.isEmpty ? '全部' : month,
              items: [for (final m in kTagMonths) (m, m == '全部' ? '月' : '$m月')],
              onChanged: (v) => onMonth(v == '全部' ? '' : v),
              tooltip: '月',
            ),
            const SizedBox(width: 8),
            BgmSelect<bool>(
              value: meta,
              items: const [(false, '用户标签'), (true, '公共标签')],
              onChanged: onMeta,
              tooltip: '公共标签',
            ),
          ],
        ),
      ),
    );
  }
}

class _TagSubjectRow extends StatelessWidget {
  final Subject subject;

  const _TagSubjectRow({required this.subject});

  @override
  Widget build(BuildContext context) {
    return BgmTextRow(
      leading: Cover(
        url: subject.images.medium.isNotEmpty
            ? subject.images.medium
            : subject.images.large,
        width: 40,
        height: 56,
        radius: 4,
      ),
      title: subject.displayName,
      onTap: () => context.push('/subject/${subject.id}'),
      onLongPress: () => showCollectionSheet(context, subject.id),
    );
  }
}
