import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import 'widgets/paged.dart';
import '../../design_system/design_system.dart';

/// 机核资讯文章 (Anitama 数据源)
class NewsArticle {
  final String id;
  final String title;
  final String desc;
  final String thumb;
  final int comments;
  final int likes;
  final String publishedAt;
  final String url;

  const NewsArticle({
    this.id = '',
    this.title = '',
    this.desc = '',
    this.thumb = '',
    this.comments = 0,
    this.likes = 0,
    this.publishedAt = '',
    this.url = '',
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? const {};
    return NewsArticle(
      id: json['id']?.toString() ?? '',
      title: attrs['title'] as String? ?? '',
      desc: attrs['desc'] as String? ?? '',
      thumb: attrs['thumb'] as String? ?? '',
      comments: (attrs['comments-count'] as num?)?.toInt() ?? 0,
      likes: (attrs['likes-count'] as num?)?.toInt() ?? 0,
      publishedAt: attrs['published-at'] as String? ?? '',
      url: 'https://www.gcores.com/articles/${json['id']}',
    );
  }
}

/// 原版 NEWS 菜单: 来源 + 浏览器查看
const kAnitamaSources = <(int, String)>[(0, '机核'), (1, '异世界'), (2, '游民星空')];

/// Anitama 资讯
///
/// 原项目聚合机核 / 异世界 / 游民星空 三个资讯源, 其中机核使用公开
/// JSON:API, 这里移植机核源 (其余为 HTML 抓取, 不稳定)。
final newsListProvider =
    AsyncNotifierProvider.family<NewsList, PagedData<NewsArticle>, int>(
      NewsList.new,
    );

class NewsList extends PagedNotifier<NewsArticle, int> {
  @override
  Future<List<NewsArticle>> fetchPage(int arg, int page) async {
    final client = ref.read(apiClientProvider);
    final data = await client.get(
      apiGcoresOriginals(page),
      host: 'https://www.gcores.com',
    );
    final map = data as Map<String, dynamic>;
    return (map['data'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(NewsArticle.fromJson)
            .toList() ??
        const [];
  }
}

class AnitamaScreen extends ConsumerStatefulWidget {
  const AnitamaScreen({super.key});

  @override
  ConsumerState<AnitamaScreen> createState() => _AnitamaScreenState();
}

class _AnitamaScreenState extends ConsumerState<AnitamaScreen> {
  int _source = 0; // 0 机核 1 异世界 2 游民

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: '业界资讯',
        showBackButton: true,
        actions: [
          BgmHeaderMore(
            items: [
              for (final source in kAnitamaSources) ('${source.$1}', source.$2),
              ('browser', '浏览器查看'),
            ],

            onSelected: (value) {
              if (value == 'browser') {
                openExternalUrl(switch (_source) {
                  1 => 'https://www.iyingshi.com/',
                  2 => 'https://acg.gamersky.com/',
                  _ => 'https://www.gcores.com/',
                });
                return;
              }
              setState(() => _source = int.parse(value));
            },
          ),
        ],
      ),
      body: switch (_source) {
        1 => const _ExternalNewsHint(
          name: '异世界动画',
          url: 'https://www.iyingshi.com/',
        ),
        2 => const _ExternalNewsHint(
          name: '游民星空动漫',
          url: 'https://acg.gamersky.com/',
        ),
        _ => PagedListView<NewsArticle, int>(
          provider: newsListProvider,
          arg: 0,
          emptyText: '暂无资讯',
          itemBuilder: (context, item, index) => _NewsRow(article: item),
        ),
      },
    );
  }
}

class _ExternalNewsHint extends StatelessWidget {
  final String name;
  final String url;

  const _ExternalNewsHint({required this.name, required this.url});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$name 无稳定公开 API, 打开网页浏览'),
          const SizedBox(height: 12),
          BgmButton(
            '打开$name',
            expand: false,
            onPressed: () => context.push('/web/${Uri.encodeComponent(url)}'),
          ),
        ],
      ),
    );
  }
}

class _NewsRow extends StatelessWidget {
  final NewsArticle article;

  const _NewsRow({required this.article});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/web/${Uri.encodeComponent(article.url)}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 96,
                height: 64,
                child: article.thumb.isEmpty
                    ? Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                      )
                    : Image.network(
                        'https://image.gcores.com/${article.thumb}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (article.desc.isNotEmpty)
                    Text(
                      article.desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${article.likes} 赞 · ${article.comments} 评论 · ${article.publishedAt}',
                    style: context.ds.meta,
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
