import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/models/subject.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/avatar.dart';
import '../../shared/widgets/loading.dart';
import 'widgets/paged.dart';
import 'widgets/subject_card.dart';

/// 目录详情信息
class IndexInfo {
  final int id;
  final String title;
  final String desc;
  final int total;
  final String username;
  final String avatar;
  final String updatedAt;

  const IndexInfo({
    this.id = 0,
    this.title = '',
    this.desc = '',
    this.total = 0,
    this.username = '',
    this.avatar = '',
    this.updatedAt = '',
  });

  factory IndexInfo.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>? ?? const {};
    return IndexInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      desc: json['desc'] as String? ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      username: creator['username'] as String? ?? '',
      avatar: creator['avatar']?['medium'] as String? ?? creator['avatar']?['large'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

/// 目录详情
final indexInfoProvider = FutureProvider.family<IndexInfo, int>((ref, id) async {
  final client = ref.read(apiClientProvider);
  final data = await client.get(apiV0Index(id));
  return IndexInfo.fromJson(data as Map<String, dynamic>);
});

class IndexSubjects extends PagedNotifier<Subject, int> {
  @override
  Future<List<Subject>> fetchPage(int arg, int page) async {
    final client = ref.read(apiClientProvider);
    final data = await client.get(apiV0IndexSubjects(arg, page: page, limit: 30));
    final map = data as Map<String, dynamic>;
    final list = map['data'] as List? ?? const [];
    return list.whereType<Map<String, dynamic>>().map((e) {
      final images = e['images'] as Map<String, dynamic>? ?? const {};
      final type = switch (e['type']) {
        1 => 'book',
        4 => 'game',
        6 => 'real',
        _ => 'anime',
      };
      return Subject(
        id: (e['id'] as num?)?.toInt() ?? 0,
        name: e['name'] as String? ?? '',
        type: type,
        images: SubjectImages(
          large: images['large'] as String? ?? '',
          medium: images['medium'] as String? ?? '',
          small: images['small'] as String? ?? '',
        ),
      );
    }).toList();
  }
}

final indexSubjectsProvider =
    AsyncNotifierProvider.family<IndexSubjects, PagedData<Subject>, int>(IndexSubjects.new);

/// 目录详情
class CatalogDetailScreen extends ConsumerWidget {
  final int id;

  const CatalogDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(indexInfoProvider(id));
    return Scaffold(
      appBar: BgmAppBar(title: '目录详情', showBackButton: true),
      body: Column(
        children: [
          info.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Loading()),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (index) => _IndexHeader(info: index),
          ),
          Expanded(
            child: PagedGridView<Subject, int>(
              provider: indexSubjectsProvider,
              arg: id,
              childAspectRatio: 0.58,
              emptyText: '目录中暂无条目',
              itemBuilder: (context, subject, index) =>
                  SubjectCard(subject: subject),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndexHeader extends StatelessWidget {
  final IndexInfo info;

  const _IndexHeader({required this.info});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          if (info.desc.isNotEmpty)
            Text(
              info.desc,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (info.avatar.isNotEmpty) ...[
                Avatar(url: info.avatar, size: 18),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  '${info.username} · ${info.total} 条目 · 更新 ${info.updatedAt}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
