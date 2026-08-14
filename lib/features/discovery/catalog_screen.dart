import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/score.dart';
import 'catalog_notes.dart';
import 'widgets/discovery_html.dart';
import 'widgets/paged.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: '目录',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: '我的目录',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/my-catalogs'),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) {
              if (value == 'browser') {
                openExternalUrl('$kHost/index/browser?orderby=collect');
              } else if (value == 'info') {
                context.push(catalogNotePath());
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'info', child: Text('补充说明')),
              PopupMenuItem(value: 'browser', child: Text('浏览器查看')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部 Tab: 整合 / 热门 / 最新
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final (value, label) in kCatalogTypes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Tag(
                      text: label,
                      active: _type == value,
                      onTap: () => setState(() {
                        _type = value;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          if (_type == 'advance')
            // 整合模式: 筛选 chip (仅展示, 不可用)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final label in kCatalogFilterTypes)
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 8),
                      child: _DisabledChip(text: label),
                    ),
                  for (final label in kCatalogFilterYears)
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 8),
                      child: _DisabledChip(text: label),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _type == 'advance'
                ? const _AdvancePlaceholder()
                : PagedListView<CatalogRow, CatalogQuery>(
                    provider: catalogListProvider,
                    arg: CatalogQuery(_type),
                    emptyText: '到底了',
                    itemBuilder: (context, row, index) =>
                        _CatalogRowView(row: row),
                  ),
          ),
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

/// 不可用筛选 chip (整合模式占位)
class _DisabledChip extends StatelessWidget {
  final String text;

  const _DisabledChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
