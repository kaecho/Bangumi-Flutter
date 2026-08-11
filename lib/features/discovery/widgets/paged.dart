import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/loading.dart';

/// 分页数据 (通用列表页状态)
class PagedData<T> {
  final List<T> items;
  final int page;
  final bool hasMore;

  const PagedData({this.items = const [], this.page = 1, this.hasMore = true});
}

/// 分页加载器基类
///
/// 列表页继承本类并实现 [fetchPage], 再配合
/// `AsyncNotifierProvider.family<X, PagedData<T>, A>(X.new)` 使用:
///
/// ```dart
/// class SearchResults extends PagedNotifier<Subject, SearchQuery> {
///   @override
///   Future<List<Subject>> fetchPage(SearchQuery arg, int page) async { ... }
/// }
/// final searchResultsProvider =
///     AsyncNotifierProvider.family<SearchResults, PagedData<Subject>, SearchQuery>(
///   SearchResults.new,
/// );
/// ```
///
/// UI 层直接使用 [PagedGridView] / [PagedListView] 渲染。
abstract class PagedNotifier<T, A> extends FamilyAsyncNotifier<PagedData<T>, A> {
  /// 拉取第 [page] 页 (从 1 开始); 返回空列表表示没有更多数据
  Future<List<T>> fetchPage(A arg, int page);

  @override
  Future<PagedData<T>> build(A arg) => _load(arg, 1);

  Future<PagedData<T>> _load(A arg, int page) async {
    final items = await fetchPage(arg, page);
    return PagedData<T>(items: items, page: page, hasMore: items.isNotEmpty);
  }

  /// 滚动到底部时加载下一页
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || state.isLoading) return;
    try {
      final next = await _load(arg, current.page + 1);
      state = AsyncData(PagedData<T>(
        items: [...current.items, ...next.items],
        page: next.page,
        hasMore: next.hasMore,
      ));
    } catch (_) {
      // 单页失败不打断已加载内容, 滚动可再次触发
    }
  }
}

/// 通用分页网格: 加载 / 错误重试 / 下拉刷新 / 滚动到底自动加载
class PagedGridView<T, A> extends ConsumerStatefulWidget {
  final AsyncNotifierProviderFamily<PagedNotifier<T, A>, PagedData<T>, A> provider;
  final A arg;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int crossAxisCount;
  final double childAspectRatio;
  final EdgeInsetsGeometry padding;
  final String emptyText;

  const PagedGridView({
    super.key,
    required this.provider,
    required this.arg,
    required this.itemBuilder,
    this.crossAxisCount = 3,
    this.childAspectRatio = 0.56,
    this.padding = const EdgeInsets.all(10),
    this.emptyText = '暂时没有内容',
  });

  @override
  ConsumerState<PagedGridView<T, A>> createState() => _PagedGridViewState<T, A>();
}

class _PagedGridViewState<T, A> extends ConsumerState<PagedGridView<T, A>> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant PagedGridView<T, A> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.arg != widget.arg) _controller.jumpTo(0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(widget.provider(widget.arg).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.provider(widget.arg));
    return state.when(
      loading: () => const Center(child: Loading()),
      error: (error, _) => _ErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(widget.provider(widget.arg)),
      ),
      data: (data) {
        final grid = GridView.builder(
          controller: _controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: widget.padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 12,
            childAspectRatio: widget.childAspectRatio,
          ),
          itemCount: data.items.length,
          itemBuilder: (context, index) =>
              widget.itemBuilder(context, data.items[index], index),
        );
        if (data.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => ref.refresh(widget.provider(widget.arg).future),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Empty(text: widget.emptyText),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(widget.provider(widget.arg).future),
          child: grid,
        );
      },
    );
  }
}

/// 通用分页列表 (与 [PagedGridView] 相同的加载/刷新/翻页逻辑)
class PagedListView<T, A> extends ConsumerStatefulWidget {
  final AsyncNotifierProviderFamily<PagedNotifier<T, A>, PagedData<T>, A> provider;
  final A arg;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final EdgeInsetsGeometry padding;
  final String emptyText;
  final Widget? header;

  const PagedListView({
    super.key,
    required this.provider,
    required this.arg,
    required this.itemBuilder,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
    this.emptyText = '暂时没有内容',
    this.header,
  });

  @override
  ConsumerState<PagedListView<T, A>> createState() => _PagedListViewState<T, A>();
}

class _PagedListViewState<T, A> extends ConsumerState<PagedListView<T, A>> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant PagedListView<T, A> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.arg != widget.arg) _controller.jumpTo(0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(widget.provider(widget.arg).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.provider(widget.arg));
    return state.when(
      loading: () => const Center(child: Loading()),
      error: (error, _) => _ErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(widget.provider(widget.arg)),
      ),
      data: (data) {
        final list = ListView.builder(
          controller: _controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: widget.padding,
          itemCount: data.items.length + (widget.header != null ? 1 : 0),
          itemBuilder: (context, index) {
            if (widget.header != null && index == 0) return widget.header!;
            final item = data.items[index - (widget.header != null ? 1 : 0)];
            return widget.itemBuilder(context, item, index);
          },
        );
        if (data.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => ref.refresh(widget.provider(widget.arg).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (widget.header != null) widget.header!,
                SizedBox(
                  height: 320,
                  child: Empty(text: widget.emptyText),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(widget.provider(widget.arg).future),
          child: list,
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '加载失败',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
