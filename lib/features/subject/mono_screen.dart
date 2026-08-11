import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';
import 'subject_models.dart';
import 'subject_providers.dart';

/// 角色 / 人物详情
/// 路由: /mono/character/:id, /mono/person/:id
class MonoScreen extends ConsumerWidget {
  final String type; // character | person
  final int id;

  const MonoScreen({super.key, required this.type, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(monoDetailProvider((type: type, id: id)));
    return Scaffold(
      appBar: BgmAppBar(
        title: type == 'person' ? '人物' : '角色',
        showBackButton: true,
      ),
      body: detail.when(
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
                onPressed: () =>
                    ref.invalidate(monoDetailProvider((type: type, id: id))),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _MonoHeader(type: type, detail: value),
            if (value.summary.isNotEmpty) _MonoSummary(summary: value.summary),
            if (value.infobox.isNotEmpty) _MonoInfobox(detail: value),
            _MonoWorks(type: type, id: id, displayName: value.displayName),
            if (type == 'character') _MonoComments(id: id),
          ],
        ),
      ),
    );
  }
}

class _MonoHeader extends StatelessWidget {
  final String type;
  final MonoDetail detail;

  const _MonoHeader({required this.type, required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Cover(url: detail.images.large, width: 100, height: 130, radius: 6),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.displayName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (detail.name.isNotEmpty && detail.name != detail.nameCn) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (detail.gender.isNotEmpty)
                      _MonoChip(text: '性别: ${detail.gender}'),
                    if (detail.birth.isNotEmpty) _MonoChip(text: '生日: ${detail.birth}'),
                    if (detail.bloodType.isNotEmpty) _MonoChip(text: '血型: ${detail.bloodType}'),
                    if (detail.career.isNotEmpty) _MonoChip(text: detail.career.join(' / ')),
                    if (detail.collects > 0) _MonoChip(text: '${detail.collects} 收藏'),
                    if (detail.comments > 0) _MonoChip(text: '${detail.comments} 吐槽'),
                  ],
                ),
                if (type == 'person')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          minimumSize: const Size(0, 32),
                        ),
                        onPressed: () => context.push('/subject/${detail.id}/works'),
                        child: const Text('全部作品', style: TextStyle(fontSize: 12)),
                      ),
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

class _MonoChip extends StatelessWidget {
  final String text;
  const _MonoChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _MonoSummary extends StatefulWidget {
  final String summary;
  const _MonoSummary({required this.summary});

  @override
  State<_MonoSummary> createState() => _MonoSummaryState();
}

class _MonoSummaryState extends State<_MonoSummary> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = widget.summary.replaceAll('\r\n', '\n').trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '简介'),
          Text(
            summary,
            style: const TextStyle(fontSize: 13, height: 1.6),
            maxLines: _expanded ? null : 5,
            overflow: _expanded ? null : TextOverflow.ellipsis,
          ),
          if (summary.length > 100)
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

class _MonoInfobox extends StatelessWidget {
  final MonoDetail detail;
  const _MonoInfobox({required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '信息'),
          for (final item in detail.infobox)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      item.key,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.valueText,
                      style: const TextStyle(fontSize: 12, height: 1.5),
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

class _MonoWorks extends ConsumerWidget {
  final String type;
  final int id;
  final String displayName;

  const _MonoWorks({required this.type, required this.id, required this.displayName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final works = ref.watch(monoSubjectsProvider((type: type, id: id))).valueOrNull;
    if (works == null || works.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: '出演作品 (${works.length})'),
          const SizedBox(height: 4),
          for (final item in works.take(8))
            InkWell(
              onTap: () => context.push('/subject/${item.id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Cover(url: item.images.common, width: 44, height: 60, radius: 4),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.displayName,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.date.isNotEmpty)
                            Text(
                              item.date,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (item.score > 0)
                      Text(
                        item.score.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),
          if (works.length > 8)
            TextButton(
              onPressed: () => context.push(
                type == 'person' ? '/subject/$id/works' : '/mono/character/$id/subjects',
              ),
              child: Text(
                '查看全部 ${works.length} 部作品',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonoComments extends ConsumerWidget {
  final int id;
  const _MonoComments({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final comments = ref.watch(monoCommentsProvider(id)).valueOrNull;
    if (comments == null || comments.items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '吐槽箱'),
          for (final c in comments.items.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
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
                            if (c.time.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                c.time,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.content,
                          style: const TextStyle(fontSize: 13, height: 1.4),
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
