import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/cache.dart';
import '../../shared/widgets/loading.dart';
import 'rakuen_providers.dart';
import 'widgets/topic_row.dart';

/// 超展开搜索 (帖子)
/// 路由: /rakuen/search
class RakuenSearchScreen extends ConsumerStatefulWidget {
  const RakuenSearchScreen({super.key});

  @override
  ConsumerState<RakuenSearchScreen> createState() => _RakuenSearchScreenState();
}

class _RakuenSearchScreenState extends ConsumerState<RakuenSearchScreen> {
  static const _boxName = 'rakuen';
  static const _historyKey = 'search_history';
  static const _maxHistory = 10;

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String _keyword = '';
  List<String> _history = const [];

  @override
  void initState() {
    super.initState();
    _history = _loadHistory();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(rakuenSearchProvider(_keyword).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _loadHistory() {
    final raw = Cache.instance.get(
      _boxName,
      _historyKey,
      maxAge: const Duration(days: 3650),
    );
    if (raw is List) return raw.whereType<String>().toList();
    return const [];
  }

  Future<void> _saveHistory(String keyword) async {
    final next = [
      keyword,
      ..._history.where((e) => e != keyword),
    ].take(_maxHistory).toList();
    _history = next;
    await Cache.instance.put(_boxName, _historyKey, next);
  }

  void _deleteHistory(String keyword) {
    final next = _history.where((e) => e != keyword).toList();
    setState(() => _history = next);
    Cache.instance.put(_boxName, _historyKey, next);
  }

  void _search(String keyword) {
    final kw = keyword.trim();
    if (kw.isEmpty) return;
    setState(() => _keyword = kw);
    _saveHistory(kw);
    ref.invalidate(rakuenSearchProvider(kw));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '搜索帖子',
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _search(_controller.text),
            ),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
        ),
      ),
      body: _keyword.isEmpty ? _buildHistory() : _buildResults(),
    );
  }

  Widget _buildHistory() {
    final theme = Theme.of(context);
    if (_history.isEmpty) {
      return const Center(child: Text('输入关键词搜索帖子'));
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Text(
            '搜索历史',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
          ),
        ),
        for (final keyword in _history)
          ListTile(
            dense: true,
            leading: const Icon(Icons.history, size: 18),
            title: Text(keyword, style: const TextStyle(fontSize: 14)),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => _deleteHistory(keyword),
            ),
            onTap: () {
              _controller.text = keyword;
              _search(keyword);
            },
          ),
      ],
    );
  }

  Widget _buildResults() {
    return Consumer(
      builder: (context, ref, _) {
        final async = ref.watch(rakuenSearchProvider(_keyword));
        return async.when(
          loading: () => const Loading(height: double.infinity),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('搜索失败, 请稍后重试'),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(rakuenSearchProvider(_keyword)),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
          data: (data) {
            if (data.items.isEmpty) {
              return const Center(child: Text('没有查询到结果'));
            }
            return ListView.separated(
              controller: _scrollController,
              itemCount: data.items.length + (data.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(indent: 56),
              itemBuilder: (context, index) {
                if (index >= data.items.length) {
                  return Center(
                    child: TextButton(
                      onPressed: () => ref
                          .read(rakuenSearchProvider(_keyword).notifier)
                          .loadMore(),
                      child: const Text('加载更多'),
                    ),
                  );
                }
                return RakuenTopicRow(topic: data.items[index]);
              },
            );
          },
        );
      },
    );
  }
}
