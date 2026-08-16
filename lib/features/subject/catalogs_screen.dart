import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';

import 'subject_models.dart';
import 'subject_providers.dart';
import 'subject_notes.dart';

import '../../design_system/design_system.dart';
import '../../shared/widgets/bgm_button.dart';

/// 包含该条目的目录
/// 路由: /subject/:id/catalogs
class CatalogsScreen extends ConsumerWidget {
  final int id;

  const CatalogsScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogs = ref.watch(catalogsProvider(id));
    final name = ref
        .watch(subjectDetailProvider(id))
        .valueOrNull
        ?.subject
        .displayName;
    return Scaffold(
      appBar: BgmAppBar(
        title: extraNamedTitle(name, '条目目录', named: (n) => '包含$n的目录'),
        showBackButton: true,
        actions: [
          BgmHeaderMore.browser(() => openExternalUrl(htmlSubjectCatalogs(id))),
        ],
      ),

      body: catalogs.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) =>
            BgmRetry(onRetry: () => ref.invalidate(catalogsProvider(id))),
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
    return BgmTextRow(
      leading: Avatar(url: item.userAvatar, size: 40),
      title: item.title,
      subtitle: [
        if (item.userName.isNotEmpty) item.userName,
        if (item.collected > 0) '${item.collected} 收藏',
        if (item.updatedAt.isNotEmpty) '更新于 ${item.updatedAt}',
      ].join(' · '),
      onTap: () => openCatalog(context, item),
      trailing: Icon(Icons.chevron_right, size: 18, color: context.ds.textHint),
    );
  }

  void openCatalog(BuildContext context, CatalogItem item) {
    context.push('/catalog/${item.id}');
  }
}
