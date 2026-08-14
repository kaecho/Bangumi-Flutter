import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'tinygrail_notes.dart';

/// 进阶玩法菜单
class TinygrailAdvanceScreen extends StatelessWidget {
  const TinygrailAdvanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('高级功能'),
        actions: [
          IconButton(
            tooltip: '说明',
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push(tinygrailAdvanceNotePath()),
          ),
        ],
      ),

      body: ListView(
        children: [
          _MenuTile(
            icon: Icons.add_circle_outline,
            title: '买入推荐',
            subtitle: '从市场中筛选低估角色',
            route: '/tinygrail/advance-ask',
          ),
          _MenuTile(
            icon: Icons.remove_circle_outline,
            title: '卖出推荐',
            subtitle: '从持仓中筛选高估角色',
            route: '/tinygrail/advance-bid',
          ),
          _MenuTile(
            icon: Icons.gavel_outlined,
            title: '拍卖推荐',
            subtitle: '从英灵殿中筛选拍卖标的',
            route: '/tinygrail/advance-auction',
          ),
          _MenuTile(
            icon: Icons.gavel_outlined,
            title: '拍卖推荐 B',
            subtitle: '按假设通天塔 250 名计算',
            route: '/tinygrail/advance-auction2',
          ),
          _MenuTile(
            icon: Icons.attach_money_outlined,
            title: '低价股',
            subtitle: '英灵殿中的低价角色',
            route: '/tinygrail/advance-state',
          ),
          _MenuTile(
            icon: Icons.local_fire_department_outlined,
            title: '献祭推荐',
            subtitle: '从持仓中筛选献祭标的',
            route: '/tinygrail/advance-sacrifice',
          ),
          _MenuTile(
            icon: Icons.account_tree_outlined,
            title: '资金分析',
            subtitle: '我的角色与圣殿矩形树图',
            route: '/tinygrail/tree',
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => context.push(route),
      ),
    );
  }
}
