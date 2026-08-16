import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import 'widgets/discovery_html.dart';
import 'widgets/paged.dart';
import '../../shared/widgets/bgm_button.dart';

class BlogList extends PagedNotifier<BlogListRow, String> {
  @override
  Future<List<BlogListRow>> fetchPage(String arg, int page) async {
    final client = ref.read(apiClientProvider);
    final body = await client.get(
      htmlBlogList(type: arg, page: page),
      host: kHost,
    );
    return parseBlogList(body as String);
  }
}

final blogListProvider =
    AsyncNotifierProvider.family<BlogList, PagedData<BlogListRow>, String>(
      BlogList.new,
    );

/// 原版 HeaderV2Popover DATA: 浏览器查看 + 网页版查看
const kBlogListMoreItems = <(String, String)>[
  ('browser', '浏览器查看'),
  ('spa', '网页版查看'),
];

/// 全站日志 (原项目 TabsV2: 全部/动画/书籍/游戏/音乐/三次元)
class BlogScreen extends ConsumerStatefulWidget {
  const BlogScreen({super.key});

  @override
  ConsumerState<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends ConsumerState<BlogScreen> {
  static const _types = <(String key, String label)>[
    ('all', '全部'),
    ('anime', '动画'),
    ('book', '书籍'),
    ('game', '游戏'),
    ('music', '音乐'),
    ('real', '三次元'),
  ];
  int _type = 0;

  String get _typeKey => _types[_type].$1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: '日志',
        showBackButton: true,
        actions: [
          BgmHeaderAction(
            tooltip: '我的日志',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/my-blogs'),
          ),
          BgmHeaderMore(
            items: kBlogListMoreItems,
            onSelected: (value) {
              if (value == 'browser') {
                openExternalUrl('$kHost${htmlBlogList(type: _typeKey)}');
              } else if (value == 'spa') {
                openExternalUrl(htmlSpa('DiscoveryBlog'));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          BgmTabStrip(
            scrollable: true,
            index: _type,
            onSelect: (i) => setState(() => _type = i),
            tabs: [for (final t in _types) Text(t.$2)],
          ),

          Expanded(
            child: PagedListView<BlogListRow, String>(
              provider: blogListProvider,
              arg: _typeKey,
              emptyText: '暂无日志',
              itemBuilder: (context, row, index) => _BlogRow(row: row),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlogRow extends StatelessWidget {
  final BlogListRow row;

  const _BlogRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/rakuen/blog/${row.id}'),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 44,
                height: 44,
                child: row.cover.isEmpty
                    ? Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                      )
                    : Cover(url: row.cover, width: 44, height: 44, radius: 4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (row.content.isNotEmpty)
                    Text(
                      row.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${row.username} · ${row.time} · ${row.replies} 回复',
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
