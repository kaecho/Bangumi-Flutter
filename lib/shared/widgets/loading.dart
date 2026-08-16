import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/design_system.dart';
import 'bgm_button.dart';

/// 空状态
class Empty extends StatelessWidget {
  final String text;
  final IconData icon;
  final double height;

  const Empty({
    super.key,
    this.text = '暂时没有内容',
    this.icon = Icons.inbox_outlined,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 44, color: ds.textHint.withValues(alpha: 0.6)),
          const SizedBox(height: AppGap.x5),
          Text(text, style: ds.label.copyWith(color: ds.textSecondary)),
        ],
      ),
    );
  }
}

/// 原版粉色细转圈, 替代散落的 CircularProgressIndicator
class BgmSpinner extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const BgmSpinner({
    super.key,
    this.size = 18,
    this.strokeWidth = 2,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color ?? context.ds.accent,
      ),
    );
  }
}

/// 原版粉底滑条: 无 M3 涟漪轨道
class BgmSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final String? label;

  const BgmSlider({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: ds.accent,
        inactiveTrackColor: ds.border,
        thumbColor: ds.accent,
        overlayColor: ds.accentSoft,
        valueIndicatorColor: ds.accent,
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: onChanged,
      ),
    );
  }
}

/// 加载中
class Loading extends StatelessWidget {
  final double size;
  final String? text;
  final double? height;

  const Loading({super.key, this.size = 28, this.text, this.height});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Center(
      child: SizedBox(
        height: height,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BgmSpinner(size: size, strokeWidth: 2.5),

            if (text != null) ...[
              const SizedBox(height: AppGap.x5),
              Text(text!, style: ds.caption),
            ],
          ],
        ),
      ),
    );
  }
}

/// 骨架屏占位
class Skeleton extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const Skeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppRadius.s,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.ds.textHint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// 页面级加载/错误/重试容器
class PageStateView extends StatelessWidget {
  final AsyncValue<void> state;
  final Widget child;
  final VoidCallback? onRetry;

  const PageStateView({
    super.key,
    required this.state,
    required this.child,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return state.when(
      data: (_) => child,
      loading: () => const Loading(height: 300),
      error: (e, _) => BgmRetry(onRetry: onRetry, message: '$e'),
    );
  }
}

/// 加载失败 + 自有重试按钮 (替代各页散落的 FilledButton.tonal)
class BgmRetry extends StatelessWidget {
  final VoidCallback? onRetry;
  final String label;
  final String? message;

  const BgmRetry({super.key, this.onRetry, this.label = '重试', this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('加载失败', style: context.ds.bodyStrong),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.ds.caption,
              ),
            ),
          ],
          const SizedBox(height: 12),
          BgmButton(label, expand: false, onPressed: onRetry),
        ],
      ),
    );
  }
}
