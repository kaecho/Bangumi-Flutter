import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';
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

class WikiScreen extends ConsumerStatefulWidget {
  const WikiScreen({super.key});

  @override
  ConsumerState<WikiScreen> createState() => _WikiScreenState();
}

class _WikiScreenState extends ConsumerState<WikiScreen> {
  int _cate = 0; // 0=编辑 1=关联 2=入库
  String _kind = 'wiki_act-all';

  static const _editKinds = <(String id, String label)>[
    ('wiki_act-all', '条目'),
    ('wiki_act-lock', '锁定'),
    ('wiki_act-merge', '合并'),
    ('wiki_act-ep', '章节'),
    ('wiki_act-crt', '角色'),
    ('wiki_act-prsn', '人物'),
  ];
  static const _relationKinds = <(String id, String label)>[
    ('wiki_act-subject-relation', '条目关联'),
    ('wiki_act-subject-person', '条目-人物'),
    ('wiki_act-subject-crt', '条目-角色'),
  ];
  static const _lastKinds = <(String id, String label)>[
    ('latest_all', '全部'),
    ('latest_2', '动画'),
    ('latest_1', '书籍'),
    ('latest_3', '音乐'),
    ('latest_4', '游戏'),
    ('latest_6', '三次元'),
  ];

  List<(String, String)> get _kinds => switch (_cate) {
    1 => _relationKinds,
    2 => _lastKinds,
    _ => _editKinds,
  };

  @override
  Widget build(BuildContext context) {
    final wiki = ref.watch(wikiProvider);
    return Scaffold(
      appBar: BgmAppBar(
        title: '维基人',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: '浏览器查看',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => openExternalUrl('$kHost/wiki'),
          ),
        ],
      ),

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
        data: (data) {
          final kinds = _kinds;
          final current = kinds.any((e) => e.$1 == _kind)
              ? _kind
              : kinds.first.$1;
          final entries = data.of(current);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('编辑')),
                    ButtonSegment(value: 1, label: Text('关联')),
                    ButtonSegment(value: 2, label: Text('入库')),
                  ],
                  selected: {_cate},
                  onSelectionChanged: (s) {
                    setState(() {
                      _cate = s.first;
                      _kind = _kinds.first.$1;
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: [
                      for (final (id, label) in kinds)
                        ButtonSegment(value: id, label: Text(label)),
                    ],
                    selected: {current},
                    onSelectionChanged: (s) => setState(() => _kind = s.first),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.refresh(wikiProvider.future),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24, top: 8),
                    children: [
                      if (data.counts.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final (label, count) in data.counts)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
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
                      if (entries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('该分类暂无数据')),
                        )
                      else
                        ..._buildEntries(context, entries),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
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
