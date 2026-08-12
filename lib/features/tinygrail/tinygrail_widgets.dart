import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import '../../design_system/design_system.dart';

/// 角色行: 头像 + 名称/等级 + 现价 + 涨跌幅
class CharaTile extends StatelessWidget {
  final TinygrailChara chara;
  final Widget? trailing;
  final VoidCallback? onTap;

  const CharaTile({super.key, required this.chara, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = chara.fluctuation < 0
        ? context.ds.fall
        : chara.fluctuation > 0
            ? context.ds.rise
            : theme.colorScheme.onSurfaceVariant;
    final icon = chara.icon.replaceFirst('//', 'https://');
    return ListTile(
      onTap: onTap,
      leading: Cover(
        url: icon,
        width: 40,
        height: 40,
        radius: 6,
        placeholder: Container(
          width: 40,
          height: 40,
          color: theme.colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Text(
            chara.name.isEmpty ? '?' : chara.name.characters.first,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(chara.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          Text('Lv.${chara.level}', style: TextStyle(fontSize: 11, color: theme.colorScheme.primary)),
        ],
      ),
      subtitle: Text(
        '发行 ${tgAmount(chara.total)} · 市场 ${tgAmount(chara.marketValue)}',
        style: context.ds.meta,
      ),
      trailing: trailing ??
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('¥${tgPrice(chara.current)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                tgFluctuation(chara.fluctuation),
                style: TextStyle(fontSize: 11, color: color),
              ),
            ],
          ),
    );
  }
}

/// 通用角色列表页: 支持多 tab (type 列表)
class TinygrailCharaListScreen extends ConsumerStatefulWidget {
  final String title;
  final List<(String, String)> tabs; // (tab 名, list type)
  final Future<List<TinygrailChara>> Function(String type)? loader;
  final Widget Function(TinygrailChara)? itemBuilder;

  const TinygrailCharaListScreen({
    super.key,
    required this.title,
    required this.tabs,
    this.loader,
    this.itemBuilder,
  });

  @override
  ConsumerState<TinygrailCharaListScreen> createState() => _TinygrailCharaListScreenState();
}

class _TinygrailCharaListScreenState extends ConsumerState<TinygrailCharaListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: widget.tabs.length, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<List<TinygrailChara>> _load(String type) {
    final loader = widget.loader;
    if (loader != null) return loader(type);
    final api = ref.read(tinygrailApiProvider);
    return api.fetchList(type);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: widget.tabs.length > 1
            ? TabBar(
                controller: _tab,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final t in widget.tabs) Tab(text: t.$1)],
              )
            : null,
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          for (final t in widget.tabs) _CharaList(loader: () => _load(t.$2)),
        ],
      ),
    );
  }
}

class _CharaList extends ConsumerStatefulWidget {
  final Future<List<TinygrailChara>> Function() loader;

  const _CharaList({required this.loader});

  @override
  ConsumerState<_CharaList> createState() => _CharaListState();
}

class _CharaListState extends ConsumerState<_CharaList> {
  late Future<List<TinygrailChara>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  @override
  void didUpdateWidget(covariant _CharaList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loader != widget.loader) {
      _future = widget.loader();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Loading(height: double.infinity);
        }
        final list = snapshot.data ?? const <TinygrailChara>[];
        if (snapshot.hasError || list.isEmpty) {
          return Empty(text: snapshot.hasError ? '加载失败, 请重试' : '暂无数据');
        }
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _future = widget.loader());
            await _future;
          },
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final chara = list[index];
              return CharaTile(
                chara: chara,
                onTap: () => context.push('/tinygrail/chara/${chara.id}'),
              );
            },
          ),
        );
      },
    );
  }
}

/// 通用用户列表行 (富豪榜 / 董事会)
class UserTile extends StatelessWidget {
  final String name;
  final String avatar;
  final String subtitle;
  final String value;
  final int rank;
  final VoidCallback? onTap;

  const UserTile({
    super.key,
    required this.name,
    required this.avatar,
    required this.subtitle,
    required this.value,
    this.rank = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: rank > 0
          ? SizedBox(
              width: 40,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: rank <= 3 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Avatar(url: avatar.replaceFirst('//', 'https://'), size: 40, name: name),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, style: context.ds.meta),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
