import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';

import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'tinygrail_widgets.dart';

/// 关联角色 (批量角色列表, Extra HeaderV2 title=params.name||关联角色)
class TinygrailRelationScreen extends StatefulWidget {
  final List<int> ids;
  final String name;

  const TinygrailRelationScreen({
    super.key,
    required this.ids,
    this.name = '',
  });

  @override
  State<TinygrailRelationScreen> createState() => _TinygrailRelationScreenState();
}

class _TinygrailRelationScreenState extends State<TinygrailRelationScreen> {
  String _go = '买入';

  @override
  Widget build(BuildContext context) {
    return _RelationBody(
      ids: widget.ids,
      title: widget.name.isEmpty ? '关联角色' : widget.name,
      go: _go,
      onGo: (v) => setState(() => _go = v),
    );
  }
}

class _RelationBody extends ConsumerWidget {
  final List<int> ids;
  final String title;
  final String go;
  final ValueChanged<String> onGo;

  const _RelationBody({
    required this.ids,
    required this.title,
    required this.go,
    required this.onGo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(relationProvider(ids));
    return Scaffold(
      appBar: BgmAppBar(
        title: title,
        actions: [
          TinygrailIconGo(value: go, onChanged: onGo),
        ],
      ),
      body: async.when(
        loading: () => const Loading(height: double.infinity),
        error: (_, _) => const Center(child: Text('加载失败')),
        data: (list) => list.isEmpty
            ? const Empty(text: '暂无角色')
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const BgmHairline(),
                itemBuilder: (context, index) => CharaTile(
                  chara: list[index],
                  onTap: () => context.push(
                    tinygrailIconGoPath(list[index].id, go),
                  ),
                ),
              ),
      ),
    );
  }
}

final relationProvider = FutureProvider.family<List<TinygrailChara>, List<int>>(
  (ref, ids) async {
    return ref.read(tinygrailApiProvider).fetchCharaByIds(ids);
  },
);
