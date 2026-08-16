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
import 'subject_notes.dart';

import '../../design_system/design_system.dart';
import '../../shared/widgets/bgm_button.dart';

/// 章节列表
/// 路由: /subject/:id/episodes
class EpisodesScreen extends ConsumerStatefulWidget {
  final int id;

  const EpisodesScreen({super.key, required this.id});

  @override
  ConsumerState<EpisodesScreen> createState() => _EpisodesScreenState();
}

class _EpisodesScreenState extends ConsumerState<EpisodesScreen> {
  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final epsAsync = ref.watch(epListProvider(id));
    final name = ref
        .watch(subjectDetailProvider(id))
        .valueOrNull
        ?.subject
        .displayName;
    return Scaffold(
      appBar: BgmAppBar(
        title: extraNamedTitle(name, '章节', named: (n) => '$n的章节'),
        showBackButton: true,
        actions: [
          BgmHeaderMore.browser(() => openExternalUrl(htmlSubjectEpisodes(id))),
        ],
      ),
      body: epsAsync.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) =>
            BgmRetry(onRetry: () => ref.invalidate(epListProvider(id))),
        data: (value) {
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
            if (value.eps.isNotEmpty) ('本篇', value.eps),
            if (value.type1.isNotEmpty) ('特别篇', value.type1),
            if (value.type2.isNotEmpty) ('OP', value.type2),
            if (value.type3.isNotEmpty) ('ED', value.type3),
            if (value.type4.isNotEmpty) ('预告', value.type4),
            if (value.type6.isNotEmpty) ('SP', value.type6),
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
          BgmButton(
            '批量更新',
            type: BgmButtonType.plain,
            expand: false,
            onPressed: () => _showBatchUpdate(
              context,
              ref,
              subjectId,
              watched,
              eps.eps.length,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showBatchUpdate(
  BuildContext context,
  WidgetRef ref,
  int subjectId,
  int watched,
  int total,
) {
  var value = watched.toDouble();
  return showBgmDialog<void>(
    context: context,
    title: '批量更新进度',
    content: StatefulBuilder(
      builder: (ctx, setLocal) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('看到第 ${value.round()} 话 / 共 $total 话'),
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
            ref.invalidate(epStatusProvider(subjectId));
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
              BgmHeaderAction(
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
                    await setEpStatusAction(
                      ref,
                      ep.id,
                      watched ? 'remove' : 'watched',
                    );

                    ref.invalidate(epStatusProvider(subjectId));
                  } catch (e) {
                    if (context.mounted) {
                      showBgmToast(context, '操作失败: $e');
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
