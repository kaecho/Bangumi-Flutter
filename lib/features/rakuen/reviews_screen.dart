import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';

import 'rakuen_models.dart';
import 'rakuen_providers.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';

/// 原版影评 HeaderV2: `{name}的影评` / 影评
String reviewsTitle(String? name) {
  final n = name?.trim() ?? '';
  return n.isEmpty ? '影评' : '$n的影评';
}

String reviewsPath(int subjectId, {String? name}) {
  final n = name?.trim() ?? '';
  if (n.isEmpty) return '/rakuen/reviews/$subjectId';
  return '/rakuen/reviews/$subjectId?name=${Uri.encodeQueryComponent(n)}';
}

/// 条目评论/长评
/// 路由: /rakuen/reviews/:subjectId
class ReviewsScreen extends ConsumerStatefulWidget {
  final int subjectId;
  final String name;

  const ReviewsScreen({super.key, required this.subjectId, this.name = ''});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(reviewsProvider(widget.subjectId).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: reviewsTitle(widget.name),

        actions: [
          BgmHeaderMore.browser(
            () => openExternalUrl(htmlReviews(widget.subjectId)),
          ),
        ],
      ),

      body: Consumer(
        builder: (context, ref, _) {
          final async = ref.watch(reviewsProvider(widget.subjectId));
          return async.when(
            loading: () => const Loading(height: double.infinity),
            error: (e, _) => BgmRetry(
              onRetry: () => ref.invalidate(reviewsProvider(widget.subjectId)),
            ),
            data: (data) {
              if (data.reviews.isEmpty) {
                return const Center(child: Text('暂无评论'));
              }
              return ListView.separated(
                controller: _scrollController,
                itemCount: data.reviews.length + (data.hasMore ? 1 : 0),
                separatorBuilder: (_, _) => const BgmHairline(indent: 16),
                itemBuilder: (context, index) {
                  if (index >= data.reviews.length) {
                    return Center(
                      child: BgmTextAction(
                        '加载更多',
                        onPressed: () => ref
                            .read(reviewsProvider(widget.subjectId).notifier)
                            .loadMore(),
                      ),
                    );
                  }
                  return _ReviewRow(review: data.reviews[index]);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final Review review;

  const _ReviewRow({required this.review});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (review.id > 0) context.push('/rakuen/blog/${review.id}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(
              url: review.user?.avatarUrl ?? '',
              size: 34,
              name: review.user?.displayName,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (review.content.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      review.content,
                      style: context.ds.caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        review.user?.displayName ?? '',
                        style: context.ds.meta,
                      ),
                      const Spacer(),
                      if (review.replies > 0)
                        Text('${review.replies} 回复', style: context.ds.meta),
                      const SizedBox(width: 8),
                      Text(
                        friendlyTime(review.createdAt),
                        style: context.ds.tiny,
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
