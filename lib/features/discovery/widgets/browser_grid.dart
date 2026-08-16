import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/storage/settings_store.dart';
import '../../../core/utils/display.dart';
import '../../../shared/models/subject.dart';
import '../../../shared/widgets/bgm_button.dart';
import '../../../shared/widgets/cover.dart';
import '../../subject/collection_sheet.dart';
import 'discovery_html.dart';
import 'paged.dart';
import 'subject_card.dart';

/// 条目浏览器查询 (作为 family key; basePath 不含 page)
class BrowserQuery {
  final String basePath;
  final bool collected;

  const BrowserQuery(this.basePath, {this.collected = true});

  @override
  bool operator ==(Object other) =>
      other is BrowserQuery &&
      other.basePath == basePath &&
      other.collected == collected;

  @override
  int get hashCode => Object.hash(basePath, collected);
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
    var items = parseSubjectList(body as String);
    if (SettingsStore.instance.filter18x) {
      items = [
        for (final item in items)
          if (!isSensitiveSubject(
            nsfw: item.nsfw,
            name: item.name,
            nameCn: item.nameCn,
          ))
            item,
      ];
    }
    if (!arg.collected) {
      items = [
        for (final item in items)
          if (!item.collected) item,
      ];
    }
    return items;
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
  final bool isList;
  final bool collected;
  final ScrollController? controller;
  final Widget? header;

  const BrowserGrid({
    super.key,
    required this.basePath,
    this.emptyText = '暂无条目',
    this.showRank = true,
    this.childAspectRatio = 0.58,
    this.isList = false,
    this.collected = true,
    this.controller,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    if (isList) {
      return PagedListView<Subject, BrowserQuery>(
        provider: browserResultsProvider,
        arg: BrowserQuery(basePath, collected: collected),
        emptyText: emptyText,
        controller: controller,
        header: header,
        itemBuilder: (context, subject, index) {
          final rank = showRank && subject.rank > 0 ? subject.rank : null;
          final score = subject.rating?.score ?? 0;
          return BgmTextRow(
            leading: Cover(
              url: subject.images.medium.isNotEmpty
                  ? subject.images.medium
                  : subject.images.large,
              width: 48,
              height: 68,
              radius: 4,
            ),
            title: subject.displayName,
            subtitle: [
              if (rank != null) 'Rank $rank',
              if (score > 0) score.toStringAsFixed(1),
            ].join(' · '),
            onTap: () => context.push('/subject/${subject.id}'),
            onLongPress: () => showCollectionSheet(context, subject.id),
          );
        },
      );
    }
    return PagedGridView<Subject, BrowserQuery>(
      provider: browserResultsProvider,
      arg: BrowserQuery(basePath, collected: collected),
      childAspectRatio: childAspectRatio,
      emptyText: emptyText,
      controller: controller,
      header: header,
      itemBuilder: (context, subject, index) => SubjectCard(
        subject: subject,
        rank: showRank && subject.rank > 0 ? subject.rank : null,
      ),
    );
  }
}
