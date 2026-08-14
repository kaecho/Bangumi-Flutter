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

/// 角色列表
/// 路由: /subject/:id/characters
class CharactersScreen extends ConsumerWidget {
  final int id;

  const CharactersScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chars = ref.watch(subjectCharactersProvider(id));
    return Scaffold(
      appBar: BgmAppBar(
        title: '角色',
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
        data: (list) => list.isEmpty
            ? const Empty(text: '暂无角色')
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.62,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) => _CharacterCard(character: list[i]),
              ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final CharacterVo character;
  const _CharacterCard({required this.character});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.push('/mono/character/${character.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Cover(
            url: character.images.large,
            width: double.infinity,
            height: 132,
            radius: 6,
          ),
          const SizedBox(height: 6),
          Text(
            character.displayName,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (character.relation.isNotEmpty)
            Text(
              character.relation,
              style: TextStyle(fontSize: 10, color: theme.colorScheme.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (character.actors.isNotEmpty)
            Text(
              'CV: ${character.actors.map((a) => a.displayName).join(' / ')}',
              style: context.ds.tiny,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
