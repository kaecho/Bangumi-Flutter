import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';
import 'widgets/discovery_html.dart';
import '../../shared/widgets/bgm_button.dart';

/// 原版 STATE.top 默认入库
const kWikiDefaultCate = 2;
const kWikiDefaultKind = 'latest_all';

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
  int _cate = kWikiDefaultCate;
  String _kind = kWikiDefaultKind;

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
        actions: [BgmHeaderMore.browser(() => openExternalUrl('$kHost/wiki'))],
      ),

      body: wiki.when(
        loading: () => const Center(child: Loading()),
        error: (error, _) =>
            BgmRetry(onRetry: () => ref.invalidate(wikiProvider)),
        data: (data) {
          final kinds = _kinds;
          final current = kinds.any((e) => e.$1 == _kind)
              ? _kind
              : kinds.first.$1;
          final entries = data.of(current);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: BgmSegmented<int>(
                  expand: true,
                  values: const [(0, '编辑'), (1, '关联'), (2, '入库')],
                  selected: _cate,
                  onSelect: (s) {
                    setState(() {
                      _cate = s;
                      _kind = _kinds.first.$1;
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: BgmSegmented<String>(
                  expand: true,
                  values: kinds,
                  selected: current,
                  onSelect: (s) => setState(() => _kind = s),
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
    return [
      for (final entry in entries)
        BgmTextRow(
          leading: const Icon(Icons.edit_note_outlined, size: 20),
          title: entry.name,
          subtitle: '${entry.username} · ${entry.time}',
          onTap: entry.href.isEmpty
              ? null
              : () => context.push(
                  '/web/${Uri.encodeComponent('https://bgm.tv${entry.href}')}',
                ),
        ),
    ];
  }
}
