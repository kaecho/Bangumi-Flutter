import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';
import 'widgets/discovery_html.dart';
import '../../design_system/design_system.dart';

/// 维基人列表
///
/// 旧版 /wiki/top JSON API 已下线, 解析主站维基人页面
/// (https://bgm.tv/wiki)。
final wikiProvider = FutureProvider<WikiData>((ref) async {
  final client = ref.read(apiClientProvider);
  final body = await client.get(htmlWiki(), host: kHost);
  return parseWiki(body as String);
});

class WikiScreen extends ConsumerWidget {
  const WikiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wiki = ref.watch(wikiProvider);
    return Scaffold(
      appBar: BgmAppBar(title: '维基人', showBackButton: true),
      body: wiki.when(
        loading: () => const Center(child: Loading()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('加载失败'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(wikiProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(wikiProvider.future),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (label, count) in data.counts)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$label $count',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              const SectionHeader(title: '条目编辑动态'),
              ..._buildEntries(context, data.all),
              const SectionHeader(title: '锁定条目动态'),
              ..._buildEntries(context, data.lock),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEntries(BuildContext context, List<WikiEntry> entries) {
    final theme = Theme.of(context);
    return [
      for (final entry in entries)
        ListTile(
          dense: true,
          leading: const Icon(Icons.edit_note_outlined, size: 20),
          title: Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
          ),
          subtitle: Text(
            '${entry.username} · ${entry.time}',
            style: context.ds.meta,
          ),
          onTap: entry.href.isEmpty
              ? null
              : () => context.push(
                    '/web/${Uri.encodeComponent('https://bgm.tv${entry.href}')}',
                  ),
        ),
    ];
  }
}
