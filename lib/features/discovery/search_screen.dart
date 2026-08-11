import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/models/subject.dart' hide Tag;
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/score.dart';
import 'widgets/paged.dart';
import 'widgets/subject_card.dart';

/// 搜索查询参数 (作为 family key)
class SearchQuery {
  final String keyword;
  final int type; // 0=全部 2=动画 1=书籍 6=三次元 4=游戏

  const SearchQuery(this.keyword, this.type);

  @override
  bool operator ==(Object other) =>
      other is SearchQuery && other.keyword == keyword && other.type == type;

  @override
  int get hashCode => Object.hash(keyword, type);
}

/// 搜索类型 (与原项目 SEARCH_CAT 一致)
const kSearchTypes = [
  (0, '全部'),
  (2, '动画'),
  (1, '书籍'),
  (6, '三次元'),
  (4, '游戏'),
];

class SearchResults extends PagedNotifier<Subject, SearchQuery> {
  @override
  Future<List<Subject>> fetchPage(SearchQuery arg, int page) async {
    final client = ref.read(apiClientProvider);
    final data = await client.get(
      apiSearch(arg.keyword),
      query: {
        if (arg.type != 0) 'type': '${arg.type}',
        'responseGroup': 'small',
        'start': '${(page - 1) * 25}',
        'max_results': '25',
      },
    );
    final list = data is List ? data : (data['list'] as List? ?? const []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(Subject.fromJson)
        .toList();
  }
}

final searchResultsProvider =
    AsyncNotifierProvider.family<SearchResults, PagedData<Subject>, SearchQuery>(
  SearchResults.new,
);

/// 搜索
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  int _type = 0;
  SearchQuery? _query;

  void _submit() {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;
    setState(() => _query = SearchQuery(keyword, _type));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    return Scaffold(
      appBar: BgmAppBar(
        title: '搜索',
        showBackButton: true,
        actions: [
          IconButton(
            onPressed: _submit,
            icon: const Icon(Icons.search),
            tooltip: '搜索',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: '输入条目名称',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final (value, label) in kSearchTypes)
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
            child: query == null
                ? const Center(
                    child: Text('输入关键词开始搜索', style: TextStyle(fontSize: 13)),
                  )
                : PagedGridView<Subject, SearchQuery>(
                    provider: searchResultsProvider,
                    arg: query,
                    childAspectRatio: 0.58,
                    emptyText: '没有找到相关条目',
                    itemBuilder: (context, subject, index) =>
                        SubjectCard(subject: subject),
                  ),
          ),
        ],
      ),
    );
  }
}
