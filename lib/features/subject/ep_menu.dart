import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';
import '../../shared/models/ep.dart';
import 'subject_providers.dart';

/// 章节长按菜单 (原项目 doEpsSelect / getPopoverData)
Future<void> showEpActionMenu(
  BuildContext context,
  WidgetRef ref, {
  required int subjectId,
  required Ep ep,
  required bool watched,
  VoidCallback? onChanged,
  String title = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            dense: true,
            title: Text(
              '${ep.sort}. ${ep.displayName}',
              style: context.ds.bodyStrong,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.arrow_upward),
            title: Text(watched ? '撤销看过' : '标记看过'),
            onTap: () => unawaited(
              _runEpStatus(
                context,
                ctx,
                ref,
                subjectId: subjectId,
                epId: ep.id,
                status: watched ? 'remove' : 'watched',
                onChanged: onChanged,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: const Text('想看'),
            onTap: () => unawaited(
              _runEpStatus(
                context,
                ctx,
                ref,
                subjectId: subjectId,
                epId: ep.id,
                status: 'queue',
                onChanged: onChanged,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('抛弃'),
            onTap: () => unawaited(
              _runEpStatus(
                context,
                ctx,
                ref,
                subjectId: subjectId,
                epId: ep.id,
                status: 'drop',
                onChanged: onChanged,
              ),
            ),
          ),

          if (ep.type == 0)
            ListTile(
              leading: const Icon(Icons.checklist),
              title: Text('看到第 ${ep.sort} 话'),
              subtitle: const Text('更新观看进度到本集', style: TextStyle(fontSize: 11)),
              onTap: () async {
                Navigator.of(ctx).pop();
                final apply = ep.sort <= 24
                    ? true
                    : await showDialog<bool>(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              title: Text('确认看到${ep.sort}集?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogCtx, false),
                                  child: const Text('取消'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogCtx, true),
                                  child: const Text('确认'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                if (!apply) return;
                try {
                  await updateWatchedEpsAction(ref, subjectId, ep.sort);
                  ref.invalidate(epStatusProvider(subjectId));
                  ref.invalidate(collectionProvider(subjectId));
                  onChanged?.call();
                  if (context.mounted) {
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
                      SnackBar(content: Text('操作失败: ${apiErrorMessage(e)}')),
                    );
                  }
                }
              },
            ),
          if (canAddEpCalendar(
            type: ep.type,
            airdate: ep.airdate,
            watched: watched,
          ))
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('添加提醒'),
              onTap: () {
                Navigator.of(ctx).pop();
                final custom = SettingsStore.instance.customOnAirOf(subjectId);
                final clock = custom != null && custom.contains('|')
                    ? custom.split('|').last
                    : '2000';
                final resolved = title.isNotEmpty
                    ? title
                    : (ref
                              .read(subjectDetailProvider(subjectId))
                              .valueOrNull
                              ?.subject
                              .displayName ??
                          '条目 $subjectId');
                unawaited(
                  shareSubjectIcs(
                    subjectId: subjectId,
                    title: resolved,
                    clock: clock,
                    eps: [
                      (
                        id: ep.id,
                        sort: ep.sort,
                        name: ep.displayName,
                        airdate: ep.airdate,
                      ),
                    ],
                  ),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.forum_outlined),
            title: Text(ep.comment > 0 ? '本集讨论 (+${ep.comment})' : '本集讨论'),
            onTap: () {
              Navigator.of(ctx).pop();
              context.push('/subject/$subjectId/ep/${ep.id}/comments');
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _runEpStatus(
  BuildContext context,
  BuildContext sheetCtx,
  WidgetRef ref, {
  required int subjectId,
  required int epId,
  required String status,
  VoidCallback? onChanged,
}) async {
  Navigator.of(sheetCtx).pop();
  try {
    await setEpStatusAction(ref, epId, status);
    ref.invalidate(epStatusProvider(subjectId));
    onChanged?.call();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: ${apiErrorMessage(e)}')),
      );
    }
  }
}

