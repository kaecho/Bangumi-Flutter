import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
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

/// 用户收藏的人物 (自己或他人)
class UserMonoScreen extends ConsumerStatefulWidget {
  final String userId;
  final String title;

  const UserMonoScreen({super.key, required this.userId, this.title = '收藏的人物'});

  @override
  ConsumerState<UserMonoScreen> createState() => _UserMonoScreenState();
}

class _UserMonoScreenState extends ConsumerState<UserMonoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '角色'),
            Tab(text: '人物'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _MonoList(userId: widget.userId, kind: 'character'),
          _MonoList(userId: widget.userId, kind: 'person'),
        ],
      ),
    );
  }
}

/// 我的人物 (当前登录用户收藏的角色/人物)
class MyMonoScreen extends ConsumerWidget {
  const MyMonoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    if (me == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的人物')),
        body: const Center(child: Text('请先登录')),
      );
    }
    return UserMonoScreen(userId: userPathId(me), title: '我的人物');
  }
}

class _MonoList extends ConsumerStatefulWidget {
  final String userId;
  final String kind;

  const _MonoList({required this.userId, required this.kind});

  @override
  ConsumerState<_MonoList> createState() => _MonoListState();
}

class _MonoListState extends ConsumerState<_MonoList> {
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
              return const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
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
