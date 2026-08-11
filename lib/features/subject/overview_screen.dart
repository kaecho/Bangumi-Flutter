import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/ep.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';
import 'subject_providers.dart';

/// 条目概览 (书籍/音乐: 卷/碟 分组章节)
/// 路由: /subject/:id/overview
class OverviewScreen extends ConsumerWidget {
  final int id;

  const OverviewScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(subjectDetailProvider(id));
    final eps = ref.watch(epListProvider(id)).valueOrNull;
    return Scaffold(
      appBar: BgmAppBar(title: '概览', showBackButton: true),
      body: detail.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 8),
              const Text('加载失败'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(subjectDetailProvider(id)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (value) {
          if (eps == null || eps.total == 0) {
            return const Empty(text: '暂无章节信息');
          }
          // 按 disc 分组 (书籍卷 / 音乐碟)
          final groups = <int, List<Ep>>{};
          for (final ep in [...eps.eps, ...eps.type1, ...eps.type2, ...eps.type3, ...eps.type4, ...eps.type6]) {
            groups.putIfAbsent(ep.disc, () => []).add(ep);
          }
          final sorted = groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                value.subject.displayName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '共 ${eps.total} 章节${value.subject.volums > 0 ? ' · ${value.subject.volums} 卷' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              for (final entry in sorted)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        entry.key > 0 ? 'Disc ${entry.key}' : '本篇',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    for (final ep in entry.value)
                      InkWell(
                        onTap: () => context.push('/subject/$id/ep/${ep.id}/comments'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 30,
                                child: Text(
                                  '${ep.sort}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  ep.displayName.isEmpty ? '第 ${ep.sort} 话' : ep.displayName,
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (ep.duration.isNotEmpty)
                                Text(
                                  ep.duration,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
