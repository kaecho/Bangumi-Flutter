import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/status/server_status.dart';
import '../../core/storage/settings_store.dart';
import '../../design_system/design_system.dart';
import 'bgm_button.dart';

/// 服务可用性呼吸灯 (原项目 BreathingLight + notifyServerStatus)
class ServerStatusLight extends ConsumerStatefulWidget {
  const ServerStatusLight({super.key});

  @override
  ConsumerState<ServerStatusLight> createState() => _ServerStatusLightState();
}

class _ServerStatusLightState extends ConsumerState<ServerStatusLight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(settingsStoreProvider);
    final status = ref.watch(serverStatusProvider).valueOrNull;
    if (status == null ||
        !shouldNotifyServerStatus(store.serverStatusNotify, status.status)) {
      _controller.stop();
      return const SizedBox.shrink();
    }
    if (store.serverStatusBreathing) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = 0.6;
    }
    final color = switch (status.status) {
      'ok' => context.ds.success,
      'degraded' => context.ds.star,
      'down' => context.ds.error,
      _ => context.ds.textHint,
    };
    return BgmHeaderAction(
      tooltip: status.message.isEmpty ? '服务状态' : status.message,
      onPressed: () => context.push('/web/${Uri.encodeComponent(kStatusHost)}'),
      icon: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = store.serverStatusBreathing ? _controller.value : 0.6;
          return Transform.scale(
            scale: 1 + 0.28 * t,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.6 + 0.4 * t),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
