import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';
import 'widgets/discovery_html.dart';

/// 年度动画大赏
///
/// 原项目抓取 https://bgm.tv/award/{year} 页面并在 WebView 中渲染,
/// 这里解析同一页面的排行块并原生渲染。
final awardProvider = FutureProvider.family<List<AwardBlock>, int>((ref, year) async {
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
  late int _year = widget.year;

  @override
  Widget build(BuildContext context) {
    final blocks = ref.watch(awardProvider(_year));
    return Scaffold(
      appBar: BgmAppBar(
        title: '$_year 年度动画大赏',
        showBackButton: true,
        actions: [
          PopupMenuButton<int>(
            tooltip: '选择年份',
            onSelected: (v) => setState(() => _year = v),
            itemBuilder: (context) => [
              for (final y in kYearbookYears)
                PopupMenuItem(value: y, child: Text('$y 年')),
            ],
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: blocks.when(
        loading: () => const Center(child: Loading()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('加载失败'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(awardProvider(_year)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(awardProvider(_year).future),
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
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
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
