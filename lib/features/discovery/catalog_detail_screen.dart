import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/site_cookies.dart';
import '../../core/utils/display.dart';
import '../../core/utils/url_match.dart';

import '../../core/utils/format.dart';
import '../../shared/models/subject.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../subject/collection_sheet.dart';
import 'widgets/discovery_html.dart';
import 'widgets/paged.dart';
import 'widgets/subject_card.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/bgm_button.dart';

/// 原版目录详情 HeaderV2Popover DATA
List<(String, String)> catalogDetailMoreItems() => const [
  ('copy', '复制并创建目录'),
  ('browser', '浏览器查看'),
  ('spa', '网页版查看'),
];

/// 原版 headerTitle: getVisualLength >= 14 → 12, 否则 14
double catalogDetailTitleSize(String title) =>
    getVisualLength(title) >= 14 ? 12 : 14;

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
  bool _copying = false;
  String _sort = '0';
  String _collect = 'all';
  String _type = '动画';

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
        showBgmToast(context, extra.collected ? '已取消收藏' : '已收藏');
      }
    } catch (_) {
      if (mounted) {
        showBgmToast(context, '操作失败, 可能需要登录');
      }
    } finally {
      if (mounted) setState(() => _collecting = false);
    }
  }

  Future<void> _copyCatalog() async {
    if (_copying) return;
    String gh;
    try {
      gh = await ref.read(formhashProvider.future);
    } catch (_) {
      gh = '';
    }
    if (gh.isEmpty) {
      if (mounted) showBgmToast(context, '请先登录');
      return;
    }
    if (!mounted) return;
    final ok = await showBgmConfirm(
      context,
      title: '复制目录',
      message: '复制当前目录成为自己的目录, 此操作会大量消耗服务器资源, 请勿滥用, 确定?',
    );
    if (!ok || !mounted) return;
    setState(() => _copying = true);
    try {
      final client = ref.read(apiClientProvider);
      final info = ref.read(indexInfoProvider(widget.id)).valueOrNull;
      final created = await client.postSiteRaw(htmlCatalogCreate(), {
        'formhash': gh,
        'title': info?.title ?? '',
        'desc': stripHtml(info?.desc ?? ''),
        'submit': '创建目录',
      });
      final createdId = parseCreatedCatalogId(created.location ?? '');
      if (createdId == null || createdId == 0) {
        if (mounted) showBgmToast(context, '目录创建失败, 请检查登录状态');
        return;
      }
      if (mounted) showBgmToast(context, '创建成功, 开始复制数据...');
      final page = ref.read(indexSubjectsProvider(widget.id)).valueOrNull;
      final items = page?.items ?? const <Subject>[];
      for (var i = 0; i < items.length; i++) {
        if (!mounted) return;
        showBgmToast(context, '${i + 1} / ${items.length}');
        await client.post(
          htmlCatalogAddRelated(createdId),
          host: kHost,
          data: {
            'formhash': gh,
            'cat': '0',
            'add_related': '${items[i].id}',
            'submit': '添加条目关联',
          },
        );
      }
      if (!mounted) return;
      showBgmToast(context, '已完成');
      await context.push('/catalog/$createdId');
    } catch (e) {
      if (mounted) {
        showBgmToast(context, '复制失败: ${apiErrorMessage(e)}');
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extra = ref.watch(catalogDetailExtraProvider(widget.id)).valueOrNull;
    final info = ref.watch(indexInfoProvider(widget.id)).valueOrNull;
    return Scaffold(
      appBar: BgmAppBar(
        title: '目录详情',
        titleWidget: info == null ? null : _CatalogDetailTitle(info: info),
        showBackButton: true,
        actions: [
          if (extra != null &&
              (extra.joinUrl.isNotEmpty || extra.byeUrl.isNotEmpty))
            BgmHeaderAction(
              tooltip: extra.collected ? '取消收藏' : '收藏目录',
              icon: Icon(extra.collected ? Icons.star : Icons.star_border),
              onPressed: _collecting
                  ? null
                  : () => unawaited(_toggleCollect(extra)),
            ),
          BgmHeaderMore(
            items: catalogDetailMoreItems(),
            onSelected: (value) {
              if (value == 'copy') {
                unawaited(_copyCatalog());
                return;
              }
              if (value == 'browser') {
                openExternalUrl(htmlCatalogDetail(widget.id));
                return;
              }
              if (value == 'spa') {
                openExternalUrl(htmlSpaCatalogDetail(widget.id));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          ref
              .watch(indexInfoProvider(widget.id))
              .when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Loading()),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (index) => _IndexHeader(
                  catalogId: widget.id,
                  info: index,
                  extra: extra,
                  type: _type,
                  onType: (v) => setState(() => _type = v),
                ),
              ),
          _CatalogDetailToolBar(
            grid: _grid,
            reverse: _reverse,
            sort: _sort,
            collect: _collect,
            showCollect: extra?.subjects.isNotEmpty == true,
            onToggleLayout: () => setState(() => _grid = !_grid),
            onToggleReverse: () => setState(() => _reverse = !_reverse),
            onSort: (v) => setState(() => _sort = v),
            onCollect: (v) => setState(() => _collect = v),
          ),
          Expanded(
            child: _CatalogBody(
              id: widget.id,
              extra: extra,
              type: _type,
              grid: _grid,
              reverse: _reverse,
              sort: _sort,
              collect: _collect,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogDetailTitle extends StatelessWidget {
  final IndexInfo info;

  const _CatalogDetailTitle({required this.info});

  @override
  Widget build(BuildContext context) {
    final title = info.title.isEmpty ? '目录详情' : info.title;
    return Row(
      children: [
        if (info.avatar.isNotEmpty) ...[
          Avatar(url: info.avatar, size: 28, name: info.username),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.ds.section.copyWith(
              fontSize: catalogDetailTitleSize(title),
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _IndexHeader extends StatelessWidget {
  final int catalogId;
  final IndexInfo info;
  final CatalogDetailExtra? extra;
  final String type;
  final ValueChanged<String> onType;

  const _IndexHeader({
    required this.catalogId,
    required this.info,
    this.extra,
    required this.type,
    required this.onType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final types = extra == null
        ? const <(String, int)>[]
        : catalogTypeData(extra!);
    final reply = extra == null ? '' : catalogReplyText(extra!.replyCount);
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
          const SizedBox(height: 8),
          Row(
            children: [
              BgmTextAction(
                reply.isEmpty ? '留言' : '留言 ($reply)',
                onPressed: () =>
                    context.push(catalogCommentsWebPath(catalogId)),
              ),
              Text(' · ', style: context.ds.caption),
              BgmTextAction(
                'TA 的其他目录',
                onPressed: extra == null || extra!.userId.isEmpty
                    ? null
                    : () => context.push('/user/${extra!.userId}/catalogs'),
              ),
            ],
          ),
          if (types.length > 1) ...[
            const SizedBox(height: 8),
            BgmSegmented<String>(
              expand: true,
              values: [for (final t in types) (t.$1, '${t.$1} ${t.$2}')],
              selected: types.any((t) => t.$1 == type) ? type : types.first.$1,
              onSelect: onType,
            ),
          ],
        ],
      ),
    );
  }
}

class _CatalogDetailToolBar extends StatelessWidget {
  final bool grid;
  final bool reverse;
  final String sort;
  final String collect;
  final bool showCollect;
  final VoidCallback onToggleLayout;
  final VoidCallback onToggleReverse;
  final ValueChanged<String> onSort;
  final ValueChanged<String> onCollect;

  const _CatalogDetailToolBar({
    required this.grid,
    required this.reverse,
    required this.sort,
    required this.collect,
    required this.showCollect,
    required this.onToggleLayout,
    required this.onToggleReverse,
    required this.onSort,
    required this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.ds.surfaceBase,
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            BgmSelect<String>(
              value: sort,
              items: kCatalogSorts,
              onChanged: onSort,
              tooltip: '排序',
            ),
            const SizedBox(width: 8),
            BgmTextAction(grid ? '网格' : '列表', onPressed: onToggleLayout),
            if (showCollect) ...[
              const SizedBox(width: 8),
              BgmSelect<String>(
                value: collect,
                items: kCatalogCollects,
                onChanged: onCollect,
                tooltip: '收藏范围',
              ),
            ],
            const SizedBox(width: 8),
            BgmTextAction(reverse ? '倒序' : '正序', onPressed: onToggleReverse),
          ],
        ),
      ),
    );
  }
}

class _CatalogBody extends ConsumerWidget {
  final int id;
  final CatalogDetailExtra? extra;
  final String type;
  final bool grid;
  final bool reverse;
  final String sort;
  final String collect;

  const _CatalogBody({
    required this.id,
    required this.extra,
    required this.type,
    required this.grid,
    required this.reverse,
    required this.sort,
    required this.collect,
  });

  List<CatalogExtraItem> _typed(CatalogDetailExtra extra) => switch (type) {
    '角色' => extra.characters,
    '人物' => extra.persons,
    '小组' => extra.topics,
    '章节' => extra.eps,
    '日志' => extra.blogs,
    _ => const [],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (extra != null && type != '动画') {
      final items = _typed(extra!);
      final shown = reverse ? items.reversed.toList() : items;
      if (shown.isEmpty) {
        return const Center(child: Text('目录中暂无条目'));
      }
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: shown.length,
        separatorBuilder: (_, _) => const BgmHairline(),
        itemBuilder: (context, index) {
          final item = shown[index];
          final route = item.href.isEmpty
              ? null
              : bgmUrlToRoute(
                  item.href.startsWith('http')
                      ? item.href
                      : '$kHost${item.href}',
                );
          return BgmTextRow(
            leading: Cover(url: item.image, width: 40, height: 56, radius: 4),
            title: item.title,
            subtitle: item.info.isEmpty ? null : item.info,
            onTap: route == null ? null : () => context.push(route),
          );
        },
      );
    }

    final async = ref.watch(indexSubjectsProvider(id));
    return async.when(
      loading: () => const Center(child: Loading()),
      error: (_, _) =>
          BgmRetry(onRetry: () => ref.invalidate(indexSubjectsProvider(id))),
      data: (page) {
        var items = extra != null && extra!.subjects.isNotEmpty
            ? extra!.subjects
            : page.items;
        items = catalogFilterCollect(items, collect);
        items = catalogSortSubjects(items, sort);
        if (reverse) items = items.reversed.toList();
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
          separatorBuilder: (_, _) => const BgmHairline(),
          itemBuilder: (context, index) {
            final subject = items[index];
            return BgmTextRow(
              leading: Cover(
                url: subject.images.medium.isNotEmpty
                    ? subject.images.medium
                    : subject.images.large,
                width: 40,
                height: 56,
                radius: 4,
              ),
              title: subject.displayName,
              onTap: () => context.push('/subject/${subject.id}'),
              onLongPress: () => showCollectionSheet(context, subject.id),
            );
          },
        );
      },
    );
  }
}
