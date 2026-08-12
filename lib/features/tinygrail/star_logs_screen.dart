import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/format.dart';
import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import '../../design_system/design_system.dart';

/// 圣星记录
class TinygrailStarLogsScreen extends ConsumerStatefulWidget {
  const TinygrailStarLogsScreen({super.key});

  @override
  ConsumerState<TinygrailStarLogsScreen> createState() => _TinygrailStarLogsScreenState();
}

class _TinygrailStarLogsScreenState extends ConsumerState<TinygrailStarLogsScreen> {
  int _page = 1;
  final List<TinygrailStarLog> _list = [];
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(tinygrailApiProvider);
      final next = await api.fetchStarLogs(_page, 200);
      setState(() {
        _list.addAll(next);
        _page++;
        _hasMore = next.isNotEmpty;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('圣星记录')),
      body: _list.isEmpty
          ? (_loading ? const Loading() : const Empty(text: '暂无记录'))
          : RefreshIndicator(
              onRefresh: () async {
                _page = 1;
                _list.clear();
                await _load();
              },
              child: ListView.builder(
                itemCount: _list.length,
                itemBuilder: (context, index) {
                  if (index >= _list.length - 3 && _hasMore) _load();
                  final item = _list[index];
                  return ListTile(
                    onTap: () => context.push('/tinygrail/chara/${item.monoId}'),
                    leading: Text('#${item.rank}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${item.userName} · 星之力 +${item.amount} · ${friendlyTime(item.time)}',
                      style: context.ds.meta,
                    ),
                  );
                },
              ),
            ),
    );
  }
}
