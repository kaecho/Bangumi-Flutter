import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';

import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';

import 'catalog_notes.dart';
import 'widgets/discovery_html.dart';
import 'widgets/paged.dart';
import '../../shared/widgets/bgm_button.dart';

/// 目录列表查询参数 (作为 family key)
///
/// [type] 对应原项目 TYPE_DS.key: 'advance' 整合 / 'collect' 热门 / '' 最新。
/// 'advance' 走本地数据集 (protobuf, 暂未移植), 其余走主站 HTML。
class CatalogQuery {
  /// 'advance' | 'collect' | ''
  final String type;

  const CatalogQuery(this.type);

  @override
  bool operator ==(Object other) => other is CatalogQuery && other.type == type;

  @override
  int get hashCode => type.hashCode;
}

/// 列表类型 Tab (移植自 catalog/ds.ts TYPE_DS)
const kCatalogTypes = [('advance', '整合'), ('collect', '热门'), ('', '最新')];

/// 整合模式筛选条目类型 (移植自 FILTER_TYPE_DS, 仅展示, 不可用)
const kCatalogFilterTypes = [
  '不限',
  '动画',
  '书籍',
  '游戏',
  '音乐',
  '三次元',
  '角色',
  '人物',
  '小组',
  '章节',
  '日志',
];

/// 整合模式筛选年份 (移植自 FILTER_YEAR_DS, 仅展示, 不可用)
const kCatalogFilterYears = [
  '不限',
  '近1年',
  '近3年',
  '2026',
  '2025',
  '2024',
  '2023',
  '2022',
  '2021',
  '2020',
  '2019',
  '2018',
  '2017',
  '2016',
  '2015',
  '2014',
  '2013',
  '2012',
  '2011',
  '2010',
];

/// 整合模式关键字 (移植自 FILTER_KEY_DS, 仅展示)
const kCatalogFilterKeys = [
  '不限 (2000)',
  '动画 (280)',
  '漫画 (149)',
  '作品 (131)',
  '个人 (116)',
  '游戏 (96)',
  '日本 (90)',
  '推荐 (86)',
  '小说 (63)',
  '系列 (55)',
  '百合 (47)',
  '排行榜 (45)',
];

/// 原版 HeaderV2Popover: 浏览器查看 + 网页版查看 + 补充说明 + 锁定
List<(String, String)> catalogMoreItems({
  required bool fixedFilter,
  required bool fixedPagination,
}) => [
  ('browser', '浏览器查看'),
  ('spa', '网页版查看'),
  ('info', '补充说明'),
  ('toolbar', '工具栏〔${fixedFilter ? '锁定' : '浮动'}〕'),
  ('pager', '分页器〔${fixedPagination ? '锁定' : '浮动'}〕'),
];

/// 目录列表 (热门/最新)
class CatalogList extends PagedNotifier<CatalogRow, CatalogQuery> {
  @override
  Future<List<CatalogRow>> fetchPage(CatalogQuery arg, int page) async {
    // advance 走本地数据集, 不在此加载
    if (arg.type == 'advance') return const [];
    final client = ref.read(apiClientProvider);
    // orderby: collect=热门, ''=最新 (移植自 HTML_CATALOG(type, page))
    final body = await client.get(
      htmlCatalogBrowser(page: page, orderby: arg.type),
      host: kHost,
    );
    return parseCatalogList(body as String);
  }
}

final catalogListProvider =
    AsyncNotifierProvider.family<
      CatalogList,
      PagedData<CatalogRow>,
      CatalogQuery
    >(CatalogList.new);

/// 目录列表
class CatalogScreen extends ConsumerStatefulWidget {
  /// 从搜索页跳转携带的关键字 (整合模式预筛选用, 暂未移植本地数据集故不生效)
  final String? keyword;

  const CatalogScreen({super.key, this.keyword});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  late String _type = widget.keyword != null && widget.keyword!.isNotEmpty
      ? 'advance'
      : 'collect';
  String _filterType = '不限';
  String _filterYear = '不限';
  String _filterKey = '不限';
  bool _fixedFilter = true;
  bool _fixedPagination = true;

  String get _typeLabel => kCatalogTypes
      .firstWhere((e) => e.$1 == _type, orElse: () => kCatalogTypes.first)
      .$2;

  void _onMore(String value) {
    switch (value) {
      case 'browser':
        openExternalUrl('$kHost/index/browser?orderby=collect');
      case 'spa':
        openExternalUrl(htmlSpa('Catalog'));
      case 'info':
        context.push(catalogNotePath());
      case 'toolbar':
        setState(() => _fixedFilter = !_fixedFilter);
      case 'pager':
        setState(() => _fixedPagination = !_fixedPagination);
    }
  }

  Widget _toolBar() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
        children: [
          _CatalogPill(
            label: _typeLabel,
            icon: Icons.grid_view,
            options: [for (final t in kCatalogTypes) t.$2],
            selected: _typeLabel,
            onSelected: (title) {
              final next = kCatalogTypes.firstWhere((e) => e.$2 == title);
              setState(() => _type = next.$1);
            },
          ),
          if (_type == 'advance') ...[
            const SizedBox(width: 8),
            _CatalogPill(
              label: _filterType == '不限' ? '类型' : _filterType,
              icon: Icons.filter_list,
              options: kCatalogFilterTypes,
              selected: _filterType,
              onSelected: (v) => setState(() => _filterType = v),
            ),
            const SizedBox(width: 8),
            _CatalogPill(
              label: _filterYear == '不限' ? '年份' : _filterYear,
              options: kCatalogFilterYears,
              selected: _filterYear,
              onSelected: (v) => setState(() => _filterYear = v),
            ),
            const SizedBox(width: 8),
            _CatalogPill(
              label: _filterKey == '不限' ? '关键字' : _filterKey,
              options: kCatalogFilterKeys,
              selected: _filterKey,
              onSelected: (v) =>
                  setState(() => _filterKey = v.split(' (').first),
            ),
          ],
          const SizedBox(width: 8),
          BgmHeaderAction(
            tooltip: '搜索目录',
            icon: const Icon(Icons.search, size: 18),
            onPressed: () => context.push('/search?type=目录'),
          ),
        ],
      ),
    );
  }

  Widget _pager() {
    return _CatalogPagination(query: CatalogQuery(_type));
  }

  @override
  Widget build(BuildContext context) {
    final toolBar = _toolBar();
    final pager = _pager();
    final list = _type == 'advance'
        ? const _AdvancePlaceholder()
        : PagedListView<CatalogRow, CatalogQuery>(
            provider: catalogListProvider,
            arg: CatalogQuery(_type),
            emptyText: '到底了',
            autoLoadMore: false,
            header: _fixedFilter ? null : toolBar,
            footer: _fixedPagination ? null : pager,
            itemBuilder: (context, row, index) => _CatalogRowView(row: row),
          );
    return Scaffold(
      appBar: BgmAppBar(
        title: '目录',
        showBackButton: true,
        actions: [
          BgmHeaderAction(
            tooltip: '我的目录',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/my-catalogs'),
          ),
          BgmHeaderMore(
            items: catalogMoreItems(
              fixedFilter: _fixedFilter,
              fixedPagination: _fixedPagination,
            ),
            onSelected: _onMore,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_fixedFilter) toolBar,
          Expanded(child: list),
          if (_fixedPagination) pager,
        ],
      ),
    );
  }
}

/// 整合目录占位 (本地数据集未移植)
class _AdvancePlaceholder extends StatelessWidget {
  const _AdvancePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dataset_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text('整合目录依赖本地数据集，暂未移植'),
            const SizedBox(height: 4),
            Text(
              '热门 / 最新 仍可使用',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 原版 ToolBar.Popover 灰底药丸
class _CatalogPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CatalogPill({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return PopupMenuButton<String>(
      tooltip: label,
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem(
            value: o,
            child: Text(
              o,
              style: TextStyle(
                fontWeight: o == selected || o.split(' (').first == selected
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: ds.surfaceCard.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: ds.textPrimary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: ds.caption.copyWith(
                color: ds.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 目录行 (移植自 ItemCatalog 的简版: 封面 + 标题 + 作者 + 收录数 + 更新时间)
class _CatalogRowView extends StatelessWidget {
  final CatalogRow row;

  const _CatalogRowView({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 仅收录条目总数 > 0 的目录 (对应 ItemCatalog 的 total===0 过滤)
    if (row.total == 0) return const SizedBox.shrink();
    final typeCn = _catalogTypeCn(row);

    return InkWell(
      onTap: () => context.push('/catalog/${row.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 46,
                height: 46,
                child: row.avatar.isEmpty
                    ? Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.folder_outlined,
                          size: 22,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Cover(url: row.avatar, width: 46, height: 46, radius: 6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (row.desc.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      row.desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.bookmark_outline,
                        size: 13,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        typeCn.isEmpty
                            ? '收录 ${row.total} 条目'
                            : '$typeCn · 收录 ${row.total} 条目',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.primary,
                        ),
                      ),

                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${row.username} · 更新 ${row.updatedAt}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _catalogTypeCn(CatalogRow row) {
  final pairs = [
    (row.anime, '动画'),
    (row.book, '书籍'),
    (row.music, '音乐'),
    (row.game, '游戏'),
    (row.real, '三次元'),
  ];
  pairs.sort((a, b) => b.$1.compareTo(a.$1));
  return pairs.first.$1 > 0 ? pairs.first.$2 : '';
}

/// 原版 Pagination: 上一页 / 页码输入 / 下一页
class _CatalogPagination extends ConsumerStatefulWidget {
  final CatalogQuery query;

  const _CatalogPagination({required this.query});

  @override
  ConsumerState<_CatalogPagination> createState() => _CatalogPaginationState();
}

class _CatalogPaginationState extends ConsumerState<_CatalogPagination> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '1');
  }

  @override
  void didUpdateWidget(covariant _CatalogPagination oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _ctrl.text = '1';
    }
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
    await ref.read(catalogListProvider(widget.query).notifier).loadPage(page);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.type == 'advance') return const SizedBox.shrink();
    final page =
        ref.watch(catalogListProvider(widget.query)).valueOrNull?.page ?? 1;
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
