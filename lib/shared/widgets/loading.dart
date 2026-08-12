import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/design_system.dart';

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
            SizedBox(
              width: size,
              height: size,
              child: const CircularProgressIndicator(strokeWidth: 2.5),
            ),
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

  const PageStateView({super.key, required this.state, required this.child});

  @override
  Widget build(BuildContext context) {
    return state.when(
      data: (_) => child,
      loading: () => const Loading(height: 300),
      error: (e, _) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Empty(text: '加载失败, 请检查网络'),
          TextButton(
            onPressed: () {},
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
