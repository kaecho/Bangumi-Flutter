import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/display.dart';
import 'html_parse.dart';

import '../../shared/widgets/loading.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/score.dart';

import '../rakuen/rakuen_screen.dart' show kRakuenScopes;
import 'rakuen_providers.dart';
import 'widgets/topic_row.dart';

/// 超展开板块 (新番乐园/经典动画/...)
/// 路由: /rakuen/board/:key  (key 为板块 scope, 如 new_bangumi)
class BoardScreen extends ConsumerStatefulWidget {
  final String boardKey;

  const BoardScreen({super.key, required this.boardKey});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  late String _scope;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scope = widget.boardKey;
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(boardTopicsProvider(_scope).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        kRakuenScopes
            .where((e) => e.$2 == _scope)
            .map((e) => e.$1)
            .firstOrNull ??
        '板块';

    return Scaffold(
      appBar: BgmAppBar(
        title: title,
        actions: [
          BgmHeaderMore.browser(
            () => openExternalUrl(rakuenBoardPageUrl(_scope)),
          ),
        ],

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final scope in kRakuenScopes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: BgmFilterChip(
                      label: scope.$1,
                      selected: scope.$2 == _scope,
                      onTap: () {
                        setState(() => _scope = scope.$2);
                        ref.invalidate(boardTopicsProvider(_scope));
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),

      body: _BoardTopicList(scope: _scope, scrollController: _scrollController),
    );
  }
}

class _BoardTopicList extends ConsumerWidget {
  final String scope;
  final ScrollController scrollController;

  const _BoardTopicList({required this.scope, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(boardTopicsProvider(scope));
    return async.when(
      loading: () => const Loading(height: double.infinity),
      error: (e, _) =>
          BgmRetry(onRetry: () => ref.invalidate(boardTopicsProvider(scope))),

      data: (data) {
        if (data.items.isEmpty) {
          return const Center(child: Text('暂无帖子'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(boardTopicsProvider(scope)),
          child: ListView.separated(
            controller: scrollController,
            itemCount: data.items.length + (data.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const BgmHairline(indent: 56),
            itemBuilder: (context, index) {
              if (index >= data.items.length) {
                return LoadMoreLink(
                  onTap: () =>
                      ref.read(boardTopicsProvider(scope).notifier).loadMore(),
                );
              }
              return RakuenTopicRow(topic: data.items[index]);
            },
          ),
        );
      },
    );
  }
}
