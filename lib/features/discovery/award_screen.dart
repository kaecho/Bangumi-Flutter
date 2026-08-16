import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';

import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';
import 'widgets/discovery_html.dart';
import '../../shared/widgets/bgm_button.dart';

/// 年度动画大赏
///
/// 原项目抓取 https://bgm.tv/award/{year} 页面并在 WebView 中渲染,
/// 这里解析同一页面的排行块并原生渲染。
final awardProvider = FutureProvider.family<List<AwardBlock>, int>((
  ref,
  year,
) async {
  final client = ref.read(apiClientProvider);
  final body = await client.get(htmlAward(year), host: kHost);
  return parseAward(body as String);
});

class AwardScreen extends ConsumerStatefulWidget {
  final int year;

  const AwardScreen({super.key, required this.year});

  @override
  ConsumerState<AwardScreen> createState() => _AwardScreenState();
}

class _AwardScreenState extends ConsumerState<AwardScreen> {
  @override
  Widget build(BuildContext context) {
    final year = widget.year;
    final blocks = ref.watch(awardProvider(year));
    return Scaffold(
      body: blocks.when(
        loading: () => _AwardLoading(year: year),
        error: (error, _) =>
            BgmRetry(onRetry: () => ref.invalidate(awardProvider(year))),

        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(awardProvider(year).future),

          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final block in list) ...[
                SectionHeader(
                  title: block.title,
                  trailing: block.subtitle.isEmpty
                      ? null
                      : Text(
                          block.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                ),
                _AwardBlockList(items: block.items),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AwardLoading extends StatelessWidget {
  final int year;
  const _AwardLoading({required this.year});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Loading(),
          const SizedBox(height: 12),
          Text('网页加载中, 请稍等', style: ds.caption),
          const SizedBox(height: 8),
          BgmTextAction(
            '或点这里使用浏览器打开',
            color: ds.textSecondary,
            onPressed: () => openExternalUrl('$kHost${htmlAward(year)}'),
          ),
        ],
      ),
    );
  }
}

class _AwardBlockList extends StatelessWidget {
  final List<AwardItem> items;

  const _AwardBlockList({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () {
              final idMatch = RegExp(r'/(\d+)$').firstMatch(item.href);
              if (idMatch == null) return;
              if (item.href.startsWith('/subject/')) {
                context.push('/subject/${idMatch.group(1)}');
              } else {
                context.push(
                  '/web/${Uri.encodeComponent('https://bgm.tv${item.href}')}',
                );
              }
            },
            child: SizedBox(
              width: 104,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Cover(url: item.cover, width: 104, height: 139, radius: 6),
                  const SizedBox(height: 4),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item.subName.isNotEmpty)
                    Text(
                      item.subName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (item.count.isNotEmpty)
                    Text(
                      item.count,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
