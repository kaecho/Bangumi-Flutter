import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/display.dart';
import '../../shared/models/subject.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../subject/collection_sheet.dart';
import 'widgets/discovery_html.dart';
import 'widgets/paged.dart';
import 'widgets/subject_card.dart';
import '../../design_system/design_system.dart';

/// 目录详情信息
class IndexInfo {
  final int id;
  final String title;
  final String desc;
  final int total;
  final String username;
  final String avatar;
  final String updatedAt;

  const IndexInfo({
    this.id = 0,
    this.title = '',
    this.desc = '',
    this.total = 0,
    this.username = '',
    this.avatar = '',
    this.updatedAt = '',
  });

  factory IndexInfo.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>? ?? const {};
    return IndexInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      desc: json['desc'] as String? ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      username: creator['username'] as String? ?? '',
      avatar:
          creator['avatar']?['medium'] as String? ??
          creator['avatar']?['large'] as String? ??
          '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

/// 目录详情
final indexInfoProvider = FutureProvider.family<IndexInfo, int>((
  ref,
  id,
) async {
  final client = ref.read(apiClientProvider);
  final data = await client.get(apiV0Index(id));
  return IndexInfo.fromJson(data as Map<String, dynamic>);
});

/// 目录详情 HTML extras: 收藏 join/bye (对齐原版 cheerioCatalogDetail)
final catalogDetailExtraProvider =
    FutureProvider.family<CatalogDetailExtra, int>((ref, id) async {
      final client = ref.read(apiClientProvider);
      final html = await client.get(htmlCatalogDetail(id), host: kHost);
      return parseCatalogDetailExtra(html as String);
    });

class IndexSubjects extends PagedNotifier<Subject, int> {
  @override
  Future<List<Subject>> fetchPage(int arg, int page) async {
    final client = ref.read(apiClientProvider);
    final data = await client.get(
      apiV0IndexSubjects(arg, page: page, limit: 30),
    );
    final map = data as Map<String, dynamic>;
    final list = map['data'] as List? ?? const [];
    return list.whereType<Map<String, dynamic>>().map((e) {
      final images = e['images'] as Map<String, dynamic>? ?? const {};
      final type = switch (e['type']) {
        1 => 'book',
        4 => 'game',
        6 => 'real',
        _ => 'anime',
      };
      return Subject(
        id: (e['id'] as num?)?.toInt() ?? 0,
        name: e['name'] as String? ?? '',
        type: type,
        images: SubjectImages(
          large: images['large'] as String? ?? '',
          medium: images['medium'] as String? ?? '',
          small: images['small'] as String? ?? '',
        ),
      );
    }).toList();
  }
}

final indexSubjectsProvider =
    AsyncNotifierProvider.family<IndexSubjects, PagedData<Subject>, int>(
      IndexSubjects.new,
    );

/// 目录详情
class CatalogDetailScreen extends ConsumerStatefulWidget {
  final int id;

  const CatalogDetailScreen({super.key, required this.id});

  @override
  ConsumerState<CatalogDetailScreen> createState() =>
      _CatalogDetailScreenState();
}

class _CatalogDetailScreenState extends ConsumerState<CatalogDetailScreen> {
  bool _grid = true;
  bool _reverse = false;
  bool _collecting = false;

  Future<void> _toggleCollect(CatalogDetailExtra extra) async {
    final href = extra.collected ? extra.byeUrl : extra.joinUrl;
    if (href.isEmpty || _collecting) return;
    setState(() => _collecting = true);
    try {
      final client = ref.read(apiClientProvider);
      var url = href;
      if (url.startsWith('/')) url = '$kHost$url';
      await client.post(url, host: kHost);
      ref.invalidate(catalogDetailExtraProvider(widget.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(extra.collected ? '已取消收藏' : '已收藏')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('操作失败, 可能需要登录')));
      }
    } finally {
      if (mounted) setState(() => _collecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(indexInfoProvider(widget.id));
    final extra = ref.watch(catalogDetailExtraProvider(widget.id)).valueOrNull;
    return Scaffold(
      appBar: BgmAppBar(
        title: '目录详情',
        showBackButton: true,
        actions: [
          if (extra != null &&
              (extra.joinUrl.isNotEmpty || extra.byeUrl.isNotEmpty))
            IconButton(
              tooltip: extra.collected ? '取消收藏' : '收藏目录',
              icon: Icon(extra.collected ? Icons.star : Icons.star_border),
              onPressed: _collecting
                  ? null
                  : () => unawaited(_toggleCollect(extra)),
            ),
          IconButton(
            tooltip: _grid ? '列表' : '网格',
            icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _grid = !_grid),
          ),
          IconButton(
            tooltip: '倒序',
            icon: Icon(
              Icons.swap_vert,
              color: _reverse ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () => setState(() => _reverse = !_reverse),
          ),
          IconButton(
            tooltip: '复制链接',
            icon: const Icon(Icons.link),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: '$kHost/index/${widget.id}'),
              );
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已复制目录链接')));
            },
          ),
          IconButton(
            tooltip: '浏览器查看',

            icon: const Icon(Icons.open_in_browser),
            onPressed: () => openExternalUrl('$kHost/index/${widget.id}'),
          ),
        ],
      ),
      body: Column(
        children: [
          info.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Loading()),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (index) => _IndexHeader(info: index, extra: extra),
          ),
          Expanded(
            child: _grid && !_reverse
                ? PagedGridView<Subject, int>(
                    provider: indexSubjectsProvider,
                    arg: widget.id,
                    childAspectRatio: 0.58,
                    emptyText: '目录中暂无条目',
                    itemBuilder: (context, subject, index) =>
                        SubjectCard(subject: subject),
                  )
                : _CatalogSubjectsView(
                    id: widget.id,
                    grid: _grid,
                    reverse: _reverse,
                  ),
          ),
        ],
      ),
    );
  }
}

class _IndexHeader extends StatelessWidget {
  final IndexInfo info;
  final CatalogDetailExtra? extra;

  const _IndexHeader({required this.info, this.extra});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          if (info.desc.isNotEmpty)
            Text(
              info.desc,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.ds.caption,
            ),
          if (extra != null && extra!.progress.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(extra!.progress, style: context.ds.meta),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              if (info.avatar.isNotEmpty) ...[
                Avatar(url: info.avatar, size: 18),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  [
                    info.username,
                    '${info.total} 条目',
                    if (extra != null && extra!.collect.isNotEmpty)
                      extra!.collect,
                    '更新 ${info.updatedAt}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.ds.meta,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatalogSubjectsView extends ConsumerWidget {
  final int id;
  final bool grid;
  final bool reverse;

  const _CatalogSubjectsView({
    required this.id,
    required this.grid,
    required this.reverse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(indexSubjectsProvider(id));
    return async.when(
      loading: () => const Center(child: Loading()),
      error: (_, _) => Center(
        child: FilledButton.tonal(
          onPressed: () => ref.invalidate(indexSubjectsProvider(id)),
          child: const Text('重试'),
        ),
      ),
      data: (page) {
        final items = reverse ? page.items.reversed.toList() : page.items;
        if (items.isEmpty) {
          return const Center(child: Text('目录中暂无条目'));
        }
        if (grid) {
          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.58,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => SubjectCard(subject: items[index]),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final subject = items[index];
            return ListTile(
              leading: Cover(
                url: subject.images.medium.isNotEmpty
                    ? subject.images.medium
                    : subject.images.large,
                width: 40,
                height: 56,
                radius: 4,
              ),
              title: Text(subject.displayName, maxLines: 2),
              onTap: () => context.push('/subject/${subject.id}'),
              onLongPress: () => showCollectionSheet(context, subject.id),
            );
          },
        );
      },
    );
  }
}
