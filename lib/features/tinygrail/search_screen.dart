import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'tinygrail_api.dart';
import 'tinygrail_models.dart';

/// 小圣杯搜索 (角色直达)
class TinygrailSearchScreen extends ConsumerStatefulWidget {
  const TinygrailSearchScreen({super.key});

  @override
  ConsumerState<TinygrailSearchScreen> createState() => _TinygrailSearchScreenState();
}

class _TinygrailSearchScreenState extends ConsumerState<TinygrailSearchScreen> {
  final _controller = TextEditingController();
  List<TinygrailSearchItem> _list = const [];
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) {
      setState(() => _list = const []);
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await ref.read(tinygrailApiProvider).search(kw);
      if (!mounted) return;
      setState(() => _list = result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _list = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入角色名或 ID'),
          onSubmitted: _search,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _search(_controller.text),
          ),
        ],
      ),
      body: _searching
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? const Center(child: Text('搜索角色, 支持名称或 ID'))
              : ListView.separated(
                  itemCount: _list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _list[index];
                    return ListTile(
                      leading: Text(
                        item.ico ? 'ICO' : 'Lv.${item.level}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      title: Text(item.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/tinygrail/chara/${item.id}'),
                    );
                  },
                ),
    );
  }
}
