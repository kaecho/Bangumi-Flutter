import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';
import 'subject_models.dart';
import 'subject_providers.dart';
import '../../design_system/design_system.dart';

/// 番剧截屏预览
/// 路由: /subject/:id/preview
///
/// 数据来源: bangumi-data 找到 bilibili season → bilibili API 取每集封面
class PreviewScreen extends ConsumerWidget {
  final int id;

  const PreviewScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(previewProvider(id));
    return Scaffold(
      appBar: BgmAppBar(title: '预览', showBackButton: true),
      body: preview.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 8),
              const Text('加载失败'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(previewProvider(id)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (list) => list.isEmpty
            ? const Empty(text: '暂无预览截图', icon: Icons.image_not_supported_outlined)
            : GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 16 / 9,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _openViewer(context, list, i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      list[i].url,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : Container(
                              color: Colors.black12,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                      errorBuilder: (_, _, _) => Container(
                        color: Colors.black12,
                        child: Center(
                          child: Icon(Icons.broken_image_outlined, color: context.ds.textHint),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  void _openViewer(BuildContext context, List<PreviewImage> list, int index) {
    Navigator.push(
      context,
      MaterialPageRoute<_PreviewViewer>(
        builder: (_) => _PreviewViewer(images: list, initialIndex: index),
      ),
    );
  }
}

class _PreviewViewer extends StatefulWidget {
  final List<PreviewImage> images;
  final int initialIndex;

  const _PreviewViewer({required this.images, required this.initialIndex});

  @override
  State<_PreviewViewer> createState() => _PreviewViewerState();
}

class _PreviewViewerState extends State<_PreviewViewer> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _current = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            itemCount: widget.images.length,
            pageController: _controller,
            onPageChanged: (i) => setState(() => _current = i),
            builder: (context, i) => PhotoViewGalleryPageOptions(
              imageProvider: NetworkImage(widget.images[i].url),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              heroAttributes: PhotoViewHeroAttributes(tag: 'preview_${widget.images[i].url}'),
            ),
            loadingBuilder: (_, event) => const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_current + 1} / ${widget.images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
