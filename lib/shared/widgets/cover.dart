import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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

  const Cover({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.radius = 4,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.fadeIn = true,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _buildPlaceholder();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: fadeIn ? const Duration(milliseconds: 150) : Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (_, _) => _buildPlaceholder(),
        errorWidget: (_, _, _) => _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: placeholder ??
          Icon(
            Icons.movie_outlined,
            size: width * 0.3,
            color: Colors.black.withValues(alpha: 0.2),
          ),
    );
  }
}

/// 圆角头像
class Avatar extends StatelessWidget {
  final String url;
  final double size;
  final String? name;

  const Avatar({super.key, required this.url, this.size = 28, this.name});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: url.isEmpty
          ? Container(
              width: size,
              height: size,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              alignment: Alignment.center,
              child: Text(
                name != null && name!.isNotEmpty ? name!.characters.first : '?',
                style: TextStyle(fontSize: size * 0.4, color: Theme.of(context).colorScheme.primary),
              ),
            )
          : CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Container(
                width: size,
                height: size,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
    );
  }
}
