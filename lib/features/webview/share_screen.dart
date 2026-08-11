import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/models/collection.dart';
import '../../shared/models/subject.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';

/// 分享卡片数据: 条目 + 展示评分 (个人评分优先, 否则条目评分)
class ShareCardData {
  final Subject subject;
  final double score;

  const ShareCardData({required this.subject, required this.score});
}

final shareCardProvider = FutureProvider.family<ShareCardData, int>((ref, subjectId) async {
  final client = ref.read(apiClientProvider);
  Subject? subject;
  var score = 0.0;
  try {
    final data = await client.get(apiCollection(subjectId));
    final item = CollectionItem.fromJson(data as Map<String, dynamic>);
    subject = item.subject;
    score = item.rate.toDouble();
  } catch (_) {
    // 未收藏 / 未登录: 退回条目信息
  }
  subject ??= Subject.fromJson(
    await client.get(apiSubject(subjectId)) as Map<String, dynamic>,
  );
  if (score <= 0) score = subject.rating?.score ?? 0;
  return ShareCardData(subject: subject, score: score);
});

/// 拼图分享 (移植自原项目 screens/web-view/share)
///
/// 生成条目分享卡片 (封面 + 名称 + 评分), 导出 PNG 并调起系统分享。
/// 路由: /share/:subjectId
class ShareScreen extends ConsumerStatefulWidget {
  final int subjectId;

  const ShareScreen({super.key, required this.subjectId});

  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share(ShareCardData data) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      // 等待封面加载完成再截取
      final imageUrl = data.subject.images.large.isNotEmpty
          ? data.subject.images.large
          : data.subject.images.common;
      if (imageUrl.isNotEmpty) {
        await precacheImage(CachedNetworkImageProvider(imageUrl), context);
      }
      // 等待一帧确保 RepaintBoundary 已绘制
      await WidgetsBinding.instance.endOfFrame;

      final boundary = _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null || !mounted) return;

      final dir = await Directory.systemTemp.createTemp('bgm_share');
      final file = File('${dir.path}/share_${data.subject.id}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '「${data.subject.displayName}」— Bangumi 番组计划',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分享失败, 请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(shareCardProvider(widget.subjectId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('拼图分享'),
        actions: [
          data.maybeWhen(
            data: (value) => IconButton(
              tooltip: '分享',
              icon: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_outlined),
              onPressed: _sharing ? null : () => _share(value),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Center(
        child: data.when(
          loading: () => const Loading(text: '生成分享卡片中...'),
          error: (e, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 8),
              const Text('获取条目信息失败'),
              const SizedBox(height: 8),
              Text(apiErrorMessage(e), style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(shareCardProvider(widget.subjectId)),
                child: const Text('重试'),
              ),
            ],
          ),
          data: (value) => RepaintBoundary(
            key: _cardKey,
            child: _ShareCard(data: value),
          ),
        ),
      ),
    );
  }
}

/// 分享卡片: 封面 + 名称 + 评分
class _ShareCard extends StatelessWidget {
  final ShareCardData data;

  const _ShareCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final subject = data.subject;
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = subject.images.large.isNotEmpty
        ? subject.images.large
        : subject.images.common;
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.surfaceContainerHighest],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Cover(
              url: imageUrl,
              width: 180,
              height: 240,
              radius: 8,
              placeholder: Container(
                width: 180,
                height: 240,
                color: scheme.surfaceContainerHigh,
                child: const Icon(Icons.image_outlined, size: 40),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subject.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${SubjectType.text(subject.type)} · ${subject.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                data.score > 0 ? data.score.toStringAsFixed(1) : '-',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.star, size: 16, color: Colors.amber.shade600),
              const Spacer(),
              Text(
                'Bangumi 番组计划',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
