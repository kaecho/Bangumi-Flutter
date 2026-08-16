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
import 'tinygrail_notes.dart';


/// 资产分析 (股票树) — 移植自原项目 screens/tinygrail/tree
///
/// 用户角色 + 圣殿数据合并为矩形树图, 按范围/计算类型切换面积权重。
/// userName 为空表示当前登录用户, 也可传入其他用户 ID 或英灵殿。
class TinygrailTreeScreen extends ConsumerStatefulWidget {
  final String userName;

  const TinygrailTreeScreen({super.key, this.userName = ''});

  @override
  ConsumerState<TinygrailTreeScreen> createState() =>
      _TinygrailTreeScreenState();
}

/// 范围: 所有 / 流动股 / 圣殿股
const kTreeTypes = ['所有', '流动股', '圣殿股'];

/// 计算类型 (面积权重口径)
const kTreeCaculateTypes = [
  '周股息',
  '持仓价值',
  '股息',
  '持股数',
  '市场价',
  '发行量',
  '当前价',
  '交易量',
  '当前涨跌',
  '新番奖励',
];

/// 英灵殿底价兜底 (原项目 VALHALL_PRICE 为空 map, 默认 10)
const _valhallPrice = 10;

/// 角色 + 圣殿统一数据 (合并后)
class TreeItem {
  final int id;
  final String name;
  final String icon;
  final int state; // 活股数
  final int current; // 现价
  final double rate; // 股息率
  final int level; // 股票等级
  final int marketValue;
  final int total;
  final int change;
  final double fluctuation; // 百分比
  final int bonus;
  final int sacrifices; // 献祭数 (合并时为总献祭)

  const TreeItem({
    required this.id,
    required this.name,
    required this.icon,
    this.state = 0,
    this.current = 0,
    this.rate = 0,
    this.level = 0,
    this.marketValue = 0,
    this.total = 0,
    this.change = 0,
    this.fluctuation = 0,
    this.bonus = 0,
    this.sacrifices = 0,
  });

  factory TreeItem.fromChara(TinygrailChara c) => TreeItem(
    id: c.id,
    name: c.name,
    icon: c.icon,
    state: c.state,
    current: c.current,
    rate: c.rate,
    level: c.level,
    marketValue: c.marketValue,
    total: c.total,
    change: c.change,
    fluctuation: c.fluctuation,
    bonus: c.bonus,
    sacrifices: c.sacrifices,
  );

  factory TreeItem.fromTemple(TinygrailTemple t) => TreeItem(
    id: t.id,
    name: t.name,
    icon: t.cover,
    level: t.level,
    rate: t.rate,
    sacrifices: t.sacrifices,
  );
}

/// 按范围合并角色与圣殿数据 (原项目 charaAssets computed)
List<TreeItem> mergeTreeItems(
  List<TinygrailChara> chara,
  List<TinygrailTemple> temple,
  String type,
) {
  if (type == '流动股') return [for (final c in chara) TreeItem.fromChara(c)];
  if (type == '圣殿股') return [for (final t in temple) TreeItem.fromTemple(t)];
  // 所有: 角色字段覆盖圣殿同名项, 圣殿多余项追加
  final result = <TreeItem>[];
  final templeById = {for (final t in temple) t.id: t};
  for (final c in chara) {
    result.add(TreeItem.fromChara(c));
    templeById.remove(c.id);
  }
  result.addAll([for (final t in templeById.values) TreeItem.fromTemple(t)]);
  return result;
}

/// 单项面积权重 (原项目 caculateValue)
double caculateTreeValue(TreeItem item, String label, {bool isTemple = false}) {
  switch (label) {
    case '持仓价值':
      if (isTemple) return item.sacrifices * _valhallPrice * 0.5;
      if (item.sacrifices > 0) {
        return (item.state) *
                (item.current <= 0 ? _valhallPrice : item.current) +
            item.sacrifices *
                (item.current <= 0 ? _valhallPrice : item.current) *
                0.5;
      }
      return item.state * item.current.toDouble();
    case '周股息':
      if (isTemple) return item.sacrifices * item.rate * (item.level + 1) * 0.3;
      if (item.sacrifices > 0) {
        return item.state * item.rate +
            item.sacrifices * item.rate * (item.level + 1) * 0.3;
      }
      return item.state * item.rate;
    case '股息':
      return item.rate;
    case '持股数':
      if (isTemple) return item.sacrifices * 0.5;
      if (item.sacrifices > 0) return item.state + item.sacrifices * 0.5;
      return item.state.toDouble();
    case '市场价':
      return item.marketValue.toDouble();
    case '发行量':
      return item.total.toDouble();
    case '当前价':
      return item.current.toDouble();
    case '交易量':
      return item.change.toDouble();
    case '当前涨跌':
      return item.fluctuation.abs();
    case '新番奖励':
      return item.bonus.toDouble();
    default:
      return 0;
  }
}

double caculateTreeTotal(
  List<TreeItem> list,
  String label, {
  bool isTemple = false,
}) {
  return list.fold<double>(
    0,
    (a, b) => a + caculateTreeValue(b, label, isTemple: isTemple),
  );
}

/// 树图节点
class TreeNode {
  final int id;
  final String name;
  final String icon;
  final double weight;
  final double price;
  final double percent;
  final double fluctuation;

  const TreeNode({
    required this.id,
    required this.name,
    required this.icon,
    required this.weight,
    required this.price,
    required this.percent,
    this.fluctuation = 0,
  });
}

/// 构建节点列表: 低于过滤比例的条目聚合为"其他N个角色" (原项目 generateTreeMap)
List<TreeNode> buildTreeNodes(
  List<TreeItem> list,
  String caculateType, {
  Set<int> hiddenIds = const {},
}) {
  final isTemple = false;
  final total = caculateTreeTotal(list, caculateType, isTemple: isTemple);
  final visible = list.where((i) => !hiddenIds.contains(i.id)).toList();
  final currentTotal = caculateTreeTotal(
    visible,
    caculateType,
    isTemple: isTemple,
  );

  final filterRate = (0.0072 - hiddenIds.length * 0.0002).clamp(0.005, 1.0);
  var filterCount = 0;
  var filterTotal = 0.0;
  final nodes = <TreeNode>[];
  for (final item in visible) {
    final value = caculateTreeValue(item, caculateType, isTemple: isTemple);
    if (currentTotal > 0 && value / currentTotal < filterRate) {
      filterCount++;
      filterTotal += value;
      continue;
    }
    nodes.add(
      TreeNode(
        id: item.id,
        name: item.name,
        icon: item.icon,
        weight: value,
        price: value,
        percent: total > 0 ? value / total : 0,
        fluctuation: item.fluctuation,
      ),
    );
  }
  if (filterCount > 0) {
    nodes.add(
      TreeNode(
        id: 0,
        name: '其他$filterCount个角色',
        icon: '',
        // 其他的占比不会大于 5%
        weight: filterTotal / currentTotal > 0.05
            ? currentTotal * 0.05
            : filterTotal,
        price: filterTotal,
        percent: total > 0 ? filterTotal / total : 0,
      ),
    );
  }
  return nodes;
}

/// 资产分析数据
final treeAssetsProvider =
    FutureProvider.family<
      ({List<TinygrailChara> chara, List<TinygrailTemple> temple}),
      String
    >((ref, userName) async {
      final api = ref.watch(tinygrailApiProvider);
      if (userName == 'valhalla@tinygrail.com') {
        final list = await api.fetchValhalla(limit: 1600);
        return (chara: list, temple: const <TinygrailTemple>[]);
      }
      final results = await Future.wait([
        api.fetchCharaAll(userName),
        api.fetchMyTemple(userName),
      ]);
      return (
        chara: results[0] as List<TinygrailChara>,
        temple: results[1] as List<TinygrailTemple>,
      );
    });

class _TinygrailTreeScreenState extends ConsumerState<TinygrailTreeScreen> {
  String _type = '所有';
  String _caculateType = '周股息';
  final Set<int> _hidden = {};

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(treeAssetsProvider(widget.userName));
    return Scaffold(
      appBar: BgmAppBar(
        title: widget.userName.isEmpty ? '资产分析' : widget.userName,
        actions: [
          BgmHeaderAction(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () =>
                ref.invalidate(treeAssetsProvider(widget.userName)),
          ),
          BgmHeaderAction(
            icon: const Icon(Icons.info_outline),
            tooltip: '说明',
            onPressed: () => context.push(tinygrailTreeNotePath()),
          ),
        ],
      ),
      body: Column(
        children: [
          _ToolBar(
            type: _type,
            caculateType: _caculateType,
            onType: (v) => setState(() {
              _type = v;
              _hidden.clear();
            }),
            onCaculate: (v) => setState(() {
              _caculateType = v;
              _hidden.clear();
            }),
            onReset: () => setState(_hidden.clear),
          ),
          const BgmHairline(),
          Expanded(
            child: async.when(
              loading: () => const Loading(),
              error: (_, _) => const Center(child: Text('加载失败, 请刷新')),
              data: (data) {
                final items = mergeTreeItems(data.chara, data.temple, _type);
                if (items.isEmpty) return const Center(child: Text('暂无数据'));
                final nodes = buildTreeNodes(
                  items,
                  _caculateType,
                  hiddenIds: _hidden,
                );
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
                              _TreeCell(
                                node: nodes[i],
                                rect: rects[i]!,
                                onTap: () => _onCellTap(context, nodes[i]),
                                onLongPress: nodes[i].id == 0
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
    if (node.id == 0) {
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
              leading: const Icon(Icons.show_chart),
              title: '角色详情 (K线/买卖/献祭)',
              onTap: () {
                Navigator.of(ctx).pop();
                context.push('/tinygrail/chara/${node.id}');
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

class _ToolBar extends StatelessWidget {
  final String type;
  final String caculateType;
  final ValueChanged<String> onType;
  final ValueChanged<String> onCaculate;
  final VoidCallback onReset;

  const _ToolBar({
    required this.type,
    required this.caculateType,
    required this.onType,
    required this.onCaculate,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          _PopupButton(label: type, items: kTreeTypes, onSelected: onType),
          _PopupButton(
            label: caculateType,
            items: kTreeCaculateTypes,
            onSelected: onCaculate,
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

class _PopupButton extends StatelessWidget {
  final String label;
  final List<String> items;
  final ValueChanged<String> onSelected;

  const _PopupButton({
    required this.label,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: label,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final s in items) PopupMenuItem(value: s, child: Text(s)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppGap.x6),
        child: Row(children: [Text(label, style: context.ds.bodyStrong)]),
      ),
    );
  }
}

class _TreeCell extends StatelessWidget {
  final TreeNode node;
  final TreemapRect rect;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _TreeCell({
    required this.node,
    required this.rect,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final showAvatar = node.percent > 0.016; // 面积占比 > 1.6% 才显示头像
    final isOther = node.id == 0;
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
            color: isOther
                ? context.ds.surfaceBase
                : showAvatar
                ? context.ds.surfaceCard
                : context.ds.surfaceBase,
            border: Border.all(color: context.ds.border, width: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!isOther && showAvatar && node.icon.isNotEmpty)
                  Cover(
                    url: node.icon.replaceFirst('//', 'https://'),
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
