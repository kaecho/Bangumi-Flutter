import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';

import 'tinygrail_api.dart';
import 'tinygrail_models.dart';

/// 小圣杯搜索 (角色直达)
class TinygrailSearchScreen extends ConsumerStatefulWidget {
  const TinygrailSearchScreen({super.key});

  @override
  ConsumerState<TinygrailSearchScreen> createState() =>
      _TinygrailSearchScreenState();
}

class _TinygrailSearchScreenState extends ConsumerState<TinygrailSearchScreen> {
  final _controller = TextEditingController();
  List<TinygrailSearchItem> _list = const [];
  final List<TinygrailSearchItem> _history = [];
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
      setState(() {
        _list = result;
        for (final item in result) {
          _history.removeWhere((e) => e.id == item.id);
          _history.insert(0, item);
        }
        if (_history.length > 20) {
          _history.removeRange(20, _history.length);
        }
      });
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
      appBar: const BgmAppBar(title: '人物直达'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: BgmField(
                    controller: _controller,
                    autofocus: true,
                    hintText: '输入角色名字或ID',
                    textInputAction: TextInputAction.search,
                    onSubmitted: _search,
                  ),
                ),
                const SizedBox(width: 8),
                BgmButton(
                  '查询',
                  expand: false,
                  loading: _searching,
                  onPressed: _searching
                      ? null
                      : () => _search(_controller.text),
                ),
              ],
            ),
          ),
          Expanded(
            child: _searching
                ? const Loading()
                : _list.isNotEmpty
                ? ListView.separated(
                    itemCount: _list.length,
                    separatorBuilder: (_, _) => const BgmHairline(),
                    itemBuilder: (context, index) {
                      final item = _list[index];
                      return BgmTextRow(
                        leading: Text(
                          item.ico ? 'ICO' : 'Lv.${item.level}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        title: item.name,
                        onTap: () =>
                            context.push('/tinygrail/chara/${item.id}'),
                      );
                    },
                  )
                : _history.isEmpty
                ? const Center(child: Text('搜索角色, 支持名称或 ID'))
                : ListView.separated(
                    itemCount: _history.length,
                    separatorBuilder: (_, _) => const BgmHairline(),
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      return BgmTextRow(
                        title: item.name.isEmpty
                            ? '#${item.id}'
                            : '${item.name} #${item.id}',
                        onTap: () =>
                            context.push('/tinygrail/chara/${item.id}'),
                        trailing: BgmHeaderAction(
                          tooltip: '删除',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setState(() => _history.removeAt(index)),
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
