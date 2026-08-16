import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';
import '../../core/utils/format.dart';

import '../../shared/models/collection.dart';
import '../../shared/models/ep.dart';
import '../../shared/models/subject.dart' as models;
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';
import 'collection_sheet.dart';

import '../rakuen/rakuen_providers.dart';
import '../rakuen/reviews_screen.dart';

import '../user/origin_setting_screen.dart';
import '../user/origin_utils.dart';
import '../user/smb_screen.dart';
import 'ep_menu.dart';
import 'subject_models.dart';
import 'subject_notes.dart';
import 'subject_providers.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/bgm_button.dart';
import 'tag_better.dart';

import 'subject_comments_screen.dart';

class SubjectScreen extends ConsumerStatefulWidget {
  final int id;

  const SubjectScreen({super.key, required this.id});

  @override
  ConsumerState<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends ConsumerState<SubjectScreen> {
  final _scroll = ScrollController();
  bool _compact = false;
  final _blockKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final next = _scroll.offset > 72;
      if (next != _compact) setState(() => _compact = next);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final detail = ref.watch(subjectDetailProvider(id));
    return Scaffold(
      appBar: BgmAppBar(
        showBackButton: true,
        title: '条目',
        titleWidget: _compact
            ? detail.maybeWhen(
                data: (value) => _SubjectHeaderTitle(detail: value),
                orElse: () => null,
              )
            : null,
        actions: [
          _SubjectLocationButton(onSelect: _scrollToBlock),
          _SubjectMenuButton(subjectId: id),
        ],
      ),

      body: detail.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) => BgmRetry(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(subjectDetailProvider(id)),
        ),
        data: (value) {
          final store = ref.watch(settingsStoreProvider);
          Widget block(String key, Widget child) {
            final mode = store.subjectBlock(key);
            if (mode == 'hide') return const SizedBox.shrink();
            final split = _subjectSplit(store.subjectSplitStyles, context);
            Widget body = child;
            if (mode == 'fold') {
              body = BgmExpand(
                title: switch (key) {
                  'showTags' => '标签',
                  'showSummary' => '简介',
                  'showInfo' => '详情',
                  'showThumbs' => '预览图',
                  'showRating' => '评分',
                  'showCharacter' => '角色',
                  'showStaff' => '制作人员',
                  'showAnitabi' => '取景地标',
                  'showRelations' => '关联',
                  'showCatalog' => '目录',
                  'showBlog' => '日志',
                  'showTopic' => '帖子',
                  'showLike' => '猜你喜欢',
                  'showRecent' => '动态',
                  'showComment' => '吐槽',
                  _ => '更多',
                },
                titlePadding: const EdgeInsets.symmetric(horizontal: AppGap.x8),
                children: [child],
              );
            }

            if (split == null) return body;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [split, body],
            );
          }

          return ListView(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: AppGap.x10),
            children: [
              _SubjectLockBanner(subjectId: id),
              _SubjectHeader(subjectId: id, detail: value),
              if (value.subject.type == 'music')
                _keyed('disc', _DiscSection(subjectId: id))
              else if (value.subject.type != 'game')
                _keyed('ep', _EpSection(subjectId: id)),
              _SmbSection(subjectId: id),
              if (value.tags.isNotEmpty)
                _keyed(
                  'tags',
                  block(
                    'showTags',
                    _TagSection(
                      subjectId: id,
                      type: value.subject.type,
                      tags: value.tags,
                    ),
                  ),
                ),
              _keyed(
                'summary',
                block(
                  'showSummary',
                  _SummarySection(
                    subjectId: id,
                    summary: value.subject.summary,
                  ),
                ),
              ),
              _keyed(
                'thumbs',
                block('showThumbs', _PreviewThumbsSection(subjectId: id)),
              ),
              _keyed(
                'info',
                block(
                  'showInfo',
                  _InfoPreviewSection(subjectId: id, detail: value),
                ),
              ),
              _keyed(
                'rating',
                block('showRating', _RatingPreviewSection(subjectId: id)),
              ),
              _keyed(
                'character',
                block('showCharacter', _CharacterSection(subjectId: id)),
              ),
              _keyed(
                'staff',
                block('showStaff', _PersonSection(subjectId: id)),
              ),
              _keyed(
                'anitabi',
                block('showAnitabi', _AnitabiSection(subjectId: id)),
              ),
              _keyed('comic', _ComicSection(subjectId: id)),
              _keyed(
                'relations',
                block('showRelations', _RelationSection(subjectId: id)),
              ),
              _keyed(
                'catalog',
                block('showCatalog', _CatalogPreviewSection(subjectId: id)),
              ),
              _keyed('like', block('showLike', _LikeSection(subjectId: id))),
              _keyed(
                'blog',
                block('showBlog', _ReviewPreviewSection(subjectId: id)),
              ),
              _keyed(
                'topic',
                block('showTopic', _TopicPreviewSection(subjectId: id)),
              ),
              _keyed(
                'recent',
                block('showRecent', _RecentSection(subjectId: id)),
              ),
              _keyed(
                'comment',
                block('showComment', _CommentSection(subjectId: id)),
              ),
            ],
          );
        },
      ),
    );
  }

  GlobalKey _keyOf(String id) => _blockKeys.putIfAbsent(id, GlobalKey.new);

  Widget _keyed(String id, Widget child) {
    return KeyedSubtree(key: _keyOf(id), child: child);
  }

  void _scrollToBlock(String id) {
    final key = _blockKeys[id];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }
}

class _SubjectLocationButton extends StatelessWidget {
  final ValueChanged<String> onSelect;

  const _SubjectLocationButton({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu_open),
      tooltip: '跳转到',
      onSelected: onSelect,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'ep', child: Text('章节')),
        PopupMenuItem(value: 'disc', child: Text('曲目列表')),
        PopupMenuItem(value: 'tags', child: Text('标签')),
        PopupMenuItem(value: 'summary', child: Text('简介')),
        PopupMenuItem(value: 'thumbs', child: Text('预览')),
        PopupMenuItem(value: 'info', child: Text('详情')),
        PopupMenuItem(value: 'rating', child: Text('评分')),
        PopupMenuItem(value: 'character', child: Text('角色')),
        PopupMenuItem(value: 'staff', child: Text('制作人员')),
        PopupMenuItem(value: 'anitabi', child: Text('取景地标')),
        PopupMenuItem(value: 'comic', child: Text('单行本')),
        PopupMenuItem(value: 'relations', child: Text('关联')),
        PopupMenuItem(value: 'catalog', child: Text('目录')),
        PopupMenuItem(value: 'like', child: Text('猜你喜欢')),
        PopupMenuItem(value: 'blog', child: Text('日志')),
        PopupMenuItem(value: 'topic', child: Text('帖子')),
        PopupMenuItem(value: 'recent', child: Text('动态')),
        PopupMenuItem(value: 'comment', child: Text('吐槽')),
      ],
    );
  }
}

class _SubjectHeaderTitle extends StatelessWidget {
  final SubjectDetail detail;

  const _SubjectHeaderTitle({required this.detail});

  @override
  Widget build(BuildContext context) {
    final subject = detail.subject;
    final infoRows = [
      for (final row in detail.infobox) (key: row.key, value: row.valueText),
    ];
    final label = subjectTitleLabel(
      typeText: detail.typeText,
      infobox: infoRows,
      tags: [for (final tag in subject.tags) tag.name],
    );
    final hideScore = SettingsStore.instance.hideScore;
    return Row(
      children: [
        Cover(
          url: subject.images.common,
          width: subject.type == 'music' ? 22 : 18,
          height: 22,
          radius: 4,
          type: subject.type,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [subject.displayName, if (label.isNotEmpty) label].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.ds.label,
              ),
              if (!hideScore && (subject.rating?.score ?? 0) > 0)
                Score(
                  score: subject.rating!.score,
                  total: subject.rating!.total,
                  fontSize: 10,
                  showTotal: false,
                )
              else if (subject.name.isNotEmpty &&
                  subject.name != subject.displayName)
                Text(
                  subject.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.ds.tiny,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget? _subjectSplit(String style, BuildContext context) {
  if (style == 'off' || style.isEmpty) return null;
  if (style.startsWith('line')) {
    return BgmHairline(
      height: style == 'line-2' ? 16 : 8,
      thickness: style == 'line-2' ? 2 : 1,
    );
  }

  final color = switch (style) {
    'title-warning' || 'underline-warning' => context.ds.star,
    'title-primary' || 'underline-primary' => context.ds.accent,
    'title-success' || 'underline-success' => context.ds.success,
    _ => context.ds.accent,
  };
  if (style.startsWith('underline')) {
    return Container(
      height: 3,
      margin: const EdgeInsets.fromLTRB(AppGap.x8, 12, AppGap.x8, 0),
      color: color,
    );
  }
  return Padding(
    padding: const EdgeInsets.fromLTRB(AppGap.x8, 12, AppGap.x8, 0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(width: 28, height: 4, color: color),
    ),
  );
}

/// 头部: 封面 + 名称 + 评分 + 收藏按钮 + 进度
class _SubjectHeader extends ConsumerWidget {
  final int subjectId;
  final SubjectDetail detail;

  const _SubjectHeader({required this.subjectId, required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = detail.subject;
    final store = ref.watch(settingsStoreProvider);
    final isLogin = ref.watch(isLoggedInProvider);
    final collection = ref.watch(collectionProvider(subjectId));
    final epStatus = ref.watch(epStatusProvider(subjectId));
    final eps = ref.watch(epListProvider(subjectId)).valueOrNull;

    final currentType = collection.valueOrNull?.type ?? 0;
    final epCount = subject.epsCount > 0 ? subject.epsCount : (eps?.total ?? 0);
    final watchedEps = eps == null
        ? 0
        : epStatus.valueOrNull?.progressOf(eps.eps) ?? 0;
    final infoRows = [
      for (final row in detail.infobox) (key: row.key, value: row.valueText),
    ];
    final tagNames = [for (final tag in subject.tags) tag.name];
    final titleLabel = subjectTitleLabel(
      typeText: detail.typeText,
      infobox: infoRows,
      tags: tagNames,
    );
    final headerDuration = subjectHeaderDuration(
      typeText: detail.typeText,
      infobox: infoRows,
      tags: tagNames,
      epDurations: [for (final ep in eps?.eps ?? const <Ep>[]) ep.duration],
    );
    final releaseText = subject.airDate.isNotEmpty
        ? subject.airDate
        : subjectReleaseText(infoRows);
    final year = store.subjectShowAirdayMonth
        ? subjectYearMonth(
            infobox: infoRows,
            year: subjectYear(infobox: infoRows, airDate: subject.airDate),
          )
        : subjectYear(infobox: infoRows, airDate: subject.airDate);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppGap.x8,
        AppGap.x6,
        AppGap.x8,
        AppGap.x6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Cover(
            url: subject.images.large,
            width: 110,
            height: 150,
            radius: AppRadius.m,
            type: subject.type,
          ),
          const SizedBox(width: AppGap.x7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subjectShowRelease(releaseText))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '$releaseText 上映',
                      style: context.ds.caption.copyWith(
                        color: context.ds.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                GestureDetector(
                  onLongPress: () => _copyTitle(context, subject.displayName),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: displayText(subject.displayName)),
                        if (year.isNotEmpty)
                          TextSpan(
                            text: ' ($year)',
                            style: context.ds.title.copyWith(
                              fontSize:
                                  visualFontSize(subject.displayName, const [
                                    (44, 10),
                                    (32, 11),
                                    (16, 12),
                                    (0, 15),
                                  ]) -
                                  3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    style: context.ds.title.copyWith(
                      fontSize: visualFontSize(subject.displayName, const [
                        (44, 10),
                        (32, 11),
                        (16, 12),
                        (0, 15),
                      ]),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                if (subject.name.isNotEmpty &&
                    subject.name != subject.nameCn) ...[
                  const SizedBox(height: 2),
                  GestureDetector(
                    onLongPress: () => _copyTitle(context, subject.name),
                    child: Text(
                      displayText(
                        [
                          subject.name,
                          titleLabel,
                        ].where((e) => e.isNotEmpty).join(' · '),
                      ),
                      style: context.ds.caption.copyWith(
                        fontSize: visualFontSize(
                          [subject.name, titleLabel].join(' · '),
                          const [(32, 10), (22, 11), (0, 12)],
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (store.subjectBlock('showRelation') != 'hide')
                  _SeriesChips(subjectId: subjectId),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _InfoChip(text: titleLabel),
                    if (!SettingsStore.instance.hideScore && subject.rank > 0)
                      _InfoChip(text: '排名 ${subject.rank}'),
                    if (subject.airDate.isNotEmpty)
                      _InfoChip(
                        text: formatSubjectAirDate(
                          subject.airDate,
                          showMonth: store.subjectShowAirdayMonth,
                        ),
                      ),
                    if (subject.airWeekday > 0)
                      _InfoChip(text: kWeekdayCnText(subject.airWeekday)),
                    if (subject.nsfw) const _InfoChip(text: 'NSFW'),
                    if (headerDuration.isNotEmpty)
                      _InfoChip(text: headerDuration),
                  ],
                ),

                if (!store.hideScore &&
                    subject.rating != null &&
                    subject.rating!.score > 0) ...[
                  const SizedBox(height: 6),
                  Score(
                    score: subject.rating!.score,
                    total: subject.rating!.total,
                    fontSize: 13,
                  ),
                ],
                if (!store.hideScore) _FriendScoreLine(subjectId: subjectId),

                if (subject.collection != null &&
                    subject.collection!.total > 0) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => context.push('/subject/$subjectId/rating'),
                    child: Text(
                      subject.collectionText,
                      style: context.ds.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // 5 状态收藏按钮组 (原项目 box 翻转按钮)
                Row(
                  children: [
                    for (final status in const [1, 2, 3, 4, 5])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _StatusButton(
                            status: status,
                            selected: currentType == status,
                            action: SubjectType.action(subject.type),
                            onTap: () =>
                                _setCollectionStatus(context, ref, status),
                          ),
                        ),
                      ),
                    InkWell(
                      onTap: () => _openCollectionSheet(context, ref),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.ds.surfaceCard,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: context.ds.border),
                        ),
                        child: Icon(
                          Icons.edit_note,
                          size: 18,
                          color: context.ds.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _SubjectOriginButton(subject: subject),
                  ],
                ),
                if (ref.watch(settingsStoreProvider).showCount &&
                    subject.collection != null &&
                    subject.collection!.total > 0) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => context.push('/subject/$subjectId/rating'),
                    child: Text(
                      _collectionDistributionText(
                        subject.collection!,
                        subject.type,
                      ),

                      style: context.ds.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if ((collection.valueOrNull?.comment ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _openCollectionSheet(context, ref),
                    child: Text(
                      collection.valueOrNull!.comment,
                      style: context.ds.caption,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (ref.watch(settingsStoreProvider).showEpInput &&
                    isLogin &&
                    subject.type == 'book') ...[
                  const SizedBox(height: 8),
                  _BookProgressInputs(
                    subjectId: subjectId,
                    chap: collection.valueOrNull?.epStatus ?? 0,
                    vol: collection.valueOrNull?.volStatus ?? 0,
                    totalChap: subject.eps,
                  ),
                ] else if (ref.watch(settingsStoreProvider).showEpInput &&
                    isLogin &&
                    epCount > 0) ...[
                  const SizedBox(height: 8),
                  _ProgressBar(
                    watched: watchedEps,
                    total: epCount,
                    onTap: () =>
                        _openProgressDialog(context, ref, watchedEps, epCount),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openCollectionSheet(BuildContext context, WidgetRef ref) {
    final isLogin = ref.read(isLoggedInProvider);
    if (!isLogin) {
      context.push('/login');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CollectionSheet(subjectId: subjectId),
    );
  }

  void _openProgressDialog(
    BuildContext context,
    WidgetRef ref,
    int watched,
    int total,
  ) {
    var value = watched.toDouble();
    showBgmDialog<void>(
      context: context,
      title: '设置观看进度',
      content: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('看到第 ${value.round()} 话 / 共 $total 话', style: context.ds.body),
            BgmSlider(
              value: value.clamp(0, total.toDouble()),
              max: total.toDouble(),
              divisions: total,
              label: '${value.round()}',
              onChanged: (v) => setLocal(() => value = v),
            ),
          ],
        ),
      ),
      actions: (ctx) => [
        BgmButton(
          '取消',
          type: BgmButtonType.plain,
          expand: false,
          onPressed: () => Navigator.pop(ctx),
        ),
        BgmButton(
          '保存',
          expand: false,
          onPressed: () async {
            try {
              await updateWatchedEpsAction(ref, subjectId, value.round());
              invalidateSubjectState(ref, subjectId);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                showBgmToast(
                  context,
                  '进度已更新',
                  duration: const Duration(seconds: 1),
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                showBgmToast(context, '更新失败: ${apiErrorMessage(e)}');
              }
            }
          },
        ),
      ],
    );
  }

  /// 点击状态按钮直接切换收藏状态
  Future<void> _setCollectionStatus(
    BuildContext context,
    WidgetRef ref,
    int status,
  ) async {
    if (!ref.read(isLoggedInProvider)) {
      await context.push('/login');
      return;
    }
    try {
      await updateCollectionAction(ref, subjectId, type: status);
      invalidateSubjectState(ref, subjectId);
      if (context.mounted) {
        showBgmToast(
          context,
          '已${SubjectType.statusText(status, detail.subject.type)}',
          duration: const Duration(seconds: 1),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showBgmToast(context, '操作失败: ${apiErrorMessage(e)}');
      }
    }
  }

  /// 收藏人数分布文案 (原项目 box 人数行)
  static String _collectionDistributionText(
    models.CollectionCount c, [
    String type = 'anime',
  ]) {
    final verb = SubjectType.action(type);
    final parts = <String>[
      if (c.wish > 0) '${c.wish} 想$verb',
      if (c.collect > 0) '${c.collect} $verb过',
      if (c.doing > 0) '${c.doing} 在$verb',
      if (c.onHold > 0) '${c.onHold} 搁置',
      if (c.dropped > 0) '${c.dropped} 抛弃',
    ];
    return parts.isEmpty ? '' : parts.join(' · ');
  }

  Future<void> _copyTitle(BuildContext context, String text) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    showBgmToast(context, '已复制标题', duration: const Duration(seconds: 1));
  }
}

class _SeriesChips extends ConsumerWidget {
  final int subjectId;

  const _SeriesChips({required this.subjectId});

  static const _priority = ['前传', '续集', '动画', '不同演绎', '书籍', '系列'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relations = ref
        .watch(subjectRelationsProvider(subjectId))
        .valueOrNull;
    if (relations == null || relations.isEmpty) {
      return const SizedBox.shrink();
    }
    final chips = <SubjectListItem>[];
    for (final label in _priority) {
      for (final item in relations) {
        if (item.relation == label && chips.every((e) => e.id != item.id)) {
          chips.add(item);
          break;
        }
      }
      if (chips.length >= 2) break;
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final item in chips)
            InkWell(
              onTap: () => context.push('/subject/${item.id}'),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
                decoration: BoxDecoration(
                  color: context.ds.surfaceCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.ds.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Cover(
                      url: item.images.grid,
                      width: 22,
                      height: 28,
                      radius: 3,
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.relation,
                            style: context.ds.tiny.copyWith(
                              color: context.ds.accent,
                            ),
                          ),
                          Text(
                            item.displayName,
                            style: context.ds.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 收藏状态按钮 (原项目 box 翻转按钮)
class _StatusButton extends StatelessWidget {
  final int status;
  final bool selected;
  final String action;
  final VoidCallback onTap;

  const _StatusButton({
    required this.status,
    required this.selected,
    required this.onTap,
    this.action = '看',
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.ds.accent : context.ds.surfaceCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? context.ds.accent : context.ds.border,
          ),
        ),
        child: Text(
          CollectionStatus.text(status).replaceAll('看', action),
          style: context.ds.caption.copyWith(
            color: selected ? Colors.white : context.ds.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

String kWeekdayCnText(int weekday) =>
    ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'][weekday.clamp(0, 7)];

class _InfoChip extends StatelessWidget {
  final String text;
  const _InfoChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.ds.textHint.withValues(alpha: 0.12),
        borderRadius: AppRadius.sAll,
      ),
      child: Text(text, style: context.ds.tiny),
    );
  }
}

class _FriendScoreLine extends ConsumerWidget {
  final int subjectId;

  const _FriendScoreLine({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = ref.watch(subjectHtmlExtrasProvider(subjectId)).valueOrNull;
    if (extras == null || extras.friendTotal <= 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '好友 ${extras.friendScore.toStringAsFixed(1)} · ${extras.friendTotal} 人评分',
        style: context.ds.meta,
      ),
    );
  }
}

/// 在看进度条
class _ProgressBar extends StatelessWidget {
  final int watched;
  final int total;
  final VoidCallback onTap;

  const _ProgressBar({
    required this.watched,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? watched / total : 0.0;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.sAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: context.ds.textHint.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 4),
          Text('看到第 $watched 话 / 共 $total 话 · 点击设置进度', style: context.ds.meta),
        ],
      ),
    );
  }
}

class _BookProgressInputs extends ConsumerStatefulWidget {
  final int subjectId;
  final int chap;
  final int vol;
  final int totalChap;

  const _BookProgressInputs({
    required this.subjectId,
    required this.chap,
    required this.vol,
    required this.totalChap,
  });

  @override
  ConsumerState<_BookProgressInputs> createState() =>
      _BookProgressInputsState();
}

class _BookProgressInputsState extends ConsumerState<_BookProgressInputs> {
  late final TextEditingController _chap = TextEditingController(
    text: '${widget.chap}',
  );
  late final TextEditingController _vol = TextEditingController(
    text: '${widget.vol}',
  );
  bool _saving = false;

  @override
  void didUpdateWidget(covariant _BookProgressInputs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chap != widget.chap) _chap.text = '${widget.chap}';
    if (oldWidget.vol != widget.vol) _vol.text = '${widget.vol}';
  }

  @override
  void dispose() {
    _chap.dispose();
    _vol.dispose();
    super.dispose();
  }

  Future<void> _save({int? chap, int? vol}) async {
    setState(() => _saving = true);
    try {
      await updateWatchedEpsAction(
        ref,
        widget.subjectId,
        chap ?? int.tryParse(_chap.text) ?? widget.chap,
        watchedVols: vol ?? int.tryParse(_vol.text) ?? widget.vol,
      );
      invalidateSubjectState(ref, widget.subjectId);
      if (mounted) {
        showBgmToast(context, '进度已更新', duration: const Duration(seconds: 1));
      }
    } catch (e) {
      if (mounted) {
        showBgmToast(context, '更新失败: ${apiErrorMessage(e)}');
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text('Chap.', style: context.ds.caption),
            const SizedBox(width: 6),
            SizedBox(
              width: 44,
              child: BgmField(
                controller: _chap,
                keyboardType: TextInputType.number,
                style: context.ds.label,
              ),
            ),
            if (widget.totalChap > 0)
              Text(' / ${widget.totalChap}', style: context.ds.caption),
            BgmHeaderAction(
              tooltip: 'Chap +1',
              icon: const Icon(Icons.add_circle_outline, size: 18),
              onPressed: _saving
                  ? null
                  : () => _save(chap: widget.chap + 1, vol: widget.vol),
            ),
          ],
        ),
        Row(
          children: [
            Text('Vol.', style: context.ds.caption),
            const SizedBox(width: 14),
            SizedBox(
              width: 44,
              child: BgmField(
                controller: _vol,
                keyboardType: TextInputType.number,
                style: context.ds.label,
              ),
            ),
            BgmHeaderAction(
              tooltip: 'Vol +1',
              icon: const Icon(Icons.add_circle_outline, size: 18),
              onPressed: _saving
                  ? null
                  : () => _save(chap: widget.chap, vol: widget.vol + 1),
            ),

            const Spacer(),
            BgmTextAction('更新', onPressed: _saving ? null : () => _save()),
          ],
        ),
      ],
    );
  }
}

/// 简介 (可展开)
class _SummarySection extends ConsumerStatefulWidget {
  final int subjectId;
  final String summary;
  const _SummarySection({required this.subjectId, required this.summary});

  @override
  ConsumerState<_SummarySection> createState() => _SummarySectionState();
}

class _SummarySectionState extends ConsumerState<_SummarySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.summary.isEmpty) return const SizedBox.shrink();
    final expandInPlace = ref.watch(settingsStoreProvider).subjectHtmlExpand;
    final text = widget.summary.replaceAll('\r\n', '\n').trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppGap.x8,
        AppGap.x4,
        AppGap.x8,
        AppGap.x2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '简介'),
          Text(
            text,
            style: context.ds.label.copyWith(height: 1.5),
            maxLines: expandInPlace && _expanded ? null : 4,
            overflow: expandInPlace && _expanded ? null : TextOverflow.ellipsis,
          ),
          if (text.length > 80)
            GestureDetector(
              onTap: () {
                if (expandInPlace) {
                  setState(() => _expanded = !_expanded);
                  return;
                }
                context.push('/subject/${widget.subjectId}/info');
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  expandInPlace ? (_expanded ? '收起' : '展开') : '查看全部',
                  style: context.ds.caption.copyWith(color: context.ds.accent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 曲目列表 (原项目 TITLE_DISC)
class _DiscSection extends ConsumerWidget {
  final int subjectId;

  const _DiscSection({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = ref.watch(subjectHtmlExtrasProvider(subjectId)).valueOrNull;
    final discs = extras?.discs ?? const <SubjectDisc>[];
    if (discs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGap.x8, AppGap.x6, AppGap.x8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: '曲目列表')),
              if (discs.length > 1)
                Text('${discs.length} Disc', style: context.ds.caption),
            ],
          ),
          for (final disc in discs) ...[
            if (disc.title.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(disc.title, style: context.ds.caption),
            ],
            for (var i = 0; i < disc.tracks.length; i++)
              InkWell(
                onTap: disc.tracks[i].epId > 0
                    ? () => context.push(
                        '/subject/$subjectId/ep/${disc.tracks[i].epId}/comments',
                      )
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text('${i + 1}', style: context.ds.meta),
                      ),
                      Expanded(
                        child: Text(
                          disc.tracks[i].title,
                          style: context.ds.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// 章节列表
class _EpSection extends ConsumerStatefulWidget {
  final int subjectId;
  const _EpSection({required this.subjectId});

  @override
  ConsumerState<_EpSection> createState() => _EpSectionState();
}

class _EpSectionState extends ConsumerState<_EpSection> {
  bool _reverse = false;

  @override
  Widget build(BuildContext context) {
    final subjectId = widget.subjectId;
    final epsAsync = ref.watch(epListProvider(subjectId));
    final eps = epsAsync.valueOrNull;
    if (eps == null || eps.eps.isEmpty) return const SizedBox.shrink();

    final epStatus = ref.watch(epStatusProvider(subjectId)).valueOrNull;
    final list = _reverse ? eps.eps.reversed.toList() : eps.eps;
    final shown = list.take(6).toList();
    final comments = [for (final ep in eps.eps) ep.comment];
    final heatMin = comments.isEmpty
        ? 0
        : comments.reduce((a, b) => a < b ? a : b);
    final heatMax = comments.isEmpty
        ? 1
        : comments.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppGap.x8,
            AppGap.x6,
            AppGap.x4,
            AppGap.x2,
          ),
          child: Row(
            children: [
              const Expanded(child: SectionHeader(title: '章节')),
              if (ref.watch(settingsStoreProvider).showCustomOnair)
                _SubjectOnAirChip(subjectId: subjectId),

              BgmHeaderAction(
                tooltip: _reverse ? '正序' : '倒序',
                icon: Icon(
                  Icons.swap_vert,
                  size: 20,
                  color: _reverse ? context.ds.accent : context.ds.textHint,
                ),
                onPressed: () => setState(() => _reverse = !_reverse),
              ),

              BgmTextAction(
                '全部',
                onPressed: () => context.push('/subject/$subjectId/episodes'),
              ),
            ],
          ),
        ),
        for (final ep in shown)
          _EpRow(
            subjectId: subjectId,
            ep: ep,
            watched: epStatus?.isWatched(ep.id) ?? false,
            heatMin: heatMin,
            heatMax: heatMax,
          ),

        if (eps.eps.length > shown.length)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppGap.x8),
            child: BgmTextAction(
              '查看全部 ${eps.eps.length} 话',
              onPressed: () => context.push('/subject/$subjectId/episodes'),
            ),
          ),
      ],
    );
  }
}

class _SubjectOnAirChip extends ConsumerWidget {
  final int subjectId;

  const _SubjectOnAirChip({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekday =
        ref
            .watch(subjectDetailProvider(subjectId))
            .valueOrNull
            ?.subject
            .airWeekday ??
        0;
    final custom = ref.watch(settingsStoreProvider).customOnAirOf(subjectId);
    var wd = weekday;
    var label = '放送';
    if (custom != null) {
      final parts = custom.split('|');
      wd = int.tryParse(parts.first) ?? weekday;
      final clock = parts.length > 1 && parts[1].length == 4
          ? '${parts[1].substring(0, 2)}:${parts[1].substring(2)}'
          : '';
      label = '${kWeekdayCn[wd % 7]}${clock.isEmpty ? '' : ' $clock'}';
    } else if (weekday > 0) {
      label = kWeekdayCn[weekday % 7];
    }
    return BgmTextAction(label, onPressed: () => _edit(context, ref, wd));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, int weekday) async {
    var wd = weekday <= 0 ? DateTime.now().weekday % 7 : weekday % 7;
    var hour = '20';
    var minute = '00';
    final custom = ref.read(settingsStoreProvider).customOnAirOf(subjectId);
    if (custom != null) {
      final parts = custom.split('|');
      wd = int.tryParse(parts.first) ?? wd;
      if (parts.length > 1 && parts[1].length == 4) {
        hour = parts[1].substring(0, 2);
        minute = parts[1].substring(2);
      }
    }
    final saved = await showBgmDialog<bool>(
      context: context,
      title: '自定义放送',
      content: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: BgmSelect<int>(
                value: wd,
                items: [for (var i = 0; i < 7; i++) (i, kWeekdayCn[i])],
                onChanged: (v) => setLocal(() => wd = v),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                BgmSelect<String>(
                  value: hour,
                  items: [
                    for (var h = 0; h < 24; h++)
                      (
                        h.toString().padLeft(2, '0'),
                        h.toString().padLeft(2, '0'),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => hour = v),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(':'),
                ),
                BgmSelect<String>(
                  value: minute,
                  items: const [
                    ('00', '00'),
                    ('15', '15'),
                    ('30', '30'),
                    ('45', '45'),
                  ],
                  onChanged: (v) => setLocal(() => minute = v),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: (ctx) => [
        BgmButton(
          '恢复默认',
          type: BgmButtonType.plain,
          expand: false,
          onPressed: () {
            ref.read(settingsStoreProvider).clearCustomOnAir(subjectId);
            Navigator.pop(ctx, false);
          },
        ),
        BgmButton(
          '保存',
          expand: false,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    );
    if (saved == true) {
      await ref
          .read(settingsStoreProvider)
          .setCustomOnAir(subjectId, wd, '$hour$minute');
    }
  }
}

/// 单集行: sort + 标题 + 日期 + 观看状态, 长按弹出操作菜单 (原项目 ep 长按菜单)
class _EpRow extends ConsumerWidget {
  final int subjectId;
  final Ep ep;
  final bool watched;
  final int heatMin;
  final int heatMax;

  const _EpRow({
    required this.subjectId,
    required this.ep,
    required this.watched,
    required this.heatMin,
    required this.heatMax,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLogin = ref.watch(isLoggedInProvider);
    final kind = epAirKind(ep.airdate, watched: watched);
    final color = switch (kind) {
      'watched' => context.ds.accent,
      'today' => context.ds.success,
      'na' => context.ds.textHint,
      _ => context.ds.textPrimary,
    };
    final heat = SettingsStore.instance.heatMap
        ? heatMapOpacity(ep.comment, min: heatMin, max: heatMax)
        : 0.0;
    return InkWell(
      onTap: () => context.push('/subject/$subjectId/ep/${ep.id}/comments'),
      onLongPress: isLogin ? () => _showEpMenu(context, ref) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Column(
                children: [
                  Text(
                    '${ep.sort}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (heat > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA000).withValues(alpha: heat),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ep.displayName.isEmpty ? '第 ${ep.sort} 话' : ep.displayName,
                    style: TextStyle(fontSize: 13, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (ep.airdate.isNotEmpty)
                    Text(
                      '${ep.airdate}${ep.duration.isNotEmpty ? ' · ${ep.duration}' : ''}',
                      style: context.ds.meta,
                    ),
                ],
              ),
            ),
            if (isLogin)
              BgmHeaderAction(
                tooltip: watched ? '取消看过' : '标记看过',
                icon: Icon(
                  watched ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20,
                  color: watched ? context.ds.accent : context.ds.textHint,
                ),
                onPressed: () async {
                  try {
                    await setEpStatusAction(
                      ref,
                      ep.id,
                      watched ? 'remove' : 'watched',
                    );

                    ref.invalidate(epStatusProvider(subjectId));
                  } catch (e) {
                    if (context.mounted) {
                      showBgmToast(context, '操作失败: ${apiErrorMessage(e)}');
                    }
                  }
                },
              ),

            Icon(Icons.chevron_right, size: 18, color: context.ds.textHint),
          ],
        ),
      ),
    );
  }

  Future<void> _showEpMenu(BuildContext context, WidgetRef ref) {
    return showEpActionMenu(
      context,
      ref,
      subjectId: subjectId,
      ep: ep,
      watched: watched,
    );
  }
}

/// 标签区块
class _TagSection extends ConsumerWidget {
  final int subjectId;
  final String type;
  final List<models.Tag> tags;
  const _TagSection({
    required this.subjectId,
    required this.type,
    required this.tags,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(settingsStoreProvider);
    final shown = store.subjectTagsExpand
        ? tags.take(10).toList()
        : const <models.Tag>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppGap.x8,
        AppGap.x5,
        AppGap.x8,
        AppGap.x2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: '标签')),
              BgmHeaderAction(
                tooltip: store.subjectTagsExpand ? '收起' : '展开',
                onPressed: () =>
                    store.setSubjectTagsExpand(!store.subjectTagsExpand),
                icon: Icon(
                  store.subjectTagsExpand
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
              ),
              BgmTextAction(
                '全部',
                onPressed: () => context.push('/subject/$subjectId/tag'),
              ),
            ],
          ),
          if (shown.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in shown)
                  GestureDetector(
                    onTap: () => context.push(
                      '/subject/$subjectId/typerank?tag=${Uri.encodeComponent(tag.name)}&type=$type',
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tag(text: tag.name),
                        TypeRankBetterText(
                          type: type,
                          tag: tag.name,
                          rank:
                              ref
                                  .watch(subjectDetailProvider(subjectId))
                                  .valueOrNull
                                  ?.subject
                                  .rank ??
                              0,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 角色横向列表
class _CharacterSection extends ConsumerWidget {
  final int subjectId;
  const _CharacterSection({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chars = ref.watch(subjectCharactersProvider(subjectId)).valueOrNull;
    if (chars == null || chars.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppGap.x8,
            AppGap.x6,
            AppGap.x4,
            AppGap.x2,
          ),
          child: Row(
            children: [
              const Expanded(child: SectionHeader(title: '角色')),
              BgmTextAction(
                '全部',
                onPressed: () => context.push('/subject/$subjectId/characters'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 170,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppGap.x8),
            scrollDirection: Axis.horizontal,
            itemCount: chars.take(12).length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final c = chars[i];
              return GestureDetector(
                onTap: () => context.push('/mono/character/${c.id}'),
                child: SizedBox(
                  width: 88,
                  child: Column(
                    children: [
                      Cover(
                        url: c.images.grid,
                        width: 88,
                        height: 110,
                        radius: 6,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.displayName,
                        style: context.ds.caption.copyWith(
                          color: context.ds.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (c.actors.isNotEmpty)
                        Text(
                          'CV: ${c.actors.first.displayName}',
                          style: context.ds.tiny,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 制作人员横向列表
class _PersonSection extends ConsumerWidget {
  final int subjectId;
  const _PersonSection({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persons = ref.watch(subjectPersonsProvider(subjectId)).valueOrNull;
    if (persons == null || persons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppGap.x8,
            AppGap.x6,
            AppGap.x4,
            AppGap.x2,
          ),
          child: Row(
            children: [
              const Expanded(child: SectionHeader(title: '制作人员')),
              BgmTextAction(
                '全部',
                onPressed: () => context.push('/subject/$subjectId/persons'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppGap.x8),
            scrollDirection: Axis.horizontal,
            itemCount: persons.take(12).length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final p = persons[i];
              return GestureDetector(
                onTap: () => context.push('/mono/person/${p.id}'),
                child: SizedBox(
                  width: 88,
                  child: Column(
                    children: [
                      Cover(
                        url: p.images.grid,
                        width: 88,
                        height: 110,
                        radius: 6,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.displayName,
                        style: context.ds.caption.copyWith(
                          color: context.ds.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p.relation.isNotEmpty)
                        Text(
                          p.relation,
                          style: context.ds.tiny,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 相关条目横向列表
class _RelationSection extends ConsumerWidget {
  final int subjectId;
  const _RelationSection({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relations = ref
        .watch(subjectRelationsProvider(subjectId))
        .valueOrNull;
    if (relations == null || relations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppGap.x8,
            AppGap.x6,
            AppGap.x4,
            AppGap.x2,
          ),
          child: Row(
            children: [
              const Expanded(child: SectionHeader(title: '关联')),
              BgmTextAction(
                '全部',
                onPressed: () => context.push('/subject/$subjectId/link'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 170,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppGap.x8),
            scrollDirection: Axis.horizontal,
            itemCount: relations.take(12).length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final r = relations[i];
              return GestureDetector(
                onTap: () => context.push('/subject/${r.id}'),
                child: SizedBox(
                  width: 88,
                  child: Column(
                    children: [
                      Cover(
                        url: r.images.common.isNotEmpty
                            ? r.images.common
                            : r.images.large,
                        width: 88,
                        height: 110,
                        radius: 6,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r.displayName,
                        style: context.ds.caption.copyWith(
                          color: context.ds.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (r.relation.isNotEmpty)
                        Text(
                          r.relation,
                          style: context.ds.tiny.copyWith(
                            color: context.ds.accent,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 截屏预览 (原项目 TITLE_THUMBS)
class _PreviewThumbsSection extends ConsumerWidget {
  final int subjectId;

  const _PreviewThumbsSection({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbs = ref.watch(previewProvider(subjectId)).valueOrNull;
    if (thumbs == null || thumbs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGap.x8, AppGap.x6, AppGap.x8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: '预览')),
              BgmTextAction(
                '全部',
                onPressed: () => context.push('/subject/$subjectId/preview'),
              ),
            ],
          ),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: thumbs.take(8).length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final url = thumbs[i].url;
                return GestureDetector(
                  onTap: () => context.push('/subject/$subjectId/preview'),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Cover(url: url, width: 140, height: 88, radius: 0),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 信息预览 (原项目 TITLE_INFO)
class _InfoPreviewSection extends ConsumerWidget {
  final int subjectId;
  final SubjectDetail detail;

  const _InfoPreviewSection({required this.subjectId, required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (detail.infobox.isEmpty) return const SizedBox.shrink();
    final store = ref.watch(settingsStoreProvider);
    final expandInPlace = store.subjectHtmlExpand;
    final source = store.subjectPromoteAlias
        ? promoteAliasRows(detail.infobox, keyOf: (e) => e.key)
        : detail.infobox;
    final rows = source.take(4).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGap.x8, AppGap.x6, AppGap.x8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: '详情')),
              BgmTextAction(
                '修订',
                onPressed: () => context.push('/subject/$subjectId/wiki'),
              ),
              BgmTextAction(
                expandInPlace ? '全部' : '查看全部',
                onPressed: () => context.push('/subject/$subjectId/info'),
              ),
            ],
          ),
          for (final item in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      item.key,
                      style: context.ds.caption.copyWith(
                        color: context.ds.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.valueText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.ds.label,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 评分预览 (原项目 TITLE_RATING)
class _RatingPreviewSection extends ConsumerStatefulWidget {
  final int subjectId;

  const _RatingPreviewSection({required this.subjectId});

  @override
  ConsumerState<_RatingPreviewSection> createState() =>
      _RatingPreviewSectionState();
}

class _RatingPreviewSectionState extends ConsumerState<_RatingPreviewSection> {
  late bool _showScore = !SettingsStore.instance.hideScore;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(ratingStatsProvider(widget.subjectId)).valueOrNull;
    if (stats == null || stats.total <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGap.x8, AppGap.x6, AppGap.x8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: '评分')),
              BgmTextAction(
                '全部',
                onPressed: () =>
                    context.push('/subject/${widget.subjectId}/rating'),
              ),
            ],
          ),
          if (_showScore)
            Row(
              children: [
                Text(
                  stats.score.toStringAsFixed(1),
                  style: context.ds.title.copyWith(color: context.ds.star),
                ),
                const SizedBox(width: 8),
                Stars(score: stats.score, size: 12),
                const SizedBox(width: 8),
                Text(
                  '${stats.total} 人${stats.rank > 0 ? ' · #${stats.rank}' : ''}',
                  style: context.ds.caption,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push(ratingDeviationNotePath()),
                  child: Text(
                    '标准差 ${stats.deviation.toStringAsFixed(2)} ${stats.dispute}',
                    style: context.ds.caption,
                  ),
                ),
              ],
            )
          else
            BgmTextAction(
              '评分已隐藏，点击显示',
              onPressed: () => setState(() => _showScore = true),
            ),
        ],
      ),
    );
  }
}

/// 目录预览 (原项目 TITLE_CATALOG)
class _CatalogPreviewSection extends ConsumerWidget {
  final int subjectId;

  const _CatalogPreviewSection({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogs = ref.watch(catalogsProvider(subjectId)).valueOrNull;
    if (catalogs == null || catalogs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGap.x8, AppGap.x6, AppGap.x8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: '目录')),
              BgmTextAction(
                '全部',
                onPressed: () => context.push('/subject/$subjectId/catalogs'),
              ),
            ],
          ),
          for (final c in catalogs.take(3))
            BgmTextRow(
              padding: EdgeInsets.zero,
              title: c.title,
              subtitle:
                  '${c.userName}${c.collected > 0 ? ' · ${c.collected} 收藏' : ''}',
              onTap: () => context.push('/catalog/${c.id}'),
            ),
        ],
      ),
    );
  }
}

/// 长评预览 (原项目 TITLE_BLOG / reviews)
class _ReviewPreviewSection extends ConsumerWidget {
  final int subjectId;

  const _ReviewPreviewSection({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(reviewsProvider(subjectId)).valueOrNull;
    if (data == null || data.reviews.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGap.x8, AppGap.x6, AppGap.x8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: '日志')),
              BgmTextAction(
                '全部',
                onPressed: () {
                  final name = ref
                      .read(subjectDetailProvider(subjectId))
                      .valueOrNull
                      ?.subject
                      .displayName;
                  context.push(reviewsPath(subjectId, name: name));
                },
              ),
            ],
          ),
          for (final r in data.reviews.take(3))
            BgmTextRow(
              padding: EdgeInsets.zero,
              title: r.title.isEmpty ? r.content : r.title,
              replies: r.replies,
              subtitle: r.user?.displayName,
              onTap: r.id > 0
                  ? () => context.push('/rakuen/blog/${r.id}')
                  : null,
            ),
        ],
      ),
    );
  }
}

/// 讨论版预览 (原项目 TITLE_TOPIC)
class _TopicPreviewSection extends ConsumerWidget {
  final int subjectId;

  const _TopicPreviewSection({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(subjectBoardProvider(subjectId)).valueOrNull;
    if (topics == null || topics.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGap.x8, AppGap.x6, AppGap.x8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: '帖子')),
              BgmTextAction(
                '全部',
                onPressed: () => context.push('/subject/$subjectId/board'),
              ),
            ],
          ),
          for (final t in topics.take(3))
            BgmTextRow(
              padding: EdgeInsets.zero,
              title: t.title,
              replies: t.replyCount,
              subtitle: t.userName,
              onTap: t.topicId.isEmpty
                  ? null
                  : () => context.push('/rakuen/topic/${t.topicId}'),
            ),
        ],
      ),
    );
  }
}

/// 巡礼地点 (原项目 TITLE_ANITABI)
class _AnitabiSection extends ConsumerWidget {
  final int subjectId;

  const _AnitabiSection({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spots = ref.watch(anitabiLiteProvider(subjectId)).valueOrNull;
    if (spots == null || spots.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGap.x8, AppGap.x6, AppGap.x8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: '取景地标')),
              BgmTextAction(
                '地图',
                onPressed: () => context.push(
                  '/web/${Uri.encodeComponent('https://anitabi.cn/map?bangumiId=$subjectId')}',
                ),
              ),
            ],
          ),
          for (final s in spots.take(5))
            BgmTextRow(
              padding: EdgeInsets.zero,
              title: s.name,
              subtitle: s.address.isEmpty ? null : s.address,
            ),
        ],
      ),
    );
  }
}

/// 本地文件夹收录 (原项目 TITLE_SMB)
class _SmbSection extends ConsumerWidget {
  final int subjectId;

  const _SmbSection({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(smbControllerProvider);
    final hits = [
      for (final f in folders)
        if (f.subjects.any((s) => s['id'] == subjectId)) f,
    ];
    if (hits.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGap.x8, AppGap.x6, AppGap.x8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: '本地')),
              BgmTextAction(
                '管理',
                onPressed: () => context.push('/settings/smb'),
              ),
            ],
          ),
          for (final f in hits)
            BgmTextRow(
              padding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_outlined, size: 20),
              title: f.name,
              subtitle: f.note.isEmpty ? null : f.note,
              onTap: () => context.push('/settings/smb/${f.id}'),
            ),
        ],
      ),
    );
  }
}

/// 锁定提示 (原项目 lock)
class _SubjectLockBanner extends ConsumerWidget {
  final int subjectId;

  const _SubjectLockBanner({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = ref.watch(subjectHtmlExtrasProvider(subjectId)).valueOrNull;
    if (extras == null || extras.lock.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(AppGap.x8, AppGap.x6, AppGap.x8, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.ds.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.ds.border),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: context.ds.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(extras.lock, style: context.ds.bodyStrong),
                const SizedBox(height: 4),
                Text(
                  '不符合收录原则，条目及相关收藏、讨论、关联等内容将会随时被移除',
                  style: context.ds.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 猜你喜欢 (原项目 like)
class _LikeSection extends ConsumerWidget {
  final int subjectId;

  const _LikeSection({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = ref.watch(subjectHtmlExtrasProvider(subjectId)).valueOrNull;
    if (extras == null || extras.likes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGap.x8, AppGap.x6, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '猜你喜欢'),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: AppGap.x8),
              itemCount: extras.likes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = extras.likes[index];
                return InkWell(
                  onTap: () => context.push('/subject/${item.id}'),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        Cover(
                          url: item.images.common,
                          width: 72,
                          height: 96,
                          radius: 4,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.ds.tiny,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 单行本 (原项目 TITLE_COMIC)
class _ComicSection extends ConsumerWidget {
  final int subjectId;

  const _ComicSection({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = ref.watch(subjectHtmlExtrasProvider(subjectId)).valueOrNull;
    final comics = extras?.comics ?? const <SubjectListItem>[];
    if (comics.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGap.x8, AppGap.x6, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: '单行本')),
              Padding(
                padding: const EdgeInsets.only(right: AppGap.x8),
                child: Text('${comics.length}', style: context.ds.caption),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: AppGap.x8),
              itemCount: comics.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = comics[index];
                return InkWell(
                  onTap: () => context.push('/subject/${item.id}'),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        Cover(
                          url: item.images.common,
                          width: 72,
                          height: 96,
                          radius: 4,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.ds.tiny,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 用户动态 / 谁在看 (原项目 TITLE_RECENT)
class _RecentSection extends ConsumerWidget {
  final int subjectId;

  const _RecentSection({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = ref.watch(subjectHtmlExtrasProvider(subjectId)).valueOrNull;
    if (extras == null || extras.recent.isEmpty) {
      return const SizedBox.shrink();
    }
    final store = ref.watch(settingsStoreProvider);
    final friends = store.subjectRecentType == '好友';
    final type =
        ref.watch(subjectDetailProvider(subjectId)).valueOrNull?.subject.type ??
        'anime';
    final action = SubjectType.action(type);
    final doings = friends
        ? ref
              .watch(
                subjectRatingProvider((
                  id: subjectId,
                  status: 'doings',
                  friends: true,
                )),
              )
              .valueOrNull
              ?.items
        : null;
    final collections = friends
        ? ref
              .watch(
                subjectRatingProvider((
                  id: subjectId,
                  status: 'collections',
                  friends: true,
                )),
              )
              .valueOrNull
              ?.items
        : null;
    final who = friends
        ? extraFriendsRecent(
            doings: doings ?? const [],
            collections: collections ?? const [],
            action: action,
          )
        : extras.recent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGap.x8, AppGap.x6, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: '动态',
            trailing: BgmSegmented<String>(
              values: const [('全站', '全站'), ('好友', '好友')],
              selected: store.subjectRecentType,
              onSelect: store.setSubjectRecentType,
            ),
          ),
          const SizedBox(height: 8),
          if (who.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppGap.x8, bottom: 8),
              child: Text('暂无好友动态', style: context.ds.caption),
            )
          else
            SizedBox(
              height: 68,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: AppGap.x8),
                itemCount: who.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final user = who[index];
                  return InkWell(
                    onTap: () => context.push('/user/${user.userId}'),
                    child: Row(
                      children: [
                        Avatar(url: user.avatar, size: 36),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 96),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.ds.label,
                              ),
                              Text(
                                user.status,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.ds.tiny,
                              ),
                              if (user.star > 0)
                                Stars(score: user.star.toDouble(), size: 9),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SubjectOriginButton extends ConsumerWidget {
  final models.Subject subject;

  const _SubjectOriginButton({required this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origins = originsForType(
      ref.watch(originConfigProvider).valueOrNull ?? const {},
      subject.type,
    );
    return PopupMenuButton<String>(
      tooltip: '源头',
      padding: EdgeInsets.zero,
      icon: Icon(Icons.cast, size: 20, color: context.ds.textSecondary),
      onSelected: (value) async {
        if (value == 'manage') {
          if (context.mounted) await context.push('/settings/origin');
          return;
        }
        final origin = origins.cast<OriginItem?>().firstWhere(
          (e) => e?.uuid == value,
          orElse: () => null,
        );
        if (origin == null) return;
        final year = RegExp(r'(\d{4})').firstMatch(subject.airDate)?.group(1);
        final url = replaceOriginUrl(
          origin.url,
          cn: subject.displayName,
          jp: subject.name.isEmpty ? subject.displayName : subject.name,
          id: subject.id,
          year: year ?? '',
        );
        if (url.isEmpty) return;
        if (context.mounted && SettingsStore.instance.openInfo) {
          showBgmToast(context, '已复制地址，即将跳转');
        }
        await openExternalUrl(url);
      },
      itemBuilder: (_) => [
        for (final o in origins)
          PopupMenuItem(value: o.uuid, child: Text(o.name)),
        const PopupMenuItem(value: 'manage', child: Text('源头管理')),
      ],
    );
  }
}

/// 吐槽箱预览
class _CommentSection extends ConsumerStatefulWidget {
  final int subjectId;
  const _CommentSection({required this.subjectId});

  @override
  ConsumerState<_CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends ConsumerState<_CommentSection> {
  String _interestType = '';
  String _score = '全部';
  bool _version = false;
  bool _reverse = false;

  @override
  Widget build(BuildContext context) {
    final comments = ref
        .watch(
          subjectCommentsProvider((
            id: widget.subjectId,
            page: 1,
            interestType: _interestType,
            version: _version,
          )),
        )
        .valueOrNull;
    if (comments == null || comments.items.isEmpty) {
      return const SizedBox.shrink();
    }
    final items = _reverse ? comments.items.reversed.toList() : comments.items;
    final visible = _score == '全部'
        ? items
        : [
            for (final item in items)
              if (_inScore(item.star, _score)) item,
          ];
    final type =
        ref
            .watch(subjectDetailProvider(widget.subjectId))
            .valueOrNull
            ?.subject
            .type ??
        'anime';
    final statusFilters = typedStatusFilters(type);
    final interestLabel = statusFilters
        .firstWhere((e) => e.$2 == _interestType, orElse: () => ('全部', ''))
        .$1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGap.x8, 0, AppGap.x8, AppGap.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SubjectCommentChrome(
            countLabel: '${comments.items.length}+',
            hasVersion: comments.hasVersion,
            version: _version,
            interestType: _interestType,
            interestLabel: interestLabel,
            statusFilters: statusFilters,
            score: _score,
            reverse: _reverse,
            extra: BgmTextAction(
              '全部',
              onPressed: () => context.push(
                subjectCommentsPath(
                  widget.subjectId,
                  interestType: _interestType,
                  score: _score,
                  version: _version,
                  reverse: _reverse,
                ),
              ),
            ),
            onVersion: () => setState(() {
              _version = !_version;
              _reverse = false;
            }),
            onStatus: (v) => setState(() {
              _interestType = v;
              _score = '全部';
              _reverse = false;
            }),
            onScore: (v) => setState(() => _score = v),
            onReverse: () => setState(() => _reverse = !_reverse),
          ),

          for (final c in visible.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Avatar(url: c.avatar, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayText(c.userName),
                                style: context.ds.meta.copyWith(
                                  color: context.ds.accent,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            UserAgeBadge(userId: c.userId),
                            if (c.star > 0) ...[
                              const SizedBox(width: 4),
                              Stars(score: c.star.toDouble(), size: 9),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayText(
                            ref.watch(settingsStoreProvider).commentSplit
                                ? c.content.replaceAll('/', '\n')
                                : c.content,
                          ),
                          style: context.ds.label.copyWith(height: 1.4),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

bool _inScore(int star, String score) {
  final parts = score.split('-');
  if (parts.length != 2) return true;
  final lo = int.tryParse(parts[0]) ?? 0;
  final hi = int.tryParse(parts[1]) ?? 10;
  return star >= lo && star <= hi;
}

/// 原版 MENU_DS: 浏览器查看〔id〕/ 复制链接 / 复制分享 / 拼图分享 / 客户端网页版本分享 / 设置
List<(String, String)> subjectMoreItems(int subjectId) => [
  ('web', '浏览器查看〔$subjectId〕'),
  ('copyLink', '复制链接'),
  ('copyShare', '复制分享'),
  ('share', '拼图分享'),
  ('webShare', '客户端网页版本分享'),
  ('actions', '跳转管理'),
  ('setting', '设置'),
];

/// 条目详情头部菜单 (原版 header/menu-component MENU_DS)
class _SubjectMenuButton extends ConsumerWidget {
  final int subjectId;

  const _SubjectMenuButton({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BgmHeaderMore(
      items: [for (final item in subjectMoreItems(subjectId)) item],
      onSelected: (value) => _handle(context, ref, value),
    );
  }

  void _handle(BuildContext context, WidgetRef ref, String value) {
    final id = subjectId;
    switch (value) {
      case 'web':
        context.push('/web/${Uri.encodeComponent('$kHost/subject/$id')}');
      case 'copyLink':
        Clipboard.setData(ClipboardData(text: '$kHost/subject/$id'));
        if (context.mounted) showBgmToast(context, '已复制链接');
      case 'copyShare':
        final detail = ref.read(subjectDetailProvider(id)).valueOrNull;
        final name = detail?.subject.displayName ?? '';
        final jp = detail?.subject.name ?? '';
        final label = name == jp ? name : '$name · $jp';
        Clipboard.setData(
          ClipboardData(text: '【链接】$label | Bangumi番组计划\n$kHost/subject/$id'),
        );
        if (context.mounted) showBgmToast(context, '已复制分享文案');
      case 'webShare':
        final detail = ref.read(subjectDetailProvider(id)).valueOrNull;
        final name = detail?.subject.displayName ?? '';
        final jp = detail?.subject.name ?? '';
        final label = name == jp || jp.isEmpty ? name : '$name · $jp';
        final url = 'https://bangumi-app.5t5.top/?id=$id';
        Clipboard.setData(
          ClipboardData(text: '【链接】$label | Bangumi番组计划\n$url'),
        );
        if (context.mounted) {
          showBgmToast(context, '已复制 APP 网页版地址');
          context.push('/web/${Uri.encodeComponent(url)}');
        }
      case 'share':
        context.push('/share/$id');
      case 'actions':
        final detail = ref.read(subjectDetailProvider(id)).valueOrNull;
        final name = detail?.subject.displayName ?? '';
        context.push(
          '/settings/actions${name.isEmpty ? '' : '?name=${Uri.encodeQueryComponent(name)}'}',
        );
      case 'setting':
        context.push('/settings');
    }
  }
}
