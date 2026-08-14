import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';
import '../subject/subject_providers.dart';
import 'discovery_notes.dart';
import 'widgets/discovery_html.dart';

/// 词云: 基于收藏标签的词频统计
///
/// 原项目使用私有 KV 服务的 jieba 分词 (不可达), 这里以收藏条目的
/// 标签词频作为等价实现: 标签出现次数越多字号越大。
final wordCloudProvider = FutureProvider.family<List<(String, int)>, String>((
  ref,
  subjectType,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final userId = user.username.isEmpty ? '${user.id}' : user.username;
  final client = ref.read(apiClientProvider);

  final counts = <String, int>{};
  for (final status in const [3, 2, 1]) {
    for (var page = 1; page <= 2; page++) {
      try {
        final data = await client.get(
          apiV0UsersCollections(
            userId,
            subjectType,
            100,
            (page - 1) * 100,
            '$status',
          ),
        );
        final items = parseV0Collections(data);
        if (items.isEmpty) break;
        for (final item in items) {
          for (final tag in item.subject.tags) {
            final name = tag.name.trim();
            if (name.isEmpty) continue;
            if (RegExp(r'^\d{4}年?$').hasMatch(name)) continue;
            counts[name] = (counts[name] ?? 0) + 1;
          }
        }
      } catch (_) {
        break;
      }
    }
  }

  final list = counts.entries.map((e) => (e.key, e.value)).toList()
    ..sort((a, b) => b.$2.compareTo(a.$2));
  return list.take(80).toList();
});

/// 条目词云: 用该条目自身标签 (count 作为词频)
final subjectWordCloudProvider =
    FutureProvider.family<List<(String, int)>, int>((ref, id) async {
      final detail = await ref.watch(subjectDetailProvider(id).future);
      final list = [
        for (final tag in detail.tags)
          if (tag.name.trim().isNotEmpty) (tag.name.trim(), tag.count),
      ]..sort((a, b) => b.$2.compareTo(a.$2));
      return list.take(80).toList();
    });

/// 我的词云 / 条目词云
class WordCloudScreen extends ConsumerStatefulWidget {
  final int? subjectId;
  final String type;

  const WordCloudScreen({super.key, this.subjectId, this.type = ''});

  @override
  ConsumerState<WordCloudScreen> createState() => _WordCloudScreenState();
}

class _WordCloudScreenState extends ConsumerState<WordCloudScreen> {
  static const _types = [
    ('2', '动画'),
    ('1', '书籍'),
    ('4', '游戏'),
    ('3', '音乐'),
    ('6', '三次元'),
  ];
  late String _type = widget.type.isEmpty
      ? '2'
      : switch (widget.type) {
          'book' => '1',
          'music' => '3',
          'game' => '4',
          'real' => '6',
          _ => '2',
        };
  int _minCount = 1;

  bool get _isSubject => (widget.subjectId ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(isLoggedInProvider);
    final words = _isSubject
        ? ref.watch(subjectWordCloudProvider(widget.subjectId!))
        : ref.watch(wordCloudProvider(_type));
    return Scaffold(
      appBar: BgmAppBar(
        title: _isSubject ? '条目词云' : '我的词云',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: '说明',
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push(wordCloudNotePath()),
          ),
        ],
      ),

      body: !_isSubject && !loggedIn
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
          : Column(
              children: [
                if (!_isSubject)
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final (value, label) in _types)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: _type == value,
                              onSelected: (_) => setState(() => _type = value),
                            ),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        '最小词频 $_minCount',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Expanded(
                        child: Slider(
                          value: _minCount.toDouble(),
                          min: 1,
                          max: 8,
                          divisions: 7,
                          label: '$_minCount',
                          onChanged: (v) =>
                              setState(() => _minCount = v.round()),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: words.when(
                    loading: () => const Center(child: Loading()),
                    error: (error, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('加载失败'),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: () {
                              if (_isSubject) {
                                ref.invalidate(
                                  subjectWordCloudProvider(widget.subjectId!),
                                );
                              } else {
                                ref.invalidate(wordCloudProvider(_type));
                              }
                            },
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                    data: (list) {
                      final filtered = list
                          .where((e) => e.$2 >= _minCount)
                          .toList();
                      if (list.isEmpty) {
                        return const Center(child: Text('暂无标签'));
                      }
                      if (filtered.isEmpty) {
                        return const Center(child: Text('没有达到最小词频的标签'));
                      }
                      return RefreshIndicator(
                        onRefresh: () async {
                          if (_isSubject) {
                            ref.invalidate(
                              subjectWordCloudProvider(widget.subjectId!),
                            );
                            await ref.read(
                              subjectWordCloudProvider(
                                widget.subjectId!,
                              ).future,
                            );
                          } else {
                            ref.invalidate(wordCloudProvider(_type));
                            await ref.read(wordCloudProvider(_type).future);
                          }
                        },
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                '${_isSubject ? '条目标签' : '收藏条目标签词频'} (${filtered.length} 个标签)',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                for (final (word, count) in filtered)
                                  _WordChip(
                                    word: word,
                                    count: count,
                                    max: filtered.first.$2,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
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
    final fontSize = 12 + 20 * (count / max).clamp(0.1, 1.0);
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text('标签 "$word" 出现 $count 次'),
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
          color: theme.colorScheme.primary.withValues(
            alpha: 0.6 + 0.4 * count / max,
          ),
        ),
      ),
    );
  }
}
