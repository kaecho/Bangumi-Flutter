import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';
import 'widgets/discovery_html.dart';

/// 词云: 基于收藏标签的词频统计
///
/// 原项目使用私有 KV 服务的 jieba 分词 (不可达), 这里以收藏条目的
/// 标签词频作为等价实现: 标签出现次数越多字号越大。
final wordCloudProvider = FutureProvider<List<(String, int)>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final userId = user.username.isEmpty ? '${user.id}' : user.username;
  final client = ref.read(apiClientProvider);

  // 想看/在看/看过 各取前几页 (与原项目一致: 每页 100)
  final counts = <String, int>{};
  for (final status in const [3, 2, 1]) {
    for (var page = 1; page <= 2; page++) {
      try {
        final data = await client.get(
          apiV0UsersCollections(userId, '2', 100, (page - 1) * 100, '$status'),
        );
        final items = parseV0Collections(data);
        if (items.isEmpty) break;
        for (final item in items) {
          for (final tag in item.subject.tags) {
            final name = tag.name.trim();
            if (name.isEmpty) continue;
            if (RegExp(r'^\d{4}年?$').hasMatch(name)) continue; // 年份过滤
            counts[name] = (counts[name] ?? 0) + 1;
          }
        }
      } catch (_) {
        break;
      }
    }
  }

  final list = counts.entries
      .map((e) => (e.key, e.value))
      .toList()
    ..sort((a, b) => b.$2.compareTo(a.$2));
  return list.take(80).toList();
});

/// 我的词云
class WordCloudScreen extends ConsumerWidget {
  const WordCloudScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(isLoggedInProvider);
    final words = ref.watch(wordCloudProvider);
    return Scaffold(
      appBar: BgmAppBar(title: '我的词云', showBackButton: true),
      body: !loggedIn
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('登录后查看收藏标签词云'),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => context.push('/login'),
                    child: const Text('去登录'),
                  ),
                ],
              ),
            )
          : words.when(
              loading: () => const Center(child: Loading()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('加载失败'),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(wordCloudProvider),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('收藏数据不足'))
                  : RefreshIndicator(
                      onRefresh: () => ref.refresh(wordCloudProvider.future),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '收藏条目标签词频 (${list.length} 个标签)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final (word, count) in list)
                                _WordChip(word: word, count: count, max: list.first.$2),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
    );
  }
}

class _WordChip extends StatelessWidget {
  final String word;
  final int count;
  final int max;

  const _WordChip({required this.word, required this.count, required this.max});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 字号 12~32 与词频成正比
    final fontSize = 12 + 20 * (count / max).clamp(0.1, 1.0);
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text('标签 "$word" 出现在 $count 个收藏条目中'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      ),
      child: Text(
        word,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: count >= max * 0.7 ? FontWeight.w700 : FontWeight.w400,
          color: theme.colorScheme.primary.withValues(alpha: 0.6 + 0.4 * count / max),
        ),
      ),
    );
  }
}
