import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../design_system/design_system.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../subject/collection_sheet.dart';
import 'widgets/discovery_html.dart';
import 'widgets/paged.dart';

/// 搜索类型 (与原项目 SEARCH_CAT 一致, 共 9 项)
const kSearchCats = <({String value, String label})>[
  (value: 'subject_all', label: '条目'),
  (value: 'subject_2', label: '动画'),
  (value: 'subject_1', label: '书籍'),
  (value: 'subject_3', label: '音乐'),
  (value: 'subject_4', label: '游戏'),
  (value: 'subject_6', label: '三次元'),
  (value: 'mono_all', label: '人物'),
  (value: 'catalog', label: '目录'),
  (value: 'user', label: '用户'),
];

/// 搜索细度 (原项目 SEARCH_LEGACY)
const kSearchLegacy = <({String value, String label})>[
  (value: '', label: '模糊'),
  (value: '1', label: '精确'),
];

/// 不支持 legacy 的分类 (人物 / 目录 / 用户)
const kNoLegacyCats = {'mono_all', 'catalog', 'user'};

/// 搜索查询参数 (作为 family key)
class SearchQuery {
  final String keyword;
  final String cat; // subject_all | subject_2 | ... | mono_all
  final String legacy; // '' 模糊 | '1' 精确

  const SearchQuery(this.keyword, this.cat, this.legacy);

  @override
  bool operator ==(Object other) =>
      other is SearchQuery &&
      other.keyword == keyword &&
      other.cat == cat &&
      other.legacy == legacy;

  @override
  int get hashCode => Object.hash(keyword, cat, legacy);
}

/// 搜索结果分页 Notifier (条目 / 人物共用 SearchItem)
class SearchResults extends PagedNotifier<SearchItem, SearchQuery> {
  @override
  Future<List<SearchItem>> fetchPage(SearchQuery arg, int page) async {
    final client = ref.read(apiClientProvider);
    // 原项目 fetchSearch: text.replace(' ', '+'); url 内部已编码
    final textValue = arg.keyword.replaceAll(' ', '+');
    // 用户 / 人物搜索不支持 legacy, 强制关闭
    final legacyValue = arg.cat == 'mono_all' || arg.cat == 'user'
        ? ''
        : arg.legacy;
    final path = htmlSearch(
      textValue,
      arg.cat,
      page: page,
      legacy: legacyValue,
    );

    // 搜索 cookie: chii_searchDateLine = legacy?0:now-100
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final extraCookie =
        'chii_searchDateLine=${legacyValue == '1' ? 0 : ts - 100}';
    final html2 = await client.fetchHtmlWithCookie('$kHost$path', extraCookie);

    // 频率限制: 不走 catch (由调用方提示)
    if (html2.contains('秒内只能进行一次搜索')) {
      throw Exception('rate_limited');
    }

    final page_ = arg.cat.contains('mono')
        ? parseSearchMono(html2)
        : parseSearchSubject(html2);
    return page_.list;
  }
}

final searchResultsProvider =
    AsyncNotifierProvider.family<
      SearchResults,
      PagedData<SearchItem>,
      SearchQuery
    >(SearchResults.new);

/// 搜索历史持久化
const _kHistoryKey = 'search_history';
const _kHistoryMax = 20;

class SearchHistory {
  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHistoryKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      return list.length > _kHistoryMax ? list.sublist(0, _kHistoryMax) : list;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<String>> add(List<String> history, String value) async {
    if (value.isEmpty) return history;
    final next = [value, ...history.where((e) => e != value)];
    final capped = next.length > _kHistoryMax
        ? next.sublist(0, _kHistoryMax)
        : next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHistoryKey, jsonEncode(capped));
    return capped;
  }

  static Future<List<String>> remove(List<String> history, String value) async {
    final next = history.where((e) => e != value).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHistoryKey, jsonEncode(next));
    return next;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHistoryKey);
  }
}

/// 搜索
class SearchScreen extends ConsumerStatefulWidget {
  final String initialQuery;
  final String initialType;

  const SearchScreen({
    super.key,
    this.initialQuery = '',
    this.initialType = '',
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _cat = 'subject_2'; // 默认动画 (原项目 STATE.cat 默认 动画)
  String _legacy = ''; // 默认模糊 (原项目 STATE.legacy 默认 模糊)
  String _value = ''; // 已确认的搜索值
  bool _searching = false; // 提交查询中
  List<String> _history = const [];
  SearchQuery? _query;

  bool get _isUser => _cat == 'user';
  bool get _isCatalog => _cat == 'catalog';
  bool get _isMono => _cat == 'mono_all';
  bool get _showLegacy => !kNoLegacyCats.contains(_cat);
  bool get _showHistory => _history.isNotEmpty && _value.isEmpty;
  bool get _showAdvance =>
      _focusNode.hasFocus && !_isUser && !_isCatalog && _query == null;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) {
      _controller.text = widget.initialQuery;
      _value = widget.initialQuery;
    }
    if (widget.initialType.isNotEmpty) {
      final matched = kSearchCats.where((c) => c.label == widget.initialType);
      if (matched.isNotEmpty) _cat = matched.first.value;
    }
    _loadHistory();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    if (widget.initialQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _doSearch();
      });
    }
  }

  Future<void> _loadHistory() async {
    final h = await SearchHistory.load();
    if (mounted) setState(() => _history = h);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _label => kSearchCats.firstWhere((c) => c.value == _cat).label;

  void _onSelectCat(String label) {
    final next = kSearchCats.firstWhere((c) => c.label == label);
    if (next.value == _cat) return;
    setState(() {
      _cat = next.value;
      _query = null;
      _value = '';
    });
    if (_controller.text.trim().isNotEmpty) _doSearch();
  }

  void _onSelectLegacy(String label) {
    final next = kSearchLegacy.firstWhere((l) => l.label == label);
    if (next.value == _legacy) return;
    setState(() {
      _legacy = next.value;
      _query = null;
    });
    if (_value.isNotEmpty) _doSearch();
  }

  void _selectHistory(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    setState(() {});
    _onSubmit();
  }

  Future<void> _deleteHistory(String value) async {
    final next = await SearchHistory.remove(_history, value);
    setState(() => _history = next);
  }

  Future<void> _deleteHistoryAll() async {
    await SearchHistory.clear();
    setState(() => _history = const []);
  }

  void _onSubmit() {
    final value = _controller.text.trim();
    if (_isUser) {
      _submitUser(value);
      return;
    }
    if (_isCatalog) {
      _submitCatalog(value);
      return;
    }
    _doSearch();
  }

  Future<void> _doSearch() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      _toast('请输入内容');
      return;
    }
    setState(() {
      _searching = true;
      _value = value;
      _query = SearchQuery(value, _cat, _legacy);
    });
    // 历史持久化
    final next = await SearchHistory.add(_history, value);
    if (mounted) setState(() => _history = next);
    // 触发 provider 构建 (PagedListView 会自行 watch)
    setState(() => _searching = false);
  }

  Future<void> _submitUser(String value) async {
    if (value.isEmpty) {
      _toast('请输入完整的用户 ID');
      return;
    }
    if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(value)) {
      _toast('请输入用户 ID 而非用户昵称');
      return;
    }
    setState(() => _searching = true);
    try {
      final client = ref.read(apiClientProvider);
      final html = await client.fetchHtml(htmlUserWiki(value));
      if (html.contains('数据库中没有查询到该用户的信息')) {
        _toast('该用户 ID 不存在');
        return;
      }
      if (mounted) unawaited(context.push('/user/$value'));
    } catch (_) {
      _toast('请稍候再查询');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _submitCatalog(String value) async {
    if (value.isEmpty) {
      _toast('请输入目录关键字');
      return;
    }
    if (mounted) {
      unawaited(
        context.push(
          '/catalog?_keyword=${Uri.encodeQueryComponent(value.trim())}',
        ),
      );
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: '搜索',
        showBackButton: true,
        actions: [
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) {
              if (value == 'browser') {
                final text = _value.isNotEmpty
                    ? _value
                    : _controller.text.trim();
                final path = text.isEmpty
                    ? '/subject_search'
                    : htmlSearch(text, _cat, legacy: _legacy);
                openExternalUrl('$kHost$path');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'browser', child: Text('浏览器查看')),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          // Flex search bar = [Category popover, SearchBar, Legacy popover, BtnSubmit]
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                _CategoryButton(label: _label, onSelect: _onSelectCat),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _onSubmit(),
                    decoration: InputDecoration(
                      hintText: _isUser ? '输入完整的用户 ID' : '输入关键字',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
                if (_showLegacy) ...[
                  const SizedBox(width: 8),
                  _LegacyButton(
                    label: kSearchLegacy
                        .firstWhere((l) => l.value == _legacy)
                        .label,
                    onSelect: _onSelectLegacy,
                  ),
                ],
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _searching ? null : _onSubmit,
                  child: Text(_isUser || _isCatalog ? '前往' : '查询'),
                ),
              ],
            ),
          ),
          // Advance (仅 mono 模式下显示 ID 直达提示; 静态 token 网格本应来自本地数据集, 未移植)
          if (_showAdvance) _buildAdvance(),
          // History
          if (_showHistory) _buildHistory(),
          // List (搜索结果)
          Expanded(
            child: _query == null
                ? const Center(
                    child: Text('输入关键词开始搜索', style: TextStyle(fontSize: 13)),
                  )
                : PagedListView<SearchItem, SearchQuery>(
                    provider: searchResultsProvider,
                    arg: _query!,
                    emptyText: '没有找到相关结果',
                    itemBuilder: (context, item, index) =>
                        _SearchItemView(item: item, keyword: _value),
                  ),
          ),
        ],
      ),
    );
  }

  /// Advance: 仅人物 / 条目 ID 直达 (静态联想数据集未移植)
  Widget _buildAdvance() {
    final value = _controller.text.trim();
    final isId = RegExp(r'^\d+$').hasMatch(value);
    if (value.isEmpty || !isId) return const SizedBox.shrink();
    if (_isMono) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Column(
          children: [
            _AdvanceChip(
              text: '虚拟人物 #$value',
              onTap: () => context.push('/mono/character/$value'),
            ),
            const SizedBox(height: 4),
            _AdvanceChip(
              text: '现实人物 #$value',
              onTap: () => context.push('/mono/person/$value'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: _AdvanceChip(
        text: '#$value',
        onTap: () => context.push('/subject/$value'),
      ),
    );
  }

  Widget _buildHistory() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in _history)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectHistory(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _deleteHistory(item),
                ),
              ],
            ),
          if (_history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: _deleteHistoryAll,
                  child: Text(
                    '清除历史',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 分类下拉按钮 (Category popover)
class _CategoryButton extends StatelessWidget {
  final String label;
  final ValueChanged<String> onSelect;

  const _CategoryButton({required this.label, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '搜索类型',
      onSelected: onSelect,
      itemBuilder: (_) => [
        for (final c in kSearchCats)
          PopupMenuItem(value: c.label, child: Text(c.label)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

/// 细分类型 (legacy) 下拉按钮
class _LegacyButton extends StatelessWidget {
  final String label;
  final ValueChanged<String> onSelect;

  const _LegacyButton({required this.label, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '搜索细度',
      onSelected: onSelect,
      itemBuilder: (_) => [
        for (final l in kSearchLegacy)
          PopupMenuItem(value: l.label, child: Text(l.label)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Advance chip (ID 直达)
class _AdvanceChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _AdvanceChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: context.ds.surfaceCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.ds.border, width: 0.5),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// 搜索结果行 (条目 + 人物)
class _SearchItemView extends StatelessWidget {
  final SearchItem item;
  final String keyword;

  const _SearchItemView({required this.item, required this.keyword});

  @override
  Widget build(BuildContext context) {
    final isSubject = item.type.startsWith('subject');
    if (isSubject) {
      return _SubjectRow(item: item, keyword: keyword);
    }
    return _MonoRow(item: item);
  }
}

/// 条目行: 封面 + 标题 (高亮) + 信息 + 评分
class _SubjectRow extends StatelessWidget {
  final SearchItem item;
  final String keyword;

  const _SubjectRow({required this.item, required this.keyword});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final typeKey = item.type.contains(':') ? item.type.split(':').last : '';
    final isMusic = typeKey == 'music';
    final width = isMusic ? 56.0 : 60.0;
    final height = isMusic ? 56.0 : 80.0;
    return InkWell(
      onTap: () => context.push('/subject/${item.id}'),
      onLongPress: () => showCollectionSheet(context, item.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Cover(url: item.cover, width: width, height: height, radius: 4),

            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (item.rank > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: ds.accentSoft,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '#${item.rank}',
                            style: ds.caption.copyWith(
                              color: ds.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text.rich(
                          _highlightSearchTitle(
                            item.nameCn.isEmpty ? item.name : item.nameCn,
                            keyword,
                            fontSize: visualFontSize(
                              item.nameCn.isEmpty ? item.name : item.nameCn,
                              const [(20, 12), (14, 13), (12, 14), (0, 15)],
                            ),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: '收藏',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.bookmark_add_outlined,
                          size: 18,
                          color: ds.textHint,
                        ),
                        onPressed: () => showCollectionSheet(context, item.id),
                      ),
                    ],
                  ),
                  if (item.name.isNotEmpty && item.name != item.nameCn)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.name,
                        style: ds.caption.copyWith(
                          color: ds.textSecondary,
                          fontSize: visualFontSize(item.name, const [
                            (32, 9),
                            (24, 10),
                            (16, 11),
                            (0, 12),
                          ]),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (item.tip.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.tip,
                        style: ds.caption.copyWith(color: ds.textHint),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (item.score > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Text(
                            item.score.toStringAsFixed(1),
                            style: ds.caption.copyWith(
                              color: ds.star,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (item.comments.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              item.comments,
                              style: ds.caption.copyWith(color: ds.textHint),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 人物行
class _MonoRow extends StatelessWidget {
  final SearchItem item;

  const _MonoRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final route = item.type == 'character'
        ? '/mono/character/${item.id}'
        : '/mono/person/${item.id}';
    return InkWell(
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Cover(url: item.cover, width: 56, height: 56, radius: 4),

            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: ds.body.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.nameCn.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.nameCn,
                        style: ds.caption.copyWith(color: ds.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (item.tip.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.tip,
                        style: ds.caption.copyWith(color: ds.textHint),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (item.comments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.comments,
                        style: ds.caption.copyWith(color: ds.textHint),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextSpan _highlightSearchTitle(
  String text,
  String filter, {
  required double fontSize,
}) {
  final style = TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold);
  final hit = pinYinFilterValue(text, filter);
  if (hit == null) return TextSpan(text: text, style: style);
  final index = text.toLowerCase().indexOf(hit.toLowerCase());
  if (index < 0) return TextSpan(text: text, style: style);
  return TextSpan(
    style: style,
    children: [
      TextSpan(text: text.substring(0, index)),
      TextSpan(
        text: text.substring(index, index + hit.length),
        style: const TextStyle(color: Color(0xFFE53935)),
      ),
      TextSpan(text: text.substring(index + hit.length)),
    ],
  );
}
