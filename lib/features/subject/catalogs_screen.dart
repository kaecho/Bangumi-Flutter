import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';
import 'subject_models.dart';
import 'subject_providers.dart';

/// 包含该条目的目录
/// 路由: /subject/:id/catalogs
class CatalogsScreen extends ConsumerWidget {
  final int id;

  const CatalogsScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogs = ref.watch(catalogsProvider(id));
    return Scaffold(
      appBar: BgmAppBar(title: '目录', showBackButton: true),
      body: catalogs.when(
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
                onPressed: () => ref.invalidate(catalogsProvider(id)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? const Empty(text: '暂无目录收录')
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (_, i) => _CatalogRow(item: items[i]),
              ),
      ),
    );
  }
}

class _CatalogRow extends StatelessWidget {
  final CatalogItem item;
  const _CatalogRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Avatar(url: item.userAvatar, size: 40),
      title: Text(
        item.title,
        style: const TextStyle(fontSize: 14),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          [
            if (item.userName.isNotEmpty) item.userName,
            if (item.collected > 0) '${item.collected} 收藏',
            if (item.updatedAt.isNotEmpty) '更新于 ${item.updatedAt}',
          ].join(' · '),
          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      onTap: () => openCatalog(context, item),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
    );
  }

  void openCatalog(BuildContext context, CatalogItem item) {
    // 目录详情页在其他模块实现前, 使用内置浏览器打开
    context.push('/web/${Uri.encodeComponent('https://bgm.tv/index/${item.id}')}');
  }
}
