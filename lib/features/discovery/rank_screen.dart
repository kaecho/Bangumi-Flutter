import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/models/subject.dart';
import '../../shared/widgets/app_bar.dart';
import 'widgets/discovery_html.dart';
import 'widgets/paged.dart';
import 'widgets/subject_card.dart';

/// 排行榜查询参数 (作为 family key)
class RankQuery {
  final String type; // anime | book | real | game
  final String sort; // rank | date | collects

  const RankQuery(this.type, this.sort);

  @override
  bool operator ==(Object other) =>
      other is RankQuery && other.type == type && other.sort == sort;

  @override
  int get hashCode => Object.hash(type, sort);
}

/// 排行榜类型 Tab
const kRankTypes = [
  ('anime', '动画'),
  ('book', '书籍'),
  ('real', '三次元'),
  ('game', '游戏'),
];

/// 排序选项: (值, 文案); 日期排序仅动画支持
const kRankSorts = [
  ('rank', '排名'),
  ('collects', '完成数'),
  ('trends', '热度'),
  ('date', '发售日'),
];

class RankResults extends PagedNotifier<Subject, RankQuery> {
  @override
  Future<List<Subject>> fetchPage(RankQuery arg, int page) async {
    final client = ref.read(apiClientProvider);
    final body = await client.get(
      htmlRankBrowser(arg.type, sort: arg.sort, page: page),
      host: kHost,
    );
    return parseSubjectList(body as String);
  }
}

final rankResultsProvider =
    AsyncNotifierProvider.family<RankResults, PagedData<Subject>, RankQuery>(
  RankResults.new,
);

/// 排行榜
class RankScreen extends ConsumerStatefulWidget {
  const RankScreen({super.key});

  @override
  ConsumerState<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends ConsumerState<RankScreen> {
  String _type = 'anime';
  String _sort = 'rank';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: '排行榜',
        showBackButton: true,
        actions: [
          PopupMenuButton<String>(
            initialValue: _sort,
            tooltip: '排序',
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (context) => [
              for (final (value, label) in kRankSorts)
                if (_type != 'anime' && value == 'date')
                  const PopupMenuItem(enabled: false, child: Text('发售日'))
                else
                  PopupMenuItem(value: value, child: Text(label)),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final (value, label) in kRankTypes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Tag(
                      text: label,
                      active: _type == value,
                      onTap: () => setState(() => _type = value),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PagedGridView<Subject, RankQuery>(
              provider: rankResultsProvider,
              arg: RankQuery(_type, _sort),
              childAspectRatio: 0.58,
              emptyText: '暂无数据',
              itemBuilder: (context, subject, index) => SubjectCard(
                subject: subject,
                rank: subject.rank > 0 ? subject.rank : index + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
