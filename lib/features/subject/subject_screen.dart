import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/models/collection.dart';
import '../../shared/models/ep.dart';
import '../../shared/models/subject.dart' as models;
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';
import 'collection_sheet.dart';
import 'subject_models.dart';
import 'subject_providers.dart';

/// 条目详情主页面
/// 路由: /subject/:id
class SubjectScreen extends ConsumerWidget {
  final int id;

  const SubjectScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(subjectDetailProvider(id));
    return Scaffold(
      appBar: BgmAppBar(showBackButton: true),
      body: detail.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 8),
              const Text('加载失败'),
              const SizedBox(height: 8),
              Text(apiErrorMessage(e), style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(subjectDetailProvider(id)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _SubjectHeader(subjectId: id, detail: value),
            _SummarySection(summary: value.subject.summary),
            if (value.subject.type != 'game')
              _EpSection(subjectId: id),
            if (value.tags.isNotEmpty)
              _TagSection(subjectId: id, type: value.subject.type, tags: value.tags),
            _CharacterSection(subjectId: id),
            _PersonSection(subjectId: id),
            _RelationSection(subjectId: id),
            _CommentSection(subjectId: id),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// 头部: 封面 + 名称 + 评分 + 收藏按钮 + 进度
class _SubjectHeader extends ConsumerWidget {
  final int subjectId;
  final SubjectDetail detail;

  const _SubjectHeader({required this.subjectId, required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = detail.subject;
    final theme = Theme.of(context);
    final isLogin = ref.watch(isLoggedInProvider);
    final collection = ref.watch(collectionProvider(subjectId));
    final epStatus = ref.watch(epStatusProvider(subjectId));
    final eps = ref.watch(epListProvider(subjectId)).valueOrNull;

    final currentType = collection.valueOrNull?.type ?? 0;
    final epCount = subject.epsCount > 0 ? subject.epsCount : (eps?.total ?? 0);
    final watchedEps = eps == null ? 0 : epStatus.valueOrNull?.progressOf(eps.eps) ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Cover(url: subject.images.large, width: 110, height: 150, radius: 6),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.displayName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subject.name.isNotEmpty && subject.name != subject.nameCn) ...[
                  const SizedBox(height: 2),
                  Text(
                    subject.name,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _InfoChip(text: detail.typeText),
                    if (subject.rank > 0) _InfoChip(text: '排名 ${subject.rank}'),
                    if (subject.airDate.isNotEmpty) _InfoChip(text: subject.airDate),
                    if (subject.airWeekday > 0)
                      _InfoChip(text: kWeekdayCnText(subject.airWeekday)),
                  ],
                ),
                if (subject.rating != null && subject.rating!.score > 0) ...[
                  const SizedBox(height: 6),
                  Score(
                    score: subject.rating!.score,
                    total: subject.rating!.total,
                    fontSize: 13,
                  ),
                ],
                if (subject.collection != null && subject.collection!.total > 0) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => context.push('/subject/$subjectId/rating'),
                    child: Text(
                      subject.collectionText,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          minimumSize: const Size(0, 36),
                        ),
                        onPressed: () => _openCollectionSheet(context, ref),
                        child: Text(CollectionStatus.actionText(currentType)),
                      ),
                    ),
                  ],
                ),
                if (isLogin && epCount > 0) ...[
                  const SizedBox(height: 8),
                  _ProgressBar(
                    watched: watchedEps,
                    total: epCount,
                    onTap: () => _openProgressDialog(context, ref, watchedEps, epCount),
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
      BuildContext context, WidgetRef ref, int watched, int total) {
    showDialog<void>(
      context: context,
      builder: (_) => _BatchProgressDialog(
        subjectId: subjectId,
        watched: watched,
        total: total,
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}

/// 在看进度条
class _ProgressBar extends StatelessWidget {
  final int watched;
  final int total;
  final VoidCallback onTap;

  const _ProgressBar({required this.watched, required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = total > 0 ? watched / total : 0.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '看到第 $watched 话 / 共 $total 话 · 点击设置进度',
            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 批量设置进度对话框
class _BatchProgressDialog extends ConsumerStatefulWidget {
  final int subjectId;
  final int watched;
  final int total;

  const _BatchProgressDialog({
    required this.subjectId,
    required this.watched,
    required this.total,
  });

  @override
  ConsumerState<_BatchProgressDialog> createState() => _BatchProgressDialogState();
}

class _BatchProgressDialogState extends ConsumerState<_BatchProgressDialog> {
  late double _value = widget.watched.toDouble();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置观看进度'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '看到第 ${_value.round()} 话 / 共 ${widget.total} 话',
            style: const TextStyle(fontSize: 14),
          ),
          Slider(
            value: _value.clamp(0, widget.total.toDouble()),
            max: widget.total.toDouble(),
            divisions: widget.total,
            label: '${_value.round()}',
            onChanged: (v) => setState(() => _value = v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: _submitting
              ? null
              : () async {
                  setState(() => _submitting = true);
                  try {
                    await updateWatchedEpsAction(ref, widget.subjectId, _value.round());
                    invalidateSubjectState(ref, widget.subjectId);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('进度已更新'), duration: Duration(seconds: 1)),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('更新失败: ${apiErrorMessage(e)}')),
                      );
                    }
                  }
                  if (mounted) setState(() => _submitting = false);
                },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

/// 简介 (可展开)
class _SummarySection extends StatefulWidget {
  final String summary;
  const _SummarySection({required this.summary});

  @override
  State<_SummarySection> createState() => _SummarySectionState();
}

class _SummarySectionState extends State<_SummarySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.summary.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final summary = widget.summary.replaceAll('\r\n', '\n').trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '简介'),
          Text(
            summary,
            style: const TextStyle(fontSize: 13, height: 1.5),
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? null : TextOverflow.ellipsis,
          ),
          if (summary.length > 80)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _expanded ? '收起' : '展开',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 章节列表
class _EpSection extends ConsumerWidget {
  final int subjectId;
  const _EpSection({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final epsAsync = ref.watch(epListProvider(subjectId));
    final eps = epsAsync.valueOrNull;
    if (eps == null || eps.eps.isEmpty) return const SizedBox.shrink();

    final epStatus = ref.watch(epStatusProvider(subjectId)).valueOrNull;
    final shown = eps.eps.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              const Expanded(child: SectionHeader(title: '章节')),
              TextButton(
                onPressed: () => context.push('/subject/$subjectId/episodes'),
                child: const Text('全部', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        for (final ep in shown)
          _EpRow(subjectId: subjectId, ep: ep, watched: epStatus?.isWatched(ep.id) ?? false),
        if (eps.eps.length > shown.length)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: () => context.push('/subject/$subjectId/episodes'),
              child: Text(
                '查看全部 ${eps.eps.length} 话',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.primary),
              ),
            ),
          ),
      ],
    );
  }
}

/// 单集行: sort + 标题 + 日期 + 观看状态
class _EpRow extends ConsumerWidget {
  final int subjectId;
  final Ep ep;
  final bool watched;

  const _EpRow({required this.subjectId, required this.ep, required this.watched});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLogin = ref.watch(isLoggedInProvider);
    final color = watched ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: () => context.push('/subject/$subjectId/ep/${ep.id}/comments'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '${ep.sort}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: watched ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ep.displayName.isEmpty ? '第 ${ep.sort} 话' : ep.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      color: watched ? color : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (ep.airdate.isNotEmpty)
                    Text(
                      '${ep.airdate}${ep.duration.isNotEmpty ? ' · ${ep.duration}' : ''}',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            if (isLogin)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: watched ? '取消看过' : '标记看过',
                icon: Icon(
                  watched ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20,
                  color: watched ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
                onPressed: () async {
                  try {
                    await setEpStatusAction(ref, ep.id, !watched);
                    ref.invalidate(epStatusProvider(subjectId));
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('操作失败: ${apiErrorMessage(e)}')),
                      );
                    }
                  }
                },
              ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

/// 标签区块
class _TagSection extends ConsumerWidget {
  final int subjectId;
  final String type;
  final List<models.Tag> tags;
  const _TagSection({required this.subjectId, required this.type, required this.tags});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = tags.take(10).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: '标签')),
              TextButton(
                onPressed: () => context.push('/subject/$subjectId/tag'),
                child: const Text('全部', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in shown)
                GestureDetector(
                  onTap: () => context.push(
                    '/subject/$subjectId/typerank?tag=${Uri.encodeComponent(tag.name)}&type=$type',
                  ),
                  child: Tag(text: tag.name),
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
    final theme = Theme.of(context);
    final chars = ref.watch(subjectCharactersProvider(subjectId)).valueOrNull;
    if (chars == null || chars.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              const Expanded(child: SectionHeader(title: '角色')),
              TextButton(
                onPressed: () => context.push('/subject/$subjectId/characters'),
                child: const Text('全部', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 170,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      Cover(url: c.images.grid, width: 88, height: 110, radius: 6),
                      const SizedBox(height: 6),
                      Text(
                        c.displayName,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (c.actors.isNotEmpty)
                        Text(
                          'CV: ${c.actors.first.displayName}',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
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

/// 制作人员横向列表
class _PersonSection extends ConsumerWidget {
  final int subjectId;
  const _PersonSection({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final persons = ref.watch(subjectPersonsProvider(subjectId)).valueOrNull;
    if (persons == null || persons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              const Expanded(child: SectionHeader(title: '制作人员')),
              TextButton(
                onPressed: () => context.push('/subject/$subjectId/persons'),
                child: const Text('全部', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      Cover(url: p.images.grid, width: 88, height: 110, radius: 6),
                      const SizedBox(height: 6),
                      Text(
                        p.displayName,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p.relation.isNotEmpty)
                        Text(
                          p.relation,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
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

/// 相关条目横向列表
class _RelationSection extends ConsumerWidget {
  final int subjectId;
  const _RelationSection({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final relations = ref.watch(subjectRelationsProvider(subjectId)).valueOrNull;
    if (relations == null || relations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              const Expanded(child: SectionHeader(title: '相关条目')),
              TextButton(
                onPressed: () => context.push('/subject/$subjectId/link'),
                child: const Text('全部', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 170,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      Cover(url: r.images.grid, width: 88, height: 110, radius: 6),
                      const SizedBox(height: 6),
                      Text(
                        r.displayName,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (r.relation.isNotEmpty)
                        Text(
                          r.relation,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.primary,
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

/// 吐槽箱预览
class _CommentSection extends ConsumerWidget {
  final int subjectId;
  const _CommentSection({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final comments = ref.watch(subjectCommentsProvider((id: subjectId, page: 1))).valueOrNull;
    if (comments == null || comments.items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: '吐槽箱')),
              TextButton(
                onPressed: () => context.push('/subject/$subjectId/comments'),
                child: const Text('全部', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          for (final c in comments.items.take(3))
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
                                c.userName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.primary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (c.star > 0) ...[
                              const SizedBox(width: 4),
                              Stars(score: c.star.toDouble(), size: 9),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.content,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                          maxLines: 3,
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
