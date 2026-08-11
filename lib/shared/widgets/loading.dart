import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 44, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
          ),
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
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Theme.of(context).colorScheme.primary),
            ),
            if (text != null) ...[
              const SizedBox(height: 10),
              Text(text!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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

  const Skeleton({super.key, required this.width, required this.height, this.radius = 4});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
