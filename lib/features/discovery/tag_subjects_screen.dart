import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/models/subject.dart';
import '../../shared/widgets/app_bar.dart';
import 'widgets/discovery_html.dart';
import 'widgets/paged.dart';
import 'widgets/subject_card.dart';

/// 标签条目查询参数 (作为 family key)
class TagSubjectsQuery {
  final String type; // anime | book | real | game
  final String tag;

  const TagSubjectsQuery(this.type, this.tag);

  @override
  bool operator ==(Object other) =>
      other is TagSubjectsQuery && other.type == type && other.tag == tag;

  @override
  int get hashCode => Object.hash(type, tag);
}

class TagSubjects extends PagedNotifier<Subject, TagSubjectsQuery> {
  @override
  Future<List<Subject>> fetchPage(TagSubjectsQuery arg, int page) async {
    final client = ref.read(apiClientProvider);
    final body = await client.get(
      htmlTagSubjects(arg.type, arg.tag, page: page),
      host: kHost,
    );
    return parseSubjectList(body as String);
  }
}

final tagSubjectsProvider = AsyncNotifierProvider.family<TagSubjects, PagedData<Subject>, TagSubjectsQuery>(
  TagSubjects.new,
);

/// 标签条目列表 (/tags/:type/:tag)
class TagSubjectsScreen extends ConsumerWidget {
  final String type;
  final String tag;

  const TagSubjectsScreen({super.key, required this.type, required this.tag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: BgmAppBar(title: tag, showBackButton: true),
      body: PagedGridView<Subject, TagSubjectsQuery>(
        provider: tagSubjectsProvider,
        arg: TagSubjectsQuery(type, tag),
        childAspectRatio: 0.58,
        emptyText: '该标签下暂无条目',
        itemBuilder: (context, subject, index) => SubjectCard(
          subject: subject,
          rank: subject.rank > 0 ? subject.rank : null,
        ),
      ),
    );
  }
}
