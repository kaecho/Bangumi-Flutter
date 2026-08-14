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
import '../../design_system/design_system.dart';

/// 声优 (条目内各角色的配音演员)
/// 路由: /subject/:id/voices
class VoicesScreen extends ConsumerWidget {
  final int id;

  const VoicesScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chars = ref.watch(subjectCharactersProvider(id));
    return Scaffold(
      appBar: BgmAppBar(
        title: '声优',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: '浏览器查看',
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => openExternalUrl(htmlSubjectCharacters(id)),
          ),
        ],
      ),

      body: chars.when(
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
                onPressed: () => ref.invalidate(subjectCharactersProvider(id)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (list) {
          final voices = <(ActorVo, String)>[]; // (声优, 角色名)
          for (final c in list) {
            for (final actor in c.actors) {
              voices.add((actor, c.displayName));
            }
          }
          if (voices.isEmpty) return const Empty(text: '暂无声优信息');
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: voices.length,
            itemBuilder: (_, i) {
              final (actor, charName) = voices[i];
              return InkWell(
                onTap: () => context.push('/mono/person/${actor.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Cover(
                        url: actor.images.medium,
                        width: 48,
                        height: 60,
                        radius: 4,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              actor.displayName,
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              '配音角色: $charName',
                              style: context.ds.meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: context.ds.textHint,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
