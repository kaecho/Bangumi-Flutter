import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'tinygrail_api.dart';
import 'tinygrail_models.dart';
import 'treemap.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';

/// 富豪树 (前百首富) — 移植自原项目 screens/tinygrail/tree-rich
///
/// 番市首富前 100 名的资产矩形树图, 点击用户跳转其资产分析。
class TinygrailTreeRichScreen extends ConsumerStatefulWidget {
  const TinygrailTreeRichScreen({super.key});

  @override
  ConsumerState<TinygrailTreeRichScreen> createState() =>
      _TinygrailTreeRichScreenState();
}

const kTreeRichTypes = ['周股息', '总资产', '流动资金', '初始资金'];

/// 富豪树数据 (前 100 名)
final treeRichProvider = FutureProvider<List<TinygrailRich>>((ref) async {
  return ref.read(tinygrailApiProvider).fetchRich(1, 100);
});

class _TinygrailTreeRichScreenState
    extends ConsumerState<TinygrailTreeRichScreen> {
  String _type = '周股息';
  final Set<int> _hidden = {};

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(treeRichProvider);
    return Scaffold(
      appBar: BgmAppBar(
        title: '前百首富',
        actions: [
          BgmHeaderAction(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => ref.invalidate(treeRichProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          _ToolBar(
            type: _type,
            onType: (v) => setState(() {
              _type = v;
              _hidden.clear();
            }),
            onReset: () => setState(_hidden.clear),
          ),
          const BgmHairline(),
          Expanded(
            child: async.when(
              loading: () => const Loading(),
              error: (_, _) => const Center(child: Text('加载失败, 请刷新')),
              data: (list) {
                if (list.isEmpty) return const Center(child: Text('暂无数据'));
                final nodes = _buildNodes(list, _type, _hidden);
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final rects = squarify(
                      [for (final n in nodes) n.weight],
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return GestureDetector(
                      onTap: () => setState(_hidden.clear),
                      child: Stack(
                        children: [
                          for (var i = 0; i < nodes.length; i++)
                            if (rects[i] != null)
                              _UserCell(
                                node: nodes[i],
                                rect: rects[i]!,
                                onTap: () => _onCellTap(context, nodes[i]),
                                onLongPress: nodes[i].id < 0
                                    ? null
                                    : () => setState(
                                        () => _hidden.add(nodes[i].id),
                                      ),
                              ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onCellTap(BuildContext context, TreeNode node) {
    if (node.id < 0) {
      setState(_hidden.clear);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BgmActionRow(title: node.name),
            const BgmHairline(),
            BgmActionRow(
              leading: const Icon(Icons.account_balance_outlined),
              title: '资产分析',
              onTap: () {
                Navigator.of(ctx).pop();
                context.push(
                  '/tinygrail/tree?user=${Uri.encodeComponent(node.userName)}',
                );
              },
            ),
            BgmActionRow(
              leading: const Icon(Icons.visibility_off_outlined),
              title: '隐藏',
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() => _hidden.add(node.id));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class TreeNode {
  final int id;
  final String name;
  final String userName;
  final String avatar;
  final double weight;
  final double price;
  final double percent;

  const TreeNode({
    required this.id,
    required this.name,
    required this.userName,
    required this.avatar,
    required this.weight,
    required this.price,
    required this.percent,
  });
}

double _richValue(TinygrailRich item, String type) {
  switch (type) {
    case '总资产':
      return item.assets.toDouble();
    case '流动资金':
      return item.total.toDouble();
    case '初始资金':
      return item.principal.toDouble();
    case '周股息':
    default:
      return item.share.toDouble();
  }
}

/// 构建节点: 占比 < 0.88% 聚合为"其他N个用户" (原项目固定过滤率)
List<TreeNode> _buildNodes(
  List<TinygrailRich> list,
  String type,
  Set<int> hiddenIds,
) {
  final visible = [
    for (var i = 0; i < list.length; i++)
      if (!hiddenIds.contains(i)) list[i],
  ];
  final total = visible.fold<double>(0, (a, b) => a + _richValue(b, type));
  if (total <= 0) return const [];

  const filterRate = 0.0088;
  var filterCount = 0;
  var filterTotal = 0.0;
  final nodes = <TreeNode>[];
  for (final item in visible) {
    final value = _richValue(item, type);
    if (value / total < filterRate) {
      filterCount++;
      filterTotal += value;
      continue;
    }
    nodes.add(
      TreeNode(
        id: item.rank - 1,
        name: item.nickname.isEmpty ? item.userId : item.nickname,
        userName: item.userId,
        avatar: item.avatar,
        weight: value,
        price: value,
        percent: value / total,
      ),
    );
  }
  if (filterCount > 0) {
    nodes.add(
      TreeNode(
        id: -1,
        name: '其他$filterCount个用户',
        userName: '',
        avatar: '',
        // 其他的占比不会大于 3.2%
        weight: filterTotal / total > 0.032 ? total * 0.032 : filterTotal,
        price: filterTotal,
        percent: filterTotal / total,
      ),
    );
  }
  return nodes;
}

class _ToolBar extends StatelessWidget {
  final String type;
  final ValueChanged<String> onType;
  final VoidCallback onReset;

  const _ToolBar({
    required this.type,
    required this.onType,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          PopupMenuButton<String>(
            initialValue: type,
            onSelected: onType,
            itemBuilder: (context) => [
              for (final s in kTreeRichTypes)
                PopupMenuItem(value: s, child: Text(s)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppGap.x6),
              child: Row(children: [Text(type, style: context.ds.bodyStrong)]),
            ),
          ),
          BgmHeaderAction(
            icon: const Icon(Icons.restart_alt, size: 18),
            tooltip: '重置隐藏',
            onPressed: onReset,
          ),
        ],
      ),
    );
  }
}

class _UserCell extends StatelessWidget {
  final TreeNode node;
  final TreemapRect rect;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _UserCell({
    required this.node,
    required this.rect,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final showAvatar = node.percent > 0.012; // 面积占比 > 1.2% 才显示头像
    final isOther = node.id < 0;
    return Positioned(
      left: rect.x + 1,
      top: rect.y + 1,
      width: rect.w - 2,
      height: rect.h - 2,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: isOther || !showAvatar
                ? context.ds.surfaceBase
                : context.ds.surfaceCard,
            border: Border.all(color: context.ds.border, width: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!isOther && showAvatar && node.avatar.isNotEmpty)
                  Cover(
                    url: node.avatar.replaceFirst('//', 'https://'),
                    width: rect.w - 2,
                    height: rect.h - 2,
                    fit: BoxFit.cover,
                  ),
                if (!isOther && showAvatar)
                  Container(color: Colors.black.withValues(alpha: 0.35)),
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          node.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.ds.tiny.copyWith(
                            color: isOther
                                ? context.ds.textSecondary
                                : Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (rect.h > 40)
                        Text(
                          '${_price(node.price)} · ${(node.percent * 100).toStringAsFixed(1)}%',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.ds.tiny.copyWith(
                            fontSize: 9,
                            color: isOther
                                ? context.ds.textSecondary
                                : Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _price(double fen) {
    if (fen.abs() >= 100000000) {
      return '${(fen / 100000000).toStringAsFixed(1)}亿';
    }
    if (fen.abs() >= 10000) return '${(fen / 10000).toStringAsFixed(1)}万';
    return fen.toStringAsFixed(fen == fen.roundToDouble() ? 0 : 2);
  }
}
