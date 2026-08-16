import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../shared/models/ep.dart';
import '../../shared/models/subject.dart';
import 'html_parser.dart';
import 'subject_models.dart';
import '../rakuen/html_parse.dart';

/// 第三方数据 (bilibili / bangumi-data) 使用独立 HTTP 请求,
/// 避免把 bgm.tv 的 OAuth token 发送到第三方域名
Future<String> _plainGet(String url) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set(HttpHeaders.userAgentHeader, 'Bangumi/Flutter');
    final resp = await req.close();
    return await resp.transform(utf8.decoder).join();
  } finally {
    client.close();
  }
}

/// 条目详情: 旧版 /subject/{id} + v0 large (infobox/tags)
final subjectDetailProvider = FutureProvider.family<SubjectDetail, int>((
  ref,
  id,
) async {
  final client = ref.read(apiClientProvider);

  Subject subject;
  try {
    final raw = await client.get(apiSubject(id));
    subject = Subject.fromJson(raw as Map<String, dynamic>);
  } catch (_) {
    subject = Subject(id: id, images: const SubjectImages());
  }

  List<Infobox> infobox = const [];
  List<Tag> tags = const [];
  try {
    final raw = await client.get(apiV0Subject(id));
    final map = raw as Map<String, dynamic>;
    infobox =
        (map['infobox'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(Infobox.fromJson)
            .toList() ??
        const [];
    tags =
        (map['tags'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(Tag.fromJson)
            .toList() ??
        const [];
  } catch (_) {
    // v0 详情失败不阻塞主页面
  }

  return SubjectDetail(subject: subject, infobox: infobox, tags: tags);
});

/// 条目主站页额外信息 (锁定 / 猜你喜欢)
final subjectHtmlExtrasProvider = FutureProvider.family<SubjectHtmlExtras, int>(
  (ref, id) async {
    final client = ref.read(apiClientProvider);
    final body = await client.get('$kHost/subject/$id', host: kHost);
    return parseSubjectHtmlExtras(body as String);
  },
);

/// 章节列表: /subject/{id}/ep
final epListProvider = FutureProvider.family<EpList, int>((ref, id) async {
  final client = ref.read(apiClientProvider);
  final raw = await client.get(apiSubjectEp(id));
  final list = raw is List ? raw : (raw as Map<String, dynamic>)['eps'] as List;
  return EpList.fromJson(list);
});

/// 章节观看状态: /v0/users/-/collections/{sid}/episodes (需登录)
final epStatusProvider = FutureProvider.family<EpStatusMap, int>((
  ref,
  id,
) async {
  final isLogin = ref.watch(isLoggedInProvider);
  if (!isLogin) return const EpStatusMap();
  try {
    final client = ref.read(apiClientProvider);
    final raw = await client.get(apiV0UsersEpisodes('-', id));
    final watched = <int, bool>{};
    for (final item in raw as List) {
      final map = item as Map<String, dynamic>;
      final ep = map['episode'] as Map<String, dynamic>?;
      final type = (map['type'] as num?)?.toInt() ?? 0;
      if (ep != null) {
        watched[(ep['id'] as num?)?.toInt() ?? 0] = type == 2;
      }
    }
    return EpStatusMap(watched: watched);
  } catch (_) {
    return const EpStatusMap();
  }
});

/// 用户收藏详情: /collection/{id} (需登录)
final collectionProvider = FutureProvider.family<CollectionDetail?, int>((
  ref,
  id,
) async {
  final isLogin = ref.watch(isLoggedInProvider);
  if (!isLogin) return null;
  try {
    final client = ref.read(apiClientProvider);
    final raw = await client.get(apiCollection(id));
    final detail = CollectionDetail.fromJson(raw as Map<String, dynamic>);
    return detail.hasCollection ? detail : null;
  } catch (_) {
    return null;
  }
});

/// 角色列表: /v0/subjects/{id}/characters
final subjectCharactersProvider = FutureProvider.family<List<CharacterVo>, int>(
  (ref, id) async {
    final client = ref.read(apiClientProvider);
    final raw = await client.get(apiV0SubjectCharacters(id));
    return (raw as List)
        .whereType<Map<String, dynamic>>()
        .map(CharacterVo.fromJson)
        .toList();
  },
);

/// 制作人员: 主站 HTML /subject/{id}/persons (原版 cheerioPersons)
final subjectPersonsProvider = FutureProvider.family<List<PersonVo>, int>((
  ref,
  id,
) async {
  final client = ref.read(apiClientProvider);
  final body = await client.get(htmlSubjectPersons(id), host: kHost);
  final html = parseSubjectPersons(body as String);
  if (html.isNotEmpty) return html;
  final raw = await client.get(apiV0SubjectPersons(id));
  return (raw as List)
      .whereType<Map<String, dynamic>>()
      .map(PersonVo.fromJson)
      .toList();
});

/// 关联条目: /v0/subjects/{id}/subjects
final subjectRelationsProvider =
    FutureProvider.family<List<SubjectListItem>, int>((ref, id) async {
      final client = ref.read(apiClientProvider);
      final raw = await client.get(apiV0SubjectSeries(id));
      return (raw as List)
          .whereType<Map<String, dynamic>>()
          .map(SubjectListItem.fromJson)
          .toList();
    });

/// 条目吐槽箱: 主站 HTML /subject/{id}/comments?page=&interest_type=&version=
final subjectCommentsProvider =
    FutureProvider.family<
      CommentPage,
      ({int id, int page, String interestType, bool version})
    >((ref, arg) async {
      final client = ref.read(apiClientProvider);
      final body = await client.get(
        htmlSubjectComments(
          arg.id,
          page: arg.page,
          interestType: arg.interestType,
          version: arg.version,
        ),
        host: kHost,
      );
      return parseSubjectCommentsHtml(body as String);
    });

/// 评分分布: 条目 rating.count + 吐槽 (客户端按分数过滤)
final ratingStatsProvider = FutureProvider.family<RatingStats, int>((
  ref,
  id,
) async {
  final detail = await ref.watch(subjectDetailProvider(id).future);
  final rating = detail.subject.rating;

  CommentPage comments = const CommentPage();
  try {
    comments = await ref.read(
      subjectCommentsProvider((
        id: id,
        page: 1,
        interestType: '',
        version: false,
      )).future,
    );
  } catch (_) {}

  return RatingStats(
    score: rating?.score ?? 0,
    total: rating?.total ?? 0,
    rank: rating?.rank ?? 0,
    counts: detail.ratingCounts,
    comments: comments.items,
  );
});

/// 所有人评分: 主站 HTML /subject/{id}/{status}?filter=friends
final subjectRatingProvider =
    FutureProvider.family<
      SubjectRatingPage,
      ({int id, String status, bool friends})
    >((ref, arg) async {
      final client = ref.read(apiClientProvider);
      final body = await client.get(
        htmlSubjectRating(arg.id, status: arg.status, friends: arg.friends),
        host: kHost,
      );
      return parseSubjectRatingHtml(body as String);
    });

/// 章节吐槽箱: 主站 HTML /ep/{epId}
final epCommentsProvider = FutureProvider.family<CommentPage, int>((
  ref,
  epId,
) async {
  final client = ref.read(apiClientProvider);
  final body = await client.get(htmlEpPage(epId), host: kHost);
  return parseTopicCommentsHtml(body as String);
});

/// 角色 / 人物详情: /v0/characters/{id} | /v0/persons/{id}
final monoDetailProvider =
    FutureProvider.family<MonoDetail, ({String type, int id})>((
      ref,
      arg,
    ) async {
      final client = ref.read(apiClientProvider);
      final raw = await client.get(
        arg.type == 'person' ? apiV0Person(arg.id) : apiV0Character(arg.id),
      );
      final map = raw as Map<String, dynamic>;
      return arg.type == 'person'
          ? MonoDetail.fromPerson(map)
          : MonoDetail.fromCharacter(map);
    });

/// 角色 / 人物出演作品: /v0/characters/{id}/subjects | /v0/persons/{id}/subjects
final monoSubjectsProvider =
    FutureProvider.family<List<SubjectListItem>, ({String type, int id})>((
      ref,
      arg,
    ) async {
      final client = ref.read(apiClientProvider);
      final raw = await client.get(
        arg.type == 'person'
            ? apiV0PersonSubjects(arg.id)
            : apiV0CharacterSubjects(arg.id),
      );
      return (raw as List)
          .whereType<Map<String, dynamic>>()
          .map(SubjectListItem.fromJson)
          .toList();
    });

/// 人物饰演角色: 主站 HTML /person/{id}/works/voice
final personVoicesProvider =
    FutureProvider.family<MonoVoicesPage, ({int id, String position})>((
      ref,
      arg,
    ) async {
      final client = ref.read(apiClientProvider);
      final body = await client.get(
        htmlMonoVoices(arg.id, position: arg.position),
        host: kHost,
      );
      return parseMonoVoices(body as String);
    });

/// 人物作品: 主站 HTML /{person|character}/{id}/works
final monoWorksProvider =
    FutureProvider.family<
      MonoWorksPage,
      ({String type, int id, String position, String sort})
    >((ref, arg) async {
      final client = ref.read(apiClientProvider);
      final body = await client.get(
        htmlMonoWorks(arg.type, arg.id, position: arg.position, sort: arg.sort),
        host: kHost,
      );
      return parseMonoWorks(body as String);
    });

/// 人物详情「最近演出角色」预览
final personRecentVoicesProvider =
    FutureProvider.family<List<MonoVoiceItem>, int>((ref, id) async {
      final client = ref.read(apiClientProvider);
      final body = await client.get(htmlPersonPage(id), host: kHost);
      return parsePersonRecentVoices(body as String);
    });

/// 角色吐槽箱: 主站 HTML /character/{id}
final monoCommentsProvider = FutureProvider.family<CommentPage, int>((
  ref,
  id,
) async {
  final client = ref.read(apiClientProvider);
  final body = await client.get(htmlCharacterPage(id), host: kHost);
  return parseTopicCommentsHtml(body as String);
});

/// 人物收藏动作: 主站 HTML collectUrl / eraseCollectUrl
final monoCollectProvider =
    FutureProvider.family<
      ({String collectUrl, String eraseCollectUrl}),
      ({String type, int id})
    >((ref, arg) async {
      final client = ref.read(apiClientProvider);
      final body = await client.get(
        arg.type == 'person'
            ? htmlPersonPage(arg.id)
            : htmlCharacterPage(arg.id),
        host: kHost,
      );
      return parseMonoCollect(body as String);
    });

/// 分类排行 (typerank): /v0/subjects?tag=&type=
final typerankProvider =
    FutureProvider.family<List<SubjectListItem>, ({String type, String tag})>((
      ref,
      arg,
    ) async {
      final client = ref.read(apiClientProvider);
      final raw = await client.get(apiV0TagSubjects(arg.type, arg.tag));
      final map = raw as Map<String, dynamic>;
      return (map['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(SubjectListItem.fromJson)
          .toList();
    });

/// 包含该条目的目录: 主站 HTML /subject/{id}/index
final catalogsProvider = FutureProvider.family<List<CatalogItem>, int>((
  ref,
  id,
) async {
  final client = ref.read(apiClientProvider);
  final body = await client.get(htmlSubjectCatalogs(id), host: kHost);
  return parseCatalogsHtml(body as String);
});

/// 条目讨论版: 主站 HTML /subject/{id}/board (与小组论坛同表结构)
final subjectBoardProvider = FutureProvider.family<List<RakuenTopicItem>, int>((
  ref,
  id,
) async {
  final client = ref.read(apiClientProvider);
  final body = await client.get(htmlSubjectBoard(id), host: kHost);
  return parseGroupForum(body as String);
});

/// 巡礼地点 (anitabi.cn lite)
final anitabiLiteProvider = FutureProvider.family<List<AnitabiSpot>, int>((
  ref,
  id,
) async {
  try {
    final body = await _plainGet(apiAnitabi(id));
    final decoded = jsonDecode(body);
    final List<dynamic> list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map) {
      final raw = decoded['lite'] ?? decoded['points'] ?? decoded['data'];
      list = raw is List ? raw : const <dynamic>[];
    } else {
      list = const <dynamic>[];
    }
    return [
      for (final raw in list.whereType<Map>())
        AnitabiSpot(
          name: (raw['name'] ?? raw['cn'] ?? raw['origin'] ?? '').toString(),
          address: (raw['address'] ?? raw['city'] ?? '').toString(),
        ),
    ].where((e) => e.name.isNotEmpty).take(8).toList();
  } catch (_) {
    return const [];
  }
});

/// 维基修订历史: 主站 HTML /subject/{id}/edit
final wikiProvider = FutureProvider.family<List<WikiEdit>, int>((
  ref,
  id,
) async {
  final client = ref.read(apiClientProvider);
  final body = await client.get(htmlSubjectWikiEdit(id), host: kHost);
  return parseWikiEditsHtml(body as String);
});

/// bangumi-data 索引 (缓存整个文件, 供预览截图查找 bilibili season)
class BangumiDataIndex {
  final Map<int, int> bilibiliSeasons; // bangumi subjectId -> bilibili seasonId
  final Map<int, String> titles; // bangumi subjectId -> 标题

  const BangumiDataIndex({
    this.bilibiliSeasons = const {},
    this.titles = const {},
  });
}

Future<BangumiDataIndex>? _bangumiDataFuture;

final bangumiDataProvider = FutureProvider<BangumiDataIndex>((ref) {
  return _bangumiDataFuture ??= _loadBangumiData(ref);
});

Future<BangumiDataIndex> _loadBangumiData(Ref ref) async {
  final body = await _plainGet(kBangumiDataUrl);
  final root = jsonDecode(body) as Map<String, dynamic>;
  final items = root['items'] as List? ?? const [];
  final seasons = <int, int>{};
  final titles = <int, String>{};
  for (final item in items.whereType<Map<String, dynamic>>()) {
    final sites = item['sites'] as List? ?? const [];
    int? bangumiId;
    int? biliSeason;
    for (final site in sites.whereType<Map<String, dynamic>>()) {
      final name = site['site'] as String? ?? '';
      final id =
          int.tryParse(
            (site['id'] as String? ?? '').replaceAll(RegExp(r'\D'), ''),
          ) ??
          0;
      if (name == 'bangumi') bangumiId = id;
      if (name == 'bilibili' && id > 0) biliSeason = id;
    }
    if (bangumiId != null && biliSeason != null) {
      seasons[bangumiId] = biliSeason;
      titles[bangumiId] = item['title'] as String? ?? '';
    }
  }
  return BangumiDataIndex(bilibiliSeasons: seasons, titles: titles);
}

/// 番剧截图预览: bangumi-data 找 bilibili season → bilibili API 取封面
final previewProvider = FutureProvider.family<List<PreviewImage>, int>((
  ref,
  id,
) async {
  final index = await ref.watch(bangumiDataProvider.future);
  final seasonId = index.bilibiliSeasons[id];
  if (seasonId == null) return const [];

  final body = await _plainGet(apiBilibiliSeasonSection(seasonId));
  final map = jsonDecode(body) as Map<String, dynamic>;
  final result = map['result'] as Map<String, dynamic>? ?? const {};
  final sections = [
    ...?((result['main_section'] as Map<String, dynamic>?)?['episodes']
        as List?),
    ...?((result['section'] as List?)?.expand(
      (e) => (e as Map<String, dynamic>)['episodes'] as List? ?? const [],
    )),
  ];
  final urls = <String>[];
  for (final ep in sections.whereType<Map<String, dynamic>>()) {
    final cover = ep['cover'] as String? ?? '';
    if (cover.isNotEmpty) {
      urls.add(
        cover.startsWith('http://')
            ? cover.replaceFirst('http://', 'https://')
            : cover,
      );
    }
  }
  return urls
      .map((u) => PreviewImage(url: u, referer: 'https://www.bilibili.com/'))
      .toList();
});

// ---------------------------------------------------------------------------
// 收藏 / 章节进度 动作
// ---------------------------------------------------------------------------

/// 更新收藏: POST /collection/{id}/update
///
/// [privacy] 0=公开 1=私密 (原项目 manage-modal)
Future<void> updateCollectionAction(
  WidgetRef ref,
  int subjectId, {
  required int type,
  int rate = 0,
  String comment = '',
  List<String> tags = const [],
  int epStatus = 0,
  int privacy = 0,
}) async {
  final client = ref.read(apiClientProvider);
  await client.post(
    apiCollectionAction(subjectId, 'update'),
    data: FormData.fromMap({
      'type': type,
      'rate': rate,
      'comment': comment,
      'tags': tags.join(' '),
      'ep_status': epStatus,
      'privacy': privacy,
    }),
  );
}

/// 删除收藏: POST /collection/{id}/remove
Future<void> removeCollectionAction(WidgetRef ref, int subjectId) async {
  final client = ref.read(apiClientProvider);
  await client.post(apiCollectionAction(subjectId, 'remove'));
}

/// 单集状态: POST /ep/{id}/status/{watched|queue|drop|remove}
/// 对齐原项目 MODEL_EP_STATUS / doUpdateEpStatus
Future<void> setEpStatusAction(WidgetRef ref, int epId, String status) async {
  final client = ref.read(apiClientProvider);
  await client.post(apiEpStatus(epId, status));
}

/// 批量更新进度: POST /subject/{id}/update/watched_eps
Future<void> updateWatchedEpsAction(
  WidgetRef ref,
  int subjectId,
  int watchedEps, {
  int? watchedVols,
}) async {
  final client = ref.read(apiClientProvider);
  await client.post(
    apiSubjectUpdateWatched(subjectId),
    data: FormData.fromMap({
      'watched_eps': watchedEps,
      'watched_vols': ?watchedVols,
    }),
  );
}

/// 收藏动作后刷新相关数据
void invalidateSubjectState(WidgetRef ref, int subjectId) {
  ref.invalidate(collectionProvider(subjectId));
  ref.invalidate(
    subjectCommentsProvider((
      id: subjectId,
      page: 1,
      interestType: '',
      version: false,
    )),
  );

  ref.invalidate(ratingStatsProvider(subjectId));
}
