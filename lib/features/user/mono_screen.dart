import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'user_models.dart';

class UserMonoQuery {
  final String userId;
  final String kind;

  const UserMonoQuery(this.userId, this.kind);

  @override
  bool operator ==(Object other) =>
      other is UserMonoQuery && other.userId == userId && other.kind == kind;

  @override
  int get hashCode => Object.hash(userId, kind);
}

class UserMonoData {
  final List<UserMono> items;
  final int page;
  final bool hasMore;

  const UserMonoData({
    this.items = const [],
    this.page = 1,
    this.hasMore = true,
  });
}

/// 收藏的人物 (角色/人物, bgm.tv/user/{uid}/mono/{kind}?page=, 对齐原版 LIMIT=44)
final userMonoProvider =
    AsyncNotifierProvider.family<UserMonoNotifier, UserMonoData, UserMonoQuery>(
      UserMonoNotifier.new,
    );

class UserMonoNotifier
    extends FamilyAsyncNotifier<UserMonoData, UserMonoQuery> {
  static const _limit = 44;

  @override
  Future<UserMonoData> build(UserMonoQuery query) async {
    return _fetch(1, query);
  }

  Future<UserMonoData> _fetch(int page, UserMonoQuery query) async {
    final client = ref.read(apiClientProvider);
    final html = await client.get(
      apiUserMonoHtml(query.userId, kind: query.kind, page: page),
      host: kHost,
    );
    final items = parseUserMono(html as String);
    return UserMonoData(
      items: items,
      page: page,
      hasMore: items.length >= _limit,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    try {
      final next = await _fetch(current.page + 1, arg);
      state = AsyncData(
        UserMonoData(
          items: [...current.items, ...next.items],
          page: next.page,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {}
  }
}

/// 收藏人物网格 (Character / 独立页共用)
class UserMonoList extends ConsumerStatefulWidget {
  final String userId;
  final String kind;

  const UserMonoList({super.key, required this.userId, required this.kind});

  @override
  ConsumerState<UserMonoList> createState() => _UserMonoListState();
}

class _UserMonoListState extends ConsumerState<UserMonoList> {
  final _scroll = ScrollController();

  UserMonoQuery get _query => UserMonoQuery(widget.userId, widget.kind);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        unawaited(ref.read(userMonoProvider(_query).notifier).loadMore());
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userMonoProvider(_query));
    return async.when(
      loading: () => const Loading(),
      error: (_, _) => const Center(child: Text('加载失败')),
      data: (data) {
        if (data.items.isEmpty) return const Center(child: Text('暂无收藏'));
        return GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.72,
          ),
          itemCount: data.items.length + (data.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= data.items.length) {
              return const Center(child: BgmSpinner());
            }
            final mono = data.items[index];
            return InkWell(
              onTap: () => context.push('/mono/${mono.id}'),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Cover(
                    url: mono.avatar,
                    width: double.infinity,
                    height: 110,
                    radius: 6,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mono.name,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
