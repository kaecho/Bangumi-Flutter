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
import '../../core/storage/settings_store.dart';

import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/cover.dart';
import '../subject/collection_sheet.dart';
import 'widgets/discovery_html.dart';
import 'widgets/paged.dart';
import '../../shared/widgets/bgm_button.dart';
import 'search_advance.dart';

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
  bool _t2s = true;
  List<String> _history = const [];
  Timer? _advanceTimer;
  List<SearchAdvanceHit> _advanceHits = const [];
  List<SearchAdvanceMonoHit> _advanceMono = const [];

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
    unawaited(loadCnCharTables());

    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _controller.addListener(_scheduleAdvance);

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
    _advanceTimer?.cancel();
    _controller.removeListener(_scheduleAdvance);
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

  void _onInputChanged(String text) {
    if (ref.read(settingsStoreProvider).s2t && _t2s) {
      final simplified = t2s(text);
      if (simplified != text) {
        _controller.value = TextEditingValue(
          text: simplified,
          selection: TextSelection.collapsed(offset: simplified.length),
        );
      }
    }
    _scheduleAdvance();
  }

  void _toggleT2s() {
    final next = !_t2s;
    setState(() => _t2s = next);
    if (next) {
      final converted = t2s(_controller.text);
      if (converted != _controller.text) {
        _controller.value = TextEditingValue(
          text: converted,
          selection: TextSelection.collapsed(offset: converted.length),
        );
      }
    }
    showBgmToast(context, '${next ? '开启' : '关闭'}输入内容自动转为简体');
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
    showBgmToast(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: '搜索',
        showBackButton: true,
        actions: [
          if (ref.watch(settingsStoreProvider).s2t)
            BgmHeaderAction(
              tooltip: _t2s ? '输入自动转为简体' : '保持原文',
              icon: Text(_t2s ? '简' : '繁', style: context.ds.bodyStrong),
              onPressed: _toggleT2s,
            ),
          BgmHeaderMore.browser(() {
            final text = _value.isNotEmpty ? _value : _controller.text.trim();
            final path = text.isEmpty
                ? '/subject_search'
                : htmlSearch(text, _cat, legacy: _legacy);
            openExternalUrl('$kHost$path');
          }),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                _SearchSideButton(
                  label: _label,
                  tooltip: '搜索类型',
                  ghost: true,
                  left: true,
                  options: [for (final c in kSearchCats) c.label],
                  onSelect: _onSelectCat,
                ),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _onSubmit(),
                      onChanged: _onInputChanged,

                      style: context.ds.body.copyWith(fontSize: 12),
                      cursorColor: context.ds.accent,
                      decoration: InputDecoration(
                        hintText: _isUser ? '输入完整的用户 ID' : '输入关键字',
                        hintStyle: context.ds.caption,
                        isDense: true,
                        filled: true,
                        fillColor: context.ds.surfaceCard,
                        contentPadding: const EdgeInsets.fromLTRB(
                          12,
                          10,
                          4,
                          10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.horizontal(
                            right: _showLegacy
                                ? Radius.zero
                                : const Radius.circular(40),
                          ),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.horizontal(
                            right: _showLegacy
                                ? Radius.zero
                                : const Radius.circular(40),
                          ),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.horizontal(
                            right: _showLegacy
                                ? Radius.zero
                                : const Radius.circular(40),
                          ),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_showLegacy)
                  _SearchSideButton(
                    label: kSearchLegacy
                        .firstWhere((l) => l.value == _legacy)
                        .label,
                    tooltip: '搜索细度',
                    ghost: false,
                    left: false,
                    options: [for (final l in kSearchLegacy) l.label],
                    onSelect: _onSelectLegacy,
                  ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 64,
                  height: 40,
                  child: BgmButton(
                    _isUser || _isCatalog ? '前往' : '查询',
                    type: BgmButtonType.plain,
                    expand: true,
                    onPressed: _searching ? null : _onSubmit,
                  ),
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

  void _scheduleAdvance() {
    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 160), _refreshAdvance);
  }

  Future<void> _refreshAdvance() async {
    if (!mounted || !_showAdvance) {
      if (_advanceHits.isNotEmpty || _advanceMono.isNotEmpty) {
        setState(() {
          _advanceHits = const [];
          _advanceMono = const [];
        });
      }
      return;
    }
    final value = _controller.text.trim();
    if (_isMono) {
      final hits = await searchAdvanceMono(value);
      if (!mounted) return;
      setState(() {
        _advanceHits = const [];
        _advanceMono = hits;
      });
      return;
    }
    final hits = await searchAdvanceSubjects(_cat, value);
    if (!mounted) return;
    setState(() {
      _advanceHits = hits;
      _advanceMono = const [];
    });
  }

  void _fillAdvance(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _onSubmit();
  }

  /// Advance: 打包标题联想 + 人物/条目 ID 直达
  Widget _buildAdvance() {
    final value = _controller.text.trim();
    final isId = isSearchAdvanceId(value);
    if (value.isEmpty && !isId) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        children: [
          if (isId && _isMono) ...[
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
          if (isId && !_isMono)
            _AdvanceChip(
              text: '#$value',
              onTap: () => context.push('/subject/$value'),
            ),
          if (_isMono)
            for (final item in _advanceMono)
              _AdvanceMonoRow(
                item: item,
                keyword: value,
                onOpen: () => context.push(item.path),
                onSearch: () => _fillAdvance(item.name),
              )
          else
            for (final item in _advanceHits)
              _AdvanceSubjectRow(
                item: item,
                keyword: value,
                onOpen: () => context.push('/subject/${item.id}'),
                onSearch: () => _fillAdvance(item.title),
              ),
        ],
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
                BgmHeaderAction(
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

/// 搜索栏左右胶囊 (原版 Category / Legacy, 无下拉箭头)
class _SearchSideButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool ghost;
  final bool left;
  final List<String> options;
  final ValueChanged<String> onSelect;

  const _SearchSideButton({
    required this.label,
    required this.tooltip,
    required this.ghost,
    required this.left,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final radius = left
        ? const BorderRadius.horizontal(left: Radius.circular(40))
        : const BorderRadius.horizontal(right: Radius.circular(40));
    return PopupMenuButton<String>(
      tooltip: tooltip,
      onSelected: onSelect,
      itemBuilder: (_) => [
        for (final o in options) PopupMenuItem(value: o, child: Text(o)),
      ],
      child: Container(
        width: 64,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ghost ? ds.accentSoft : ds.surfaceCard,
          borderRadius: radius,
          border: ghost
              ? Border.all(color: ds.accent.withValues(alpha: 0.35))
              : Border(
                  top: BorderSide(color: ds.border, width: 0.5),
                  right: BorderSide(color: ds.border, width: 0.5),
                  bottom: BorderSide(color: ds.border, width: 0.5),
                ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ds.caption.copyWith(
            color: ghost ? ds.accent : ds.textPrimary,
            fontWeight: FontWeight.w700,
          ),
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

class _AdvanceSubjectRow extends StatelessWidget {
  final SearchAdvanceHit item;
  final String keyword;
  final VoidCallback onOpen;
  final VoidCallback onSearch;

  const _AdvanceSubjectRow({
    required this.item,
    required this.keyword,
    required this.onOpen,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onOpen,
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.ds.bodyStrong,
              ),
            ),
          ),
          BgmHeaderAction(
            tooltip: '查询',
            icon: const Icon(Icons.search, size: 20),
            onPressed: onSearch,
          ),
        ],
      ),
    );
  }
}

class _AdvanceMonoRow extends StatelessWidget {
  final SearchAdvanceMonoHit item;
  final String keyword;
  final VoidCallback onOpen;
  final VoidCallback onSearch;

  const _AdvanceMonoRow({
    required this.item,
    required this.keyword,
    required this.onOpen,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (item.cover.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Cover(url: item.cover, width: 32, height: 32, radius: 4),
            ),
          Expanded(
            child: GestureDetector(
              onTap: onOpen,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      item.name.length > 16
                          ? '${item.name.substring(0, 16)}...'
                          : item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.ds.bodyStrong,
                    ),
                  ),
                  if (item.replies > 0)
                    Text(
                      ' +${item.replies}',
                      style: context.ds.caption.copyWith(
                        color: context.ds.accent,
                      ),
                    ),
                ],
              ),
            ),
          ),
          BgmHeaderAction(
            tooltip: '查询',
            icon: const Icon(Icons.search, size: 20),
            onPressed: onSearch,
          ),
        ],
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
                      BgmHeaderAction(
                        tooltip: '收藏',
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
