import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';

/// 评分月刊数据 (原项目公开 CDN 静态数据)
class VibMonth {
  final String title; // 202507
  final String desc;
  final List<VibBlock> blocks;

  const VibMonth({this.title = '', this.desc = '', this.blocks = const []});

  factory VibMonth.fromJson(Map<String, dynamic> json) => VibMonth(
        title: json['title'] as String? ?? '',
        desc: json['desc'] as String? ?? '',
        blocks: (json['data'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(VibBlock.fromJson)
                .toList() ??
            const [],
      );
}

class VibBlock {
  final String title;
  final List<VibItem> items;

  const VibBlock({this.title = '', this.items = const []});

  factory VibBlock.fromJson(Map<String, dynamic> json) => VibBlock(
        title: json['title'] as String? ?? '',
        items: (json['data'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(VibItem.fromJson)
                .toList() ??
            const [],
      );
}

class VibItem {
  final int id;
  final String title;
  final String rating;
  final String value1;
  final String value2;

  const VibItem({this.id = 0, this.title = '', this.rating = '', this.value1 = '', this.value2 = ''});

  factory VibItem.fromJson(Map<String, dynamic> json) => VibItem(
        id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
        title: json['title'] as String? ?? '',
        rating: json['rating']?.toString() ?? '',
        value1: json['value1']?.toString() ?? json['value']?.toString() ?? '',
        value2: json['value2']?.toString() ?? '',
      );
}

/// 评分月刊
final vibProvider = FutureProvider<List<VibMonth>>((ref) async {
  final client = ref.read(apiClientProvider);
  final data = await client.get(apiVibJson(), host: kDogeCdnHost);
  return (data as List)
      .whereType<Map<String, dynamic>>()
      .map(VibMonth.fromJson)
      .toList();
});

class VibScreen extends ConsumerWidget {
  const VibScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = ref.watch(vibProvider);
    return Scaffold(
      appBar: BgmAppBar(title: '评分月刊', showBackButton: true),
      body: months.when(
        loading: () => const Center(child: Loading()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('加载失败'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(vibProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(vibProvider.future),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final month in list)
                _MonthSection(month: month),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthSection extends StatelessWidget {
  final VibMonth month;

  const _MonthSection({required this.month});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: false,
      title: Text(
        '${month.title} 月刊',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: month.desc.isEmpty ? null : Text(month.desc, style: const TextStyle(fontSize: 11)),
      children: [
        for (final block in month.blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: block.title),
                for (final item in block.items)
                  ListTile(
                    dense: true,
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.rating.isNotEmpty)
                          Text(
                            '${item.rating}分',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        if (item.value1.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            item.value2.isEmpty ? item.value1 : '${item.value1} / ${item.value2}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: item.id > 0 ? () => context.push('/subject/${item.id}') : null,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
