import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';
import '../../shared/widgets/bgm_button.dart';

/// 评分月刊数据 (原项目公开 CDN 静态数据)
class VibMonth {
  final String title; // 202507
  final String desc;
  final List<VibBlock> blocks;

  const VibMonth({this.title = '', this.desc = '', this.blocks = const []});

  factory VibMonth.fromJson(Map<String, dynamic> json) => VibMonth(
    title: json['title'] as String? ?? '',
    desc: json['desc'] as String? ?? '',
    blocks:
        (json['data'] as List?)
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
    items:
        (json['data'] as List?)
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

  const VibItem({
    this.id = 0,
    this.title = '',
    this.rating = '',
    this.value1 = '',
    this.value2 = '',
  });

  factory VibItem.fromJson(Map<String, dynamic> json) => VibItem(
    id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
    title: json['title'] as String? ?? '',
    rating: json['rating']?.toString() ?? '',
    value1: json['value1']?.toString() ?? json['value']?.toString() ?? '',
    value2: json['value2']?.toString() ?? '',
  );
}

/// 原版 Title: `202507 (7月1日到7月31日)` → `202507 (7月1日至7月31日)`
String formatVibHeading(VibMonth month) {
  final title = month.title.trim();
  final desc = month.desc.trim().replaceAll('日到', '至');
  if (title.isEmpty) return desc;
  if (desc.isEmpty) return title;
  return '$title ($desc)';
}

const kVibGroupLabel = '小组讨论';

/// 评分月刊
final vibProvider = FutureProvider<List<VibMonth>>((ref) async {
  final client = ref.read(apiClientProvider);
  final data = await client.get(apiVibJson(), host: kDogeCdnHost);
  return (data as List)
      .whereType<Map<String, dynamic>>()
      .map(VibMonth.fromJson)
      .toList();
});

class VibScreen extends ConsumerStatefulWidget {
  const VibScreen({super.key});

  @override
  ConsumerState<VibScreen> createState() => _VibScreenState();
}

class _VibScreenState extends ConsumerState<VibScreen> {
  int _index = 0;

  void _select(int index) {
    if (index < 0) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final months = ref.watch(vibProvider);
    return Scaffold(
      appBar: BgmAppBar(
        title: 'VIB 数据月刊',
        showBackButton: true,
        actions: [
          months.maybeWhen(
            data: (list) => BgmHeaderMore(
              items: [
                (kVibGroupLabel, kVibGroupLabel),
                for (final month in list) (month.title, month.title),
              ],
              onSelected: (value) {
                if (value == kVibGroupLabel) {
                  context.push('/rakuen/group/qpz');
                  return;
                }
                final index = list.indexWhere((e) => e.title == value);
                _select(index);
              },
            ),
            orElse: () => BgmHeaderMore(
              items: const [(kVibGroupLabel, kVibGroupLabel)],
              onSelected: (_) => context.push('/rakuen/group/qpz'),
            ),
          ),
        ],
      ),
      body: months.when(
        loading: () => const Center(child: Loading()),
        error: (error, _) =>
            BgmRetry(onRetry: () => ref.invalidate(vibProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('暂无月刊'));
          }
          final index = _index.clamp(0, list.length - 1);
          final current = list[index];
          final older = index + 1 < list.length ? list[index + 1] : null;
          final newer = index > 0 ? list[index - 1] : null;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(vibProvider.future),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    formatVibHeading(current),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _MonthSection(month: current),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      if (older != null)
                        BgmTextAction(
                          older.title,
                          onPressed: () => _select(index + 1),
                        ),
                      const Spacer(),
                      if (newer != null)
                        BgmTextAction(
                          newer.title,
                          onPressed: () => _select(index - 1),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MonthSection extends StatelessWidget {
  final VibMonth month;

  const _MonthSection({required this.month});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in month.blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: block.title),
                for (final item in block.items)
                  BgmTextRow(
                    title: item.title,
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
                            item.value2.isEmpty
                                ? item.value1
                                : '${item.value1} / ${item.value2}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: item.id > 0
                        ? () => context.push('/subject/${item.id}')
                        : null,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
