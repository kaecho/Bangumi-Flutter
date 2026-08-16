import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import 'loading.dart';

/// 原版 Button.type: main / plain / ghost
enum BgmButtonType { main, plain, ghost }

/// 原版 Button: 高 44、粉底、无 Material 3 涟漪胶囊
class BgmButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final BgmButtonType type;
  final bool loading;
  final bool expand;

  const BgmButton(
    this.label, {
    super.key,
    this.onPressed,
    this.type = BgmButtonType.main,
    this.loading = false,
    this.expand = true,
  });

  @override
  State<BgmButton> createState() => _BgmButtonState();
}

class _BgmButtonState extends State<BgmButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final enabled = widget.onPressed != null && !widget.loading;
    final Color bg;
    final Color fg;
    final Border? border;
    switch (widget.type) {
      case BgmButtonType.main:
        bg = ds.accent;
        fg = Colors.white;
        border = null;
      case BgmButtonType.plain:
        bg = ds.surfaceCard;
        fg = ds.textPrimary;
        border = Border.all(color: ds.border, width: 0.5);
      case BgmButtonType.ghost:
        bg = ds.accentSoft;
        fg = ds.accent;
        border = Border.all(color: ds.accent.withValues(alpha: 0.35));
    }
    final child = AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: const Duration(milliseconds: 80),
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.45,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.lAll,
            border: border,
          ),
          child: widget.loading
              ? BgmSpinner(size: 18, strokeWidth: 2, color: fg)
              : Text(widget.label, style: ds.bodyStrong.copyWith(color: fg)),
        ),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: () => setState(() => _down = false),
      onTap: enabled ? widget.onPressed : null,
      child: widget.expand ? child : IntrinsicWidth(child: child),
    );
  }
}

/// 原版小号文字按钮: 章节「全部」/「加载更多」, 不是 44 高胶囊
class BgmTextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const BgmTextAction(this.label, {super.key, this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final enabled = onPressed != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Text(
            label,
            style: ds.label.copyWith(color: color ?? ds.accent),
          ),
        ),
      ),
    );
  }
}

/// 原版筛选项: 粉底选中, 非 M3 stadium Chip
class BgmFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const BgmFilterChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? ds.accentSoft : Colors.transparent,
        borderRadius: AppRadius.mAll,
      ),
      child: Text(
        label,
        style: ds.caption.copyWith(
          color: selected ? ds.accent : ds.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}

/// 原版 TabBar: 高 42、粉下划线 16pt、无 M3 指示条
class BgmTabStrip extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget> tabs;
  final int index;
  final ValueChanged<int> onSelect;
  final bool scrollable;

  const BgmTabStrip({
    super.key,
    required this.tabs,
    required this.index,
    required this.onSelect,
    this.scrollable = false,
  });

  static const double height = 42;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final row = Row(
      children: [
        for (var i = 0; i < tabs.length; i++)
          scrollable
              ? _BgmTabCell(
                  selected: i == index,
                  onTap: () => onSelect(i),
                  child: tabs[i],
                )
              : Expanded(
                  child: _BgmTabCell(
                    selected: i == index,
                    onTap: () => onSelect(i),
                    child: tabs[i],
                  ),
                ),
      ],
    );
    return ColoredBox(
      color: ds.surfaceCard,
      child: SizedBox(
        height: height,
        child: scrollable
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: row,
              )
            : row,
      ),
    );
  }
}

/// 跟 [TabController] / [TabBarView] 同步的原版页签条
class BgmControlledTabStrip extends StatefulWidget
    implements PreferredSizeWidget {
  final TabController controller;
  final List<Widget> tabs;
  final bool scrollable;

  const BgmControlledTabStrip({
    super.key,
    required this.controller,
    required this.tabs,
    this.scrollable = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(BgmTabStrip.height);

  @override
  State<BgmControlledTabStrip> createState() => _BgmControlledTabStripState();
}

class _BgmControlledTabStripState extends State<BgmControlledTabStrip> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
  }

  @override
  void didUpdateWidget(BgmControlledTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTick);
      widget.controller.addListener(_onTick);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BgmTabStrip(
      tabs: widget.tabs,
      index: widget.controller.index,
      scrollable: widget.scrollable,
      onSelect: widget.controller.animateTo,
    );
  }
}

/// 给 [DefaultTabController] 用的原版页签条
class BgmDefaultTabStrip extends StatelessWidget
    implements PreferredSizeWidget {
  final List<Widget> tabs;
  final bool scrollable;

  const BgmDefaultTabStrip({
    super.key,
    required this.tabs,
    this.scrollable = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(BgmTabStrip.height);

  @override
  Widget build(BuildContext context) {
    return BgmControlledTabStrip(
      controller: DefaultTabController.of(context),
      tabs: tabs,
      scrollable: scrollable,
    );
  }
}

class _BgmTabCell extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _BgmTabCell({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DefaultTextStyle(
              style: ds.label.copyWith(
                color: selected ? ds.accent : ds.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: child,
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: selected ? 16 : 0,
              height: 2,
              color: ds.accent,
            ),
          ],
        ),
      ),
    );
  }
}

/// 原版底部弹层容器: 顶圆角、无 M3 drag handle
class BgmSheet extends StatelessWidget {
  final Widget child;

  const BgmSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ds.surfaceCard,
        borderRadius: AppRadius.sheetTop,
      ),
      child: child,
    );
  }
}

/// 原版卡片面: 浅描边、无 M3 阴影抬升
class BgmCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;

  const BgmCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    Widget box = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? ds.surfaceCard,
        borderRadius: AppRadius.lAll,
        border: Border.all(color: ds.border, width: 0.5),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
    box = ClipRRect(borderRadius: AppRadius.lAll, child: box);
    if (onTap != null) {
      box = GestureDetector(onTap: onTap, child: box);
    }
    if (margin != null) {
      box = Padding(padding: margin!, child: box);
    }
    return box;
  }
}

Future<T?> showBgmSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => BgmSheet(child: builder(ctx)),
  );
}

/// 原版 SwitchPro: 52x32 轨道, 开绿色关灰, 无 M3 涟漪开关
class BgmSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const BgmSwitch({super.key, required this.value, this.onChanged});

  static const double width = 40;
  static const double height = 24;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final enabled = onChanged != null;
    return GestureDetector(
      onTap: enabled ? () => onChanged!(!value) : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.45,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: width,
          height: height,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? const Color(0xFF43D551) : ds.border,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: height - 4,
            height: height - 4,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// 原版 SegmentedControl: 粉底选中, 无 M3 stadium
class BgmSegmented<T> extends StatelessWidget {
  final List<(T, String)> values;
  final T selected;
  final ValueChanged<T> onSelect;
  final bool expand;

  const BgmSegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.onSelect,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    Widget cell((T, String) item) {
      final (value, tit) = item;
      return GestureDetector(
        onTap: () => onSelect(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: value == selected ? ds.accentSoft : Colors.transparent,
            borderRadius: AppRadius.mAll,
          ),
          child: Text(
            tit,
            style: ds.caption.copyWith(
              color: value == selected ? ds.accent : ds.textSecondary,
              fontWeight: value == selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ds.surfaceBase,
        borderRadius: AppRadius.mAll,
        border: Border.all(color: ds.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final item in values)
            if (expand) Expanded(child: cell(item)) else cell(item),
        ],
      ),
    );
  }
}

/// 原版设置右侧选择: 粉底药丸 + Header Popover, 不是 M3 DropdownButton
class BgmSelect<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final String? tooltip;

  const BgmSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.tooltip,
  });
  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final current = items.firstWhere(
      (e) => e.$1 == value,
      orElse: () => items.first,
    );
    return PopupMenuButton<int>(
      tooltip: tooltip ?? current.$2,
      padding: EdgeInsets.zero,
      onSelected: (index) => onChanged(items[index].$1),
      itemBuilder: (_) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem(value: i, child: Text(items[i].$2)),
      ],
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ds.accentSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ds.accent.withValues(alpha: 0.35)),
        ),
        child: Text(
          current.$2,
          style: ds.caption.copyWith(
            color: ds.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// 原版确认框: 圆角卡片、无 M3 默认 Dialog 形状
class BgmDialog extends StatelessWidget {
  final String? title;
  final Widget? content;
  final List<Widget> actions;

  const BgmDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ds.surfaceCard,
        borderRadius: AppRadius.xlAll,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null && title!.isNotEmpty)
              Text(title!, style: ds.section),
            if (content != null) ...[
              if (title != null && title!.isNotEmpty)
                const SizedBox(height: 10),
              DefaultTextStyle(style: ds.body, child: content!),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    actions[i],
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<T?> showBgmDialog<T>({
  required BuildContext context,
  String? title,
  Widget? content,
  required List<Widget> Function(BuildContext ctx) actions,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: BgmDialog(title: title, content: content, actions: actions(ctx)),
    ),
  );
}

Future<bool> showBgmConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
}) async {
  final ok = await showBgmDialog<bool>(
    context: context,
    title: title,
    content: message == null ? null : Text(message),
    actions: (ctx) => [
      BgmButton(
        cancelLabel,
        type: BgmButtonType.plain,
        expand: false,
        onPressed: () => Navigator.pop(ctx, false),
      ),
      BgmButton(
        confirmLabel,
        expand: false,
        onPressed: () => Navigator.pop(ctx, true),
      ),
    ],
  );
  return ok == true;
}

/// 原版 Toast.info: 居中暗底, 默认 2.4s, 不是底部 M3 SnackBar
void showBgmToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 2400),
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xCC000000),
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 72),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mAll),
      ),
    );
}

/// 原版列表细分割线 (0.5pt border token, 不是 M3 Divider)
class BgmHairline extends StatelessWidget {
  final double indent;
  final double height;
  final double thickness;

  const BgmHairline({
    super.key,
    this.indent = 0,
    this.height = 1,
    this.thickness = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Container(
          height: thickness,
          margin: EdgeInsets.only(left: indent),
          color: context.ds.border,
        ),
      ),
    );
  }
}

/// 原版折叠块: 标题点开展开, 无 M3 ExpansionTile
class BgmExpand extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> children;
  final bool initiallyExpanded;
  final EdgeInsetsGeometry titlePadding;
  final EdgeInsetsGeometry childrenPadding;

  const BgmExpand({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.children,
    this.initiallyExpanded = false,
    this.titlePadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
    this.childrenPadding = EdgeInsets.zero,
  });

  @override
  State<BgmExpand> createState() => _BgmExpandState();
}

class _BgmExpandState extends State<BgmExpand> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: widget.titlePadding,
            child: Row(
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: ds.section),
                      if (widget.subtitle != null &&
                          widget.subtitle!.isNotEmpty)
                        Text(widget.subtitle!, style: ds.caption),
                    ],
                  ),
                ),
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: ds.textHint,
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: widget.childrenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          ),
      ],
    );
  }
}

/// 原版 Input: 浅色描边、深色无边、圆角小、无 M3 默认描边
InputDecoration bgmInputDecoration({
  String? hintText,
  String? labelText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  int? maxLines,
  bool dense = true,
}) {
  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    isDense: dense,
    filled: true,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    alignLabelWithHint: maxLines != null && maxLines > 1,
  );
}

class BgmField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final int? minLines;
  final int maxLines;
  final int? maxLength;
  final bool autofocus;
  final bool enabled;
  final bool obscureText;
  final TextAlign textAlign;
  final TextStyle? style;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const BgmField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.autofocus = false,
    this.enabled = true,
    this.obscureText = false,
    this.textAlign = TextAlign.start,
    this.style,
    this.textInputAction,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      obscureText: obscureText,
      minLines: obscureText ? null : minLines,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      textAlign: textAlign,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: style ?? ds.body,
      cursorColor: ds.accent,
      decoration: bgmInputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        maxLines: maxLines,
      ).copyWith(fillColor: ds.surfaceCard, hintStyle: ds.caption),
    );
  }
}

/// 原版 ItemSetting: 左标题 + 下说明, 右控件/箭头, 无 M3 ListTile
class BgmSettingRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? below;
  final bool arrow;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const BgmSettingRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.below,
    this.arrow = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final child = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text(title, style: ds.bodyStrong)),
              ?trailing,
              if (arrow)
                Icon(Icons.navigate_next, size: 20, color: ds.textSecondary),
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: ds.caption),
          ],
          if (below != null) ...[const SizedBox(height: 8), below!],
        ],
      ),
    );
    if (onTap == null && onLongPress == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: child,
    );
  }
}

/// 原版文字列表行: 左标题 +N, 下次行, 右侧附加, 无 M3 ListTile
class BgmTextRow extends StatelessWidget {
  final String title;

  final int replies;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;

  const BgmTextRow({
    super.key,
    required this.title,
    this.replies = 0,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 10),
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final child = Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: title),
                      if (replies > 0)
                        TextSpan(
                          text: ' +$replies',
                          style: TextStyle(
                            color: ds.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  style: ds.bodyStrong,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: ds.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
    if (onTap == null && onLongPress == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: child,
    );
  }
}

/// 原版 Popover 操作行: 左图标 + 标题, 无 M3 ListTile
class BgmActionRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  const BgmActionRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final child = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ds.bodyStrong),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: ds.caption),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
    if (onTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}

/// 原版 Header 36pt 图标按钮, 无 M3 IconButton 涟漪
class BgmHeaderAction extends StatelessWidget {
  final Widget icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  const BgmHeaderAction({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(width: 36, height: 36, child: Center(child: icon));
    final tap = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      onLongPress: onLongPress,
      child: child,
    );
    if (tooltip == null || tooltip!.isEmpty) return tap;
    return Tooltip(message: tooltip!, child: tap);
  }
}

/// 原版 HeaderV2Popover: 横点更多, 无地球图标
class BgmHeaderMore extends StatelessWidget {
  final List<(String, String)> items;
  final ValueChanged<String> onSelected;
  final String tooltip;
  final Color? iconColor;

  const BgmHeaderMore({
    super.key,
    required this.items,
    required this.onSelected,
    this.tooltip = '更多',
    this.iconColor,
  });

  factory BgmHeaderMore.browser(
    VoidCallback onOpen, {
    Key? key,
    Color? iconColor,
  }) {
    return BgmHeaderMore(
      key: key,
      items: const [('browser', '浏览器查看')],
      onSelected: (_) => onOpen(),
      iconColor: iconColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz, color: iconColor),
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final item in items)
          PopupMenuItem(value: item.$1, child: Text(item.$2)),
      ],
    );
  }
}

void scrollBgmToTop(ScrollController controller) {
  if (!controller.hasClients) return;
  controller.animateTo(
    0,
    duration: const Duration(milliseconds: 240),
    curve: Curves.easeOut,
  );
}

/// 原版发现 Extra: 切布局 + 回顶, 不是地球图标
class BgmDiscoveryExtra extends StatelessWidget {
  final bool isList;
  final VoidCallback onToggleLayout;
  final VoidCallback onScrollToTop;

  const BgmDiscoveryExtra({
    super.key,
    required this.isList,
    required this.onToggleLayout,
    required this.onScrollToTop,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BgmHeaderAction(
          tooltip: isList ? '网格' : '列表',
          icon: Icon(isList ? Icons.grid_view : Icons.view_list),
          onPressed: onToggleLayout,
        ),
        BgmHeaderAction(
          tooltip: '到顶',
          icon: const Icon(Icons.vertical_align_top),
          onPressed: onScrollToTop,
        ),
      ],
    );
  }
}
