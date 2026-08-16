import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_widgets.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';

/// 番市首富 (原项目 1-100 / 周股息 / 流动资产)
class TinygrailRichScreen extends ConsumerStatefulWidget {
  const TinygrailRichScreen({super.key});

  @override
  ConsumerState<TinygrailRichScreen> createState() =>
      _TinygrailRichScreenState();
}

class _TinygrailRichScreenState extends ConsumerState<TinygrailRichScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: '番市首富',
        actions: [
          BgmHeaderAction(
            icon: const Icon(Icons.insert_chart_outlined),
            tooltip: '富豪树',
            onPressed: () => context.push('/tinygrail/tree-rich'),
          ),
        ],
        bottom: BgmControlledTabStrip(
          controller: _tab,
          tabs: const [Text('1-100'), Text('周股息'), Text('流动资产')],
        ),
      ),

      body: TabBarView(
        controller: _tab,
        children: const [
          _RichList(extra: null),
          _RichList(extra: 0),
          _RichList(extra: 1),
        ],
      ),
    );
  }
}

class _RichList extends ConsumerWidget {
  final int? extra;

  const _RichList({required this.extra});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(richProvider(extra));
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (_, _) => const Center(child: Text('加载失败')),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(richProvider(extra)),
        child: list.isEmpty
            ? const Empty(text: '暂无数据')
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const BgmHairline(),
                itemBuilder: (context, index) {
                  final item = list[index];
                  return UserTile(
                    name: item.nickname.isEmpty ? item.userId : item.nickname,
                    avatar: item.avatar,
                    subtitle:
                        '现金 ${tgMoney(item.assets)} · 总资产 ${tgMoney(item.total)} · 周息 ${tgMoney(item.share)}',
                    value: extra == 0
                        ? tgMoney(item.share)
                        : extra == 1
                        ? tgMoney(item.assets)
                        : tgMoney(item.total),
                    rank: item.rank,
                  );
                },
              ),
      ),
    );
  }
}

final richProvider = FutureProvider.family<List<TinygrailRich>, int?>((
  ref,
  extra,
) async {
  return ref.read(tinygrailApiProvider).fetchRich(1, 100, extra: extra);
});
