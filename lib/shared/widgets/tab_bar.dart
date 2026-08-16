import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// 底栏单项 (原项目 navigations/tab-bar/item)
class BgmTabItem {
  final String key;
  final String label;
  final IconData icon;
  final double iconSize;
  final String path;
  final Widget child;
  final bool alwaysShow;

  const BgmTabItem({
    required this.key,
    required this.label,
    required this.icon,
    this.iconSize = 24,
    required this.path,
    required this.child,
    required this.alwaysShow,
  });
}

/// 原版底栏: 50pt、无 M3 pill、选中才出字、选中粉
class BgmTabBar extends StatelessWidget {
  final List<BgmTabItem> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  const BgmTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onSelect,
  });

  static const double height = 50;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Material(
      color: ds.surfaceCard,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _BgmTabButton(
                    item: tabs[i],
                    selected: i == index,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BgmTabButton extends StatefulWidget {
  final BgmTabItem item;
  final bool selected;
  final VoidCallback onTap;

  const _BgmTabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_BgmTabButton> createState() => _BgmTabButtonState();
}

class _BgmTabButtonState extends State<_BgmTabButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final color = widget.selected ? ds.accent : ds.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: const Duration(milliseconds: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Icon(
                widget.item.icon,
                size: widget.item.iconSize,
                color: color,
              ),
            ),
            if (widget.selected) ...[
              const SizedBox(height: 2),
              Text(
                widget.item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ds.caption.copyWith(
                  color: color,
                  fontSize: 12,
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
