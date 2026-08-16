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

/// 角色列表
/// 路由: /subject/:id/characters
class CharactersScreen extends ConsumerWidget {
  final int id;

  const CharactersScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chars = ref.watch(subjectCharactersProvider(id));
    final name = ref
        .watch(subjectDetailProvider(id))
        .valueOrNull
        ?.subject
        .displayName;
    return Scaffold(
      appBar: BgmAppBar(
        title: extraNamedTitle(
          name,
          '更多角色',
          named: (n) => '$n的角色',
          count: chars.valueOrNull?.length,
        ),
        showBackButton: true,
        actions: [
          BgmHeaderMore.browser(
            () => openExternalUrl(htmlSubjectCharacters(id)),
          ),
        ],
      ),


      body: chars.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) => BgmRetry(
          onRetry: () => ref.invalidate(subjectCharactersProvider(id)),
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
