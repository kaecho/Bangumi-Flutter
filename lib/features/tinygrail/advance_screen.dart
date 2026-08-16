import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'tinygrail_notes.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';

/// 进阶玩法菜单
class TinygrailAdvanceScreen extends StatelessWidget {
  const TinygrailAdvanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: '高级功能',
        actions: [
          BgmHeaderAction(
            tooltip: '说明',
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push(tinygrailAdvanceNotePath()),
          ),
        ],
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          final gap = 8.0;
          final width = (constraints.maxWidth - 24 - gap) / 2;
          const items = <(IconData, String, String)>[
            (Icons.add_circle_outline, '买入推荐', '/tinygrail/advance-ask'),
            (Icons.remove_circle_outline, '卖出推荐', '/tinygrail/advance-bid'),
            (Icons.gavel, '拍卖推荐', '/tinygrail/advance-auction'),
            (Icons.gavel, '拍卖推荐 B', '/tinygrail/advance-auction2'),
            (Icons.attach_money, '低价股', '/tinygrail/advance-state'),
            (Icons.insert_chart_outlined, '资金分析', '/tinygrail/tree'),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: width,
                      child: _MenuTile(
                        icon: item.$1,
                        title: item.$2,
                        route: item.$3,
                        width: width,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;
  final double width;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.route,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        width: width,
        height: width * 0.38,
        padding: const EdgeInsets.only(left: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            Positioned(
              right: -10,
              top: 0,
              bottom: 0,
              child: Icon(icon, size: 46, color: Theme.of(context).hintColor.withValues(alpha: 0.24)),
            ),
          ],
        ),
      ),
    );
  }
}
