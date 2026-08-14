import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/storage/settings_store.dart';
import '../../../core/utils/display.dart';
import '../../../shared/models/subject.dart';
import 'discovery_html.dart';
import 'paged.dart';
import 'subject_card.dart';

/// 条目浏览器查询 (作为 family key; basePath 不含 page)
class BrowserQuery {
  final String basePath;
  const BrowserQuery(this.basePath);

  @override
  bool operator ==(Object other) =>
      other is BrowserQuery && other.basePath == basePath;

  @override
  int get hashCode => basePath.hashCode;
}

/// 通用条目浏览器数据 (主站 HTML 列表页)
class BrowserResults extends PagedNotifier<Subject, BrowserQuery> {
  @override
  Future<PagedData<Subject>> build(BrowserQuery arg) {
    ref.watch(settingsStoreProvider.select((s) => s.filter18x));
    return super.build(arg);
  }

  @override
  Future<List<Subject>> fetchPage(BrowserQuery arg, int page) async {
    final client = ref.read(apiClientProvider);
    final sep = arg.basePath.contains('?') ? '&' : '?';
    final body = await client.get(
      '${arg.basePath}$sep'
      'page=$page',
      host: kHost,
    );
    final items = parseSubjectList(body as String);
    if (!SettingsStore.instance.filter18x) return items;
    return [
      for (final item in items)
        if (!isSensitiveSubject(
          nsfw: item.nsfw,
          name: item.name,
          nameCn: item.nameCn,
        ))
          item,
    ];
  }
}

final browserResultsProvider =
    AsyncNotifierProvider.family<
      BrowserResults,
      PagedData<Subject>,
      BrowserQuery
    >(BrowserResults.new);

/// 通用条目浏览器网格 (排行榜/新番/游戏/漫画等共用)
class BrowserGrid extends StatelessWidget {
  final String basePath;
  final String emptyText;
  final bool showRank;
  final double childAspectRatio;

  const BrowserGrid({
    super.key,
    required this.basePath,
    this.emptyText = '暂无条目',
    this.showRank = true,
    this.childAspectRatio = 0.58,
  });

  @override
  Widget build(BuildContext context) {
    return PagedGridView<Subject, BrowserQuery>(
      provider: browserResultsProvider,
      arg: BrowserQuery(basePath),
      childAspectRatio: childAspectRatio,
      emptyText: emptyText,
      itemBuilder: (context, subject, index) => SubjectCard(
        subject: subject,
        rank: showRank && subject.rank > 0 ? subject.rank : null,
      ),
    );
  }
}
