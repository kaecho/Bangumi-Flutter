import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/app_bar.dart';
import 'widgets/paged.dart';

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

/// Anitama 资讯
///
/// 原项目聚合机核 / 异世界 / 游民星空 三个资讯源, 其中机核使用公开
/// JSON:API, 这里移植机核源 (其余为 HTML 抓取, 不稳定)。
final newsListProvider =
    AsyncNotifierProvider.family<NewsList, PagedData<NewsArticle>, int>(NewsList.new);

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

class AnitamaScreen extends ConsumerWidget {
  const AnitamaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: BgmAppBar(title: '资讯', showBackButton: true),
      body: PagedListView<NewsArticle, int>(
        provider: newsListProvider,
        arg: 0,
        emptyText: '暂无资讯',
        itemBuilder: (context, item, index) => _NewsRow(article: item),
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
                    ? Container(color: theme.colorScheme.surfaceContainerHighest)
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
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
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
