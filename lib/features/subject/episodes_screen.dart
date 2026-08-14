import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';
import '../../shared/models/ep.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';

import 'ep_menu.dart';
import 'subject_providers.dart';
import '../../design_system/design_system.dart';

/// 章节列表
/// 路由: /subject/:id/episodes
class EpisodesScreen extends ConsumerStatefulWidget {
  final int id;

  const EpisodesScreen({super.key, required this.id});

  @override
  ConsumerState<EpisodesScreen> createState() => _EpisodesScreenState();
}

class _EpisodesScreenState extends ConsumerState<EpisodesScreen> {
  bool _reverse = false;

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final epsAsync = ref.watch(epListProvider(id));
    return Scaffold(
      appBar: BgmAppBar(
        title: '章节',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: _reverse ? '正序' : '倒序',
            icon: Icon(
              Icons.swap_vert,
              color: _reverse ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () => setState(() => _reverse = !_reverse),
          ),
          IconButton(
            tooltip: '浏览器查看',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => openExternalUrl(htmlSubjectEpisodes(id)),
          ),
        ],
      ),
      body: epsAsync.when(
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
                onPressed: () => ref.invalidate(epListProvider(id)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (value) {
          List<Ep> maybeReverse(List<Ep> list) =>
              _reverse ? list.reversed.toList() : list;
          final all = [
            ...value.eps,
            ...value.type1,
            ...value.type2,
            ...value.type3,
            ...value.type4,
            ...value.type6,
          ];
          final comments = [for (final ep in all) ep.comment];
          final heatMin = comments.isEmpty
              ? 0
              : comments.reduce((a, b) => a < b ? a : b);
          final heatMax = comments.isEmpty
              ? 1
              : comments.reduce((a, b) => a > b ? a : b);
          final sections = <(String, List<Ep>)>[
            if (value.eps.isNotEmpty) ('本篇', maybeReverse(value.eps)),
            if (value.type1.isNotEmpty) ('特别篇', maybeReverse(value.type1)),
            if (value.type2.isNotEmpty) ('OP', maybeReverse(value.type2)),
            if (value.type3.isNotEmpty) ('ED', maybeReverse(value.type3)),
            if (value.type4.isNotEmpty) ('预告', maybeReverse(value.type4)),
            if (value.type6.isNotEmpty) ('SP', maybeReverse(value.type6)),
          ];
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _BatchBar(subjectId: id)),
              for (final (title, _) in sections)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              for (final (_, list) in sections)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _EpRow(
                      subjectId: id,
                      ep: list[i],
                      heatMin: heatMin,
                      heatMax: heatMax,
                    ),
                    childCount: list.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }
}

/// 批量管理入口
class _BatchBar extends ConsumerWidget {
  final int subjectId;
  const _BatchBar({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLogin = ref.watch(isLoggedInProvider);
    final eps = ref.watch(epListProvider(subjectId)).valueOrNull;
    final epStatus = ref.watch(epStatusProvider(subjectId)).valueOrNull;
    if (!isLogin || eps == null || eps.eps.isEmpty) {
      return const SizedBox.shrink();
    }

    final watched = epStatus?.progressOf(eps.eps) ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Text(
            '已看 $watched / ${eps.eps.length} 话',
            style: const TextStyle(fontSize: 13),
          ),
          const Spacer(),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
            ),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _BatchDialog(
                subjectId: subjectId,
                watched: watched,
                total: eps.eps.length,
              ),
            ),
            child: const Text('批量更新', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _BatchDialog extends ConsumerStatefulWidget {
  final int subjectId;
  final int watched;
  final int total;

  const _BatchDialog({
    required this.subjectId,
    required this.watched,
    required this.total,
  });

  @override
  ConsumerState<_BatchDialog> createState() => _BatchDialogState();
}

class _BatchDialogState extends ConsumerState<_BatchDialog> {
  late double _value = widget.watched.toDouble();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('批量更新进度'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('看到第 ${_value.round()} 话 / 共 ${widget.total} 话'),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting
              ? null
              : () async {
                  setState(() => _submitting = true);
                  try {
                    await updateWatchedEpsAction(
                      ref,
                      widget.subjectId,
                      _value.round(),
                    );
                    ref.invalidate(epStatusProvider(widget.subjectId));
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('进度已更新'),
                          duration: Duration(seconds: 1),
                        ),
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

/// 单集行
class _EpRow extends ConsumerWidget {
  final int subjectId;
  final Ep ep;
  final int heatMin;
  final int heatMax;

  const _EpRow({
    required this.subjectId,
    required this.ep,
    required this.heatMin,
    required this.heatMax,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLogin = ref.watch(isLoggedInProvider);
    final epStatus = ref.watch(epStatusProvider(subjectId)).valueOrNull;
    final watched = epStatus?.isWatched(ep.id) ?? false;
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
      onLongPress: isLogin
          ? () => showEpActionMenu(
              context,
              ref,
              subjectId: subjectId,
              ep: ep,
              watched: watched,
            )
          : null,

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 30,
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
                  ),
                  if (ep.nameCn.isNotEmpty &&
                      ep.name.isNotEmpty &&
                      ep.nameCn != ep.name)
                    Text(
                      ep.name,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (ep.airdate.isNotEmpty || ep.duration.isNotEmpty)
                    Text(
                      [
                        if (ep.airdate.isNotEmpty) '首播 ${ep.airdate}',
                        if (ep.duration.isNotEmpty) '时长 ${ep.duration}',
                        if (ep.comment > 0) '${ep.comment} 条吐槽',
                      ].join(' · '),
                      style: context.ds.meta,
                    ),
                  if (ep.desc.isNotEmpty)
                    Text(
                      ep.desc.replaceAll('\r\n', ' '),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                  color: watched
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
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
          ],
        ),
      ),
    );
  }
}
