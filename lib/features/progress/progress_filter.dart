import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../shared/widgets/loading.dart';

/// 原版首页 Filter: 64pt 区、40pt 居中药丸、数量/搜索叠中间
class ProgressFilterBar extends StatefulWidget {
  final TextEditingController controller;
  final int length;
  final bool fetching;
  final String percent;
  final ValueChanged<String> onChanged;

  const ProgressFilterBar({
    super.key,
    required this.controller,
    required this.length,
    required this.fetching,
    this.percent = '',
    required this.onChanged,
  });

  @override
  State<ProgressFilterBar> createState() => _ProgressFilterBarState();
}

class _ProgressFilterBarState extends State<ProgressFilterBar> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            TextField(
              controller: widget.controller,
              textAlign: TextAlign.center,
              style: ds.bodyStrong.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              cursorColor: ds.accent,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: dark ? ds.surfaceCard : ds.border,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: widget.onChanged,
              onTap: () => setState(() => _focus = true),
              onTapOutside: (_) {
                FocusScope.of(context).unfocus();
                setState(() => _focus = false);
              },
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, value, _) {
                if (_focus || value.text.isNotEmpty) {
                  return const SizedBox.shrink();
                }
                return IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.fetching) ...[
                        if (widget.percent.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              widget.percent,
                              style: ds.tiny.copyWith(color: ds.textHint),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: BgmSpinner(size: 16, color: ds.textHint),
                        ),
                      ],
                      if (widget.length > 0)
                        Text(
                          '${widget.length}',
                          style: ds.bodyStrong.copyWith(
                            fontSize: 15,
                            color: dark ? ds.textHint : ds.textSecondary,
                          ),
                        )
                      else
                        Icon(Icons.search, size: 18, color: ds.textHint),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
