import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import '../../design_system/design_system.dart';

/// 资金日志 (交易记录)
class TinygrailLogsScreen extends ConsumerStatefulWidget {
  const TinygrailLogsScreen({super.key});

  @override
  ConsumerState<TinygrailLogsScreen> createState() => _TinygrailLogsScreenState();
}

class _TinygrailLogsScreenState extends ConsumerState<TinygrailLogsScreen> {
  int _page = 1;
  final List<TinygrailBalance> _list = [];
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
      final next = await api.fetchBalance(_page);
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
      appBar: AppBar(title: const Text('资金日志')),
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
                  final change = item.change;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      change > 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
                      color: change > 0 ? context.ds.rise : context.ds.fall,
                    ),
                    title: Text(item.desc, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      friendlyTime(item.time),
                      style: context.ds.meta,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${change > 0 ? '+' : ''}${tgMoney(change)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: change > 0 ? context.ds.rise : context.ds.fall,
                          ),
                        ),
                        Text(
                          '余额 ${tgMoney(item.balance)}',
                          style: context.ds.meta,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
