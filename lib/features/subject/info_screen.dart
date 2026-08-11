import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/subject.dart' hide Tag;
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/score.dart';
import 'subject_models.dart';
import 'subject_providers.dart';

/// 条目信息
/// 路由: /subject/:id/info
class SubjectInfoScreen extends ConsumerWidget {
  final int id;

  const SubjectInfoScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(subjectDetailProvider(id));
    return Scaffold(
      appBar: BgmAppBar(title: '条目信息', showBackButton: true),
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
                onPressed: () => ref.invalidate(subjectDetailProvider(id)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _InfoHeader(detail: value),
            const Divider(height: 32),
            if (value.infobox.isNotEmpty) ...[
              const Text('信息', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final item in value.infobox) _InfoboxRow(item: item),
              const Divider(height: 32),
            ],
            if (value.subject.summary.isNotEmpty) ...[
              const Text('简介', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                value.subject.summary.replaceAll('\r\n', '\n').trim(),
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
              const Divider(height: 32),
            ],
            if (value.tags.isNotEmpty) ...[
              const Text('标签', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in value.tags)
                    GestureDetector(
                      onTap: () => context.push(
                        '/subject/$id/typerank?tag=${Uri.encodeComponent(tag.name)}',
                      ),
                      child: Tag(text: '${tag.name} (${tag.count})'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoHeader extends StatelessWidget {
  final SubjectDetail detail;
  const _InfoHeader({required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = detail.subject;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Cover(url: subject.images.common, width: 90, height: 122, radius: 6),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subject.displayName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if (subject.name.isNotEmpty && subject.name != subject.nameCn)
                Text(
                  subject.name,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              const SizedBox(height: 6),
              Text(
                '${detail.typeText}${subject.rank > 0 ? ' · 排名 ${subject.rank}' : ''}'
                '${subject.airDate.isNotEmpty ? ' · ${subject.airDate}' : ''}',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
              if (subject.rating != null && subject.rating!.score > 0) ...[
                const SizedBox(height: 6),
                Score(score: subject.rating!.score, total: subject.rating!.total, fontSize: 13),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoboxRow extends StatelessWidget {
  final Infobox item;
  const _InfoboxRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              item.key,
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(item.valueText, style: const TextStyle(fontSize: 13, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
