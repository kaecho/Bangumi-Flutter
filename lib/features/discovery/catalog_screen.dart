import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import 'widgets/discovery_html.dart';
import 'widgets/paged.dart';

/// 目录列表查询参数 (作为 family key)
class CatalogQuery {
  final String orderby; // rank | date | user
  const CatalogQuery(this.orderby);

  @override
  bool operator ==(Object other) => other is CatalogQuery && other.orderby == orderby;

  @override
  int get hashCode => orderby.hashCode;
}

/// 目录列表 Tab: 人气/最新/用户
const kCatalogOrders = [
  ('rank', '人气'),
  ('date', '最新'),
  ('user', '用户'),
];

class CatalogList extends PagedNotifier<CatalogRow, CatalogQuery> {
  @override
  Future<List<CatalogRow>> fetchPage(CatalogQuery arg, int page) async {
    final client = ref.read(apiClientProvider);
    // 旧版 /index/list JSON API 已下线, 解析主站目录浏览页
    final body = await client.get(
      htmlCatalogBrowser(page: page, orderby: arg.orderby),
      host: kHost,
    );
    return parseCatalogList(body as String);
  }
}

final catalogListProvider =
    AsyncNotifierProvider.family<CatalogList, PagedData<CatalogRow>, CatalogQuery>(
  CatalogList.new,
);

/// 目录列表
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  String _orderby = 'rank';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(title: '目录', showBackButton: true),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final (value, label) in kCatalogOrders)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Tag(
                      text: label,
                      active: _orderby == value,
                      onTap: () => setState(() => _orderby = value),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PagedListView<CatalogRow, CatalogQuery>(
              provider: catalogListProvider,
              arg: CatalogQuery(_orderby),
              emptyText: '暂无目录',
              itemBuilder: (context, row, index) => _CatalogRowView(row: row),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogRowView extends StatelessWidget {
  final CatalogRow row;

  const _CatalogRowView({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  const SizedBox(height: 3),
                  if (row.desc.isNotEmpty)
                    Text(
                      row.desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 3),
                  Text(
                    '${row.username} · 收录 ${row.total} 条目 · 更新 ${row.updatedAt}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.outline,
                    ),
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
