import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/html/bgm_html_parser.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../design_system/design_system.dart';

/// 超展开板块 (移植自原项目 MODEL_RAKUEN_SCOPE)
const kRakuenScopes = [
  ('全局聚合', 'topiclist'),
  ('新番乐园', 'new_bangumi'),
  ('etokei 绘时计', 'tokei'),
  ('经典动画', 'classical_bangumi'),
  ('天窗联盟', 'doujin'),
  ('1/8位面', 'pvc'),
];

/// 全局聚合类型 (MODEL_RAKUEN_TYPE)
const kRakuenTypes = [
  ('全部', ''),
  ('小组', 'group'),
  ('条目', 'subject'),
  ('热门', 'hot'),
  ('章节', 'ep'),
  ('人物', 'mono'),
];

/// 帖子列表数据
class RakuenData {
  final List<RakuenTopicItem> topics;
  final int page;
  final bool hasMore;

  const RakuenData({this.topics = const [], this.page = 1, this.hasMore = true});
}

/// 超展开帖子 (HTML 解析结果)
class RakuenTopicItem {
  final String title;
  final String userName;
  final String userId;
  final String topicId; // 如 group/350677
  final String group;
  final String groupHref;
  final int replies;
  final String time;

  const RakuenTopicItem({
    this.title = '',
    this.userName = '',
    this.userId = '',
    this.topicId = '',
    this.group = '',
    this.groupHref = '',
    this.replies = 0,
    this.time = '',
  });
}

final rakuenProvider = AsyncNotifierProvider.family<RakuenNotifier, RakuenData, String>(
  RakuenNotifier.new,
);

class RakuenNotifier extends FamilyAsyncNotifier<RakuenData, String> {
  @override
  Future<RakuenData> build(String key) async {
    return _fetch(1, key);
  }

  Future<RakuenData> _fetch(int page, String key) async {
    // key 格式: '{type}|{scope}', 与原项目 fetchRakuen(scope, type) 一致
    final type = key.split('|').first;
    final scope = key.split('|').last;
    final client = ref.read(apiClientProvider);
    final html = await client.fetchHtml(rakueHtmlUrl(scope, type));
    final items = parseRakuenList(html);
    return RakuenData(
      topics: [
        for (final item in items)
          RakuenTopicItem(
            title: item.title,
            userName: item.userName,
            userId: item.userId,
            topicId: item.topicId,
            group: item.group,
            groupHref: item.groupHref,
            replies: item.replyCount ?? 0,
            time: item.time,
          ),
      ],
      page: page,
      hasMore: items.length >= 30,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(current.page + 1, arg);
      state = AsyncData(RakuenData(
        topics: [...current.topics, ...next.topics],
        page: next.page,
        hasMore: next.hasMore,
      ));
    } catch (_) {}
  }
}

/// 超展开 Tab (Tab 4)
class RakuenScreen extends ConsumerStatefulWidget {
  const RakuenScreen({super.key});

  @override
  ConsumerState<RakuenScreen> createState() => _RakuenScreenState();
}

class _RakuenScreenState extends ConsumerState<RakuenScreen> {
  int _scopeIndex = 0;
  int _typeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final scope = kRakuenScopes[_scopeIndex];
    final type = kRakuenTypes[_typeIndex];
    final key = '${type.$2}|${scope.$2}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('超展开'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () => context.push('/rakuen/search'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: '电波提醒',
            onPressed: () => context.push('/rakuen/notify'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => context.push('/rakuen/setting'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Column(
            children: [
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: kRakuenScopes.length,
                  itemBuilder: (context, index) {
                    final s = kRakuenScopes[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(s.$1, style: const TextStyle(fontSize: 12)),
                        selected: index == _scopeIndex,
                        onSelected: (_) => setState(() => _scopeIndex = index),
                      ),
                    );
                  },
                ),
              ),
              if (_scopeIndex == 0)
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: kRakuenTypes.length,
                    itemBuilder: (context, index) {
                      final t = kRakuenTypes[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(t.$1, style: const TextStyle(fontSize: 12)),
                          selected: index == _typeIndex,
                          onSelected: (_) => setState(() => _typeIndex = index),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      body: _RakuenTopicList(listKey: key),
    );
  }
}

class _RakuenTopicList extends ConsumerStatefulWidget {
  final String listKey;

  const _RakuenTopicList({required this.listKey});

  @override
  ConsumerState<_RakuenTopicList> createState() => _RakuenTopicListState();
}

class _RakuenTopicListState extends ConsumerState<_RakuenTopicList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(rakuenProvider(widget.listKey).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rakuenProvider(widget.listKey));
    return async.when(
      loading: () => const Loading(),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('加载失败'),
            TextButton(
              onPressed: () => ref.invalidate(rakuenProvider(widget.listKey)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (data) {
        if (data.topics.isEmpty) {
          return const Center(child: Text('暂无帖子'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(rakuenProvider(widget.listKey)),
          child: ListView.separated(
            controller: _scrollController,
            itemCount: data.topics.length,
            separatorBuilder: (_, _) => const Divider(indent: 56),
            itemBuilder: (context, index) {
              final topic = data.topics[index];
              return _TopicRow(topic: topic);
            },
          ),
        );
      },
    );
  }
}

class _TopicRow extends StatelessWidget {
  final RakuenTopicItem topic;

  const _TopicRow({required this.topic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => context.push('/rakuen/topic/${topic.topicId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(url: '', size: 34, name: topic.userName),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (topic.group.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            topic.group,
                            style: TextStyle(fontSize: 10, color: theme.colorScheme.primary),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          topic.userName,
                          style: context.ds.meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        topic.time,
                        style: context.ds.tiny,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (topic.replies > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '${topic.replies}',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
