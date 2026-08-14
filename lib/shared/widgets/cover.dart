import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';
import '../../features/tinygrail/tinygrail_api.dart';
import '../../features/tinygrail/tinygrail_models.dart';

/// 封面图 (带缓存 + 占位/错误处理)
///
/// [url] 支持 bgm.tv 图片地址, 自动转换为对应尺寸
class Cover extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final double radius;
  final BoxFit fit;
  final Widget? placeholder;
  final bool fadeIn;
  final String? type;

  const Cover({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.radius = AppRadius.s,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.fadeIn = true,
    this.type,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, _) {
        if (url.isEmpty) return _buildPlaceholder();
        final store = SettingsStore.instance;
        final imageUrl = applyCoverQuality(
          url,
          store.imageQuality,
          displayWidth: width,
        );
        final image = ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: width,
            height: height,
            fit: fit,
            fadeInDuration: fadeIn && store.coverFadeIn
                ? const Duration(milliseconds: 150)
                : Duration.zero,
            fadeOutDuration: Duration.zero,
            httpHeaders: const {'Referer': 'https://bgm.tv/'},
            placeholder: (_, _) => _buildPlaceholder(),
            errorWidget: (_, _, _) => _buildPlaceholder(),
          ),
        );

        if (!store.coverThings || type == null || type!.isEmpty) return image;
        final color = switch (type) {
          'book' => const Color(0xFF8D6E63),
          'music' => const Color(0xFF7E57C2),
          'game' => const Color(0xFF43A047),
          'real' => const Color(0xFF039BE5),
          _ => const Color(0xFFEC6D77),
        };
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius + 1),
            border: Border.all(color: color, width: 1.5),
          ),
          child: image,
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    final skeleton = SettingsStore.instance.imageSkeleton;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppPalette.placeholderBg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: skeleton
          ? const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : placeholder ??
                Icon(
                  Icons.movie_outlined,
                  size: width * 0.3,
                  color: AppPalette.placeholderIcon,
                ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String url;
  final double size;
  final String? name;
  final String? userId;

  const Avatar({
    super.key,
    required this.url,
    this.size = 28,
    this.name,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final radius = SettingsStore.instance.avatarRound ? size / 2 : AppRadius.s;
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.isEmpty
          ? Container(
              width: size,
              height: size,
              color: ds.accentSoft,
              alignment: Alignment.center,
              child: Text(
                name != null && name!.isNotEmpty ? name!.characters.first : '?',
                style: TextStyle(fontSize: size * 0.4, color: ds.accent),
              ),
            )
          : CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) =>
                  Container(width: size, height: size, color: ds.accentSoft),
            ),
    );
    if (userId == null || userId!.isEmpty) return child;
    return GestureDetector(
      onLongPress: () => showTinygrailAssetsSheet(context, userId!),
      child: child,
    );
  }
}

Future<void> showTinygrailAssetsSheet(
  BuildContext context,
  String userId,
) async {
  final store = SettingsStore.instance;
  if (!store.tinygrailEnabled || !store.avatarAlertTinygrailAssets) return;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => _TinygrailAssetsSheet(userId: userId),
  );
}

class _TinygrailAssetsSheet extends ConsumerWidget {
  final String userId;
  const _TinygrailAssetsSheet({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = SettingsStore.instance;
    return FutureBuilder<TinygrailUser>(
      future: ref.read(tinygrailApiProvider).fetchAssets(userId),
      builder: (context, snap) {
        final user = snap.data;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: snap.connectionState != ConnectionState.done
                ? const Center(child: CircularProgressIndicator())
                : user == null || (user.total == 0 && user.balance == 0)
                ? Text('未找到 $userId 的小圣杯资产', style: context.ds.body)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nickname.isEmpty ? userId : user.nickname,
                        style: context.ds.title,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '总资产 ${store.xsbShort ? tgMoney(user.total) : user.total} · 现金 ${store.xsbShort ? tgMoney(user.balance) : user.balance}',
                        style: context.ds.body,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
