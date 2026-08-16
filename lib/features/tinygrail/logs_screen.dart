import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../core/utils/format.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import '../../design_system/design_system.dart';
import 'tinygrail_widgets.dart';


/// 资金日志 (原项目 tabs: 全部 / 刮刮乐 / ICO / 卖出 …)
class TinygrailLogsScreen extends ConsumerStatefulWidget {
  const TinygrailLogsScreen({super.key});

  @override
  ConsumerState<TinygrailLogsScreen> createState() =>
      _TinygrailLogsScreenState();
}

class _TinygrailLogsScreenState extends ConsumerState<TinygrailLogsScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    ('全部', ''),
    ('道具', '道具'),
    ('刮刮乐', '刮刮'),
    ('ICO', 'ICO'),
    ('卖出', '卖出'),
    ('买入', '买入'),
    ('竞拍', '竞拍'),
    ('圣殿', '圣殿'),
    ('分红', '分红'),
  ];

  late final TabController _tab = TabController(
    length: _tabs.length,
    vsync: this,
  );
  int _page = 1;
  final List<TinygrailBalance> _list = [];
  bool _loading = false;
  bool _hasMore = true;
  String _go = '卖出';


  @override
  void initState() {
    super.initState();
    _tab.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final next = await ref.read(tinygrailApiProvider).fetchBalance(_page);
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

  List<TinygrailBalance> _filtered() {
    final key = _tabs[_tab.index].$2;
    if (key.isEmpty) return _list;
    return _list.where((e) => e.desc.contains(key)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
    return Scaffold(
      appBar: BgmAppBar(
        title: '资金日志',
        actions: [
          TinygrailIconGo(
            value: _go,
            onChanged: (v) => setState(() => _go = v),
          ),
        ],
        bottom: BgmControlledTabStrip(
          controller: _tab,
          scrollable: true,
          tabs: [for (final t in _tabs) Tab(text: t.$1)],
        ),
      ),
      body: _list.isEmpty
          ? (_loading ? const Loading() : const Empty(text: '暂无记录'))
          : RefreshIndicator(
              onRefresh: () async {
                _page = 1;
                _list.clear();
                await _load();
              },
              child: filtered.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('该分类暂无记录')),
                      ],
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        if (index >= filtered.length - 3 && _hasMore) _load();
                        final item = filtered[index];
                        final change = item.change;
                        return BgmTextRow(
                          onTap: item.charaId > 0
                              ? () => context.push(
                                  tinygrailIconGoPath(item.charaId, _go),
                                )
                              : null,
                          leading: Icon(
                            change > 0
                                ? Icons.add_circle_outline
                                : Icons.remove_circle_outline,
                            color: change > 0
                                ? context.ds.rise
                                : context.ds.fall,
                          ),
                          title: item.desc,
                          subtitle: friendlyTime(item.time),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${change > 0 ? '+' : ''}${tgMoney(change)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: change > 0
                                      ? context.ds.rise
                                      : context.ds.fall,
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
