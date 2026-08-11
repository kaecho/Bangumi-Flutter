/// 所有 API 端点定义 (移植自原项目 src/constants/api)
/// 单一数据源: 所有请求都必须使用这里定义的端点
library;

/// 官方 API 域名 (主 + 备用)
const String kApiHost = 'https://api.bgmapi.com';
const String kApiHostBackup = 'https://api.bgm.tv';

/// v0 API (新版 JSON API)
const String kApiV0 = '$kApiHost/v0';

/// p1 API (next)
const String kApiP1 = 'https://next.bgm.tv/p1';

/// 主站
const String kHost = 'https://bgm.tv';

/// 图片域名
const String kLainHost = '//lain.bgm.tv';

/// 小圣杯
const String kTinygrailHost = 'https://tinygrail.com';

/// OAuth
const String kAppId = 'bgm8885c4d524cd61fc';
const String kAppSecret = '1da52e7834bbb73cca90302f9ddbc8dd';
const String kOauthRedirect = 'https://bgm.tv/dev/app';
const String kApiAccessToken = '$kHost/oauth/access_token';
const String kOauthAuthorize =
    '$kHost/oauth/authorize?client_id=$kAppId&response_type=code&redirect_uri=$kOauthRedirect';

/// 小圣杯 OAuth
const String kTinygrailAppId = 'bgm2525b0e4c7d93fec';
const String kTinygrailOauthRedirect = 'https://tinygrail.com/api/account/callback';

/// 用户相关
String apiUserInfo(String userId) => '$kApiHost/user/$userId';
String apiUserCollection(String userId) => '$kApiHost/user/$userId/collection';
String apiUserCollections(String subjectType, String userId) =>
    '$kApiHost/user/$userId/collections/$subjectType';
String apiUserCollectionsStatus(String userId) => '$kApiHost/user/$userId/collections/status';
String apiUserProgress(String userId) => '$kApiHost/user/$userId/progress';
String apiUserFriends(String userId) => '$kApiHost/user/$userId/friends';
String apiUserTimeline(String userId, int maxResults) =>
    '$kApiHost/user/$userId/timeline?max_results=$maxResults';

/// 条目 / 章节
String apiSubject(int subjectId) => '$kApiHost/subject/$subjectId';
String apiSubjectEp(int subjectId) => '$kApiHost/subject/$subjectId/ep';
String apiSubjectCharacters(int subjectId) => '$kApiHost/subject/$subjectId/characters';
String apiSubjectPersons(int subjectId) => '$kApiHost/subject/$subjectId/persons';
String apiSubjectRelations(int subjectId) => '$kApiHost/subject/$subjectId/relations';
String apiSubjectSubjects(int subjectId) => '$kApiHost/subject/$subjectId/subjects';
String apiSubjectTags(int subjectId) => '$kApiHost/subject/$subjectId/tags';
String apiSubjectComments(int subjectId) => '$kApiHost/subject/$subjectId/comments';
String apiSubjectReviews(int subjectId) => '$kApiHost/subject/$subjectId/reviews';
String apiSubjectBlogs(int subjectId) => '$kApiHost/subject/$subjectId/blogs';
String apiSubjectUpdateWatched(int subjectId) => '$kApiHost/subject/$subjectId/update/watched_eps';
String apiEpStatus(int epId, int status) => '$kApiHost/ep/$epId/status/$status';

/// 收藏
String apiCollection(int subjectId) => '$kApiHost/collection/$subjectId';
String apiCollectionAction(int subjectId, String action) =>
    '$kApiHost/collection/$subjectId/$action';

/// 角色 / 人物
String apiCharacter(int id) => '$kApiHost/character/$id';
String apiCharacterSubjects(int id) => '$kApiHost/character/$id/subjects';
String apiPerson(int id) => '$kApiHost/person/$id';
String apiPersonSubjects(int id) => '$kApiHost/person/$id/subjects';

/// 小组 / 讨论
String apiGroup(String name) => '$kApiHost/group/$name';
String apiGroupTopics(String name) => '$kApiHost/group/$name/topics';
String apiGroupMembers(String name) => '$kApiHost/group/$name/members';
String apiTopic(String topicId) => '$kApiHost/topic/$topicId';
String apiTopicNewReply(String topicId) => '$kApiHost/topic/$topicId/new_reply';
String apiBlog(String blogId) => '$kApiHost/blog/$blogId';
String apiBlogNewReply(String blogId) => '$kApiHost/blog/$blogId/new_reply';
String apiComment(int id) => '$kApiHost/comment/$id';
String apiSearch(String keywords) => '$kApiHost/search/subject/$keywords';

/// 超展开
String apiRakuenBoard() => '$kApiHost/rakuen/board';
String apiRakuenTopics({int? board, int page = 1}) =>
    '$kApiHost/rakuen/topics?page=$page${board != null ? '&board=$board' : ''}';
String apiRakuenGroupTopics(String name, {int page = 1}) =>
    '$kApiHost/rakuen/group/$name/topics?page=$page';
String apiRakuenTopicComments(int topicId, {int page = 1}) =>
    '$kApiHost/rakuen/topic/$topicId/comments?page=$page';
String apiRakuenNewReplies(String topicId) => '$kApiHost/rakuen/topic/$topicId/new_replies';

/// 时间线 / 吐槽
String apiTimeline() => '$kApiHost/timeline';
String apiTimelineType(String type, {int page = 1}) =>
    '$kApiHost/timeline/$type?page=$page';
String apiSay(int id) => '$kApiHost/say/$id';
String apiTimelineComments(int id) => '$kApiHost/timeline/$id/comments';

/// 搜索 (多重)
String apiSearchMulti() => '$kApiHost/search/multi';

/// 排行榜 / 标签
String apiRank(String type, String order, String tag, {int page = 1}) =>
    '$kApiHost/rank/subject/$type/$order/$tag?page=$page';
String apiTag(String type) => '$kApiHost/tag/$type';
String apiTagSubjects(String type, String tag, {int page = 1}) =>
    '$kApiHost/tag/$type/$tag?page=$page';

/// 每日放送
String apiCalendar() => '$kApiHost/calendar';

/// 其他
String apiUserBlogs(String userId) => '$kApiHost/user/$userId/blogs';
String apiUserCatalogs(String userId) => '$kApiHost/user/$userId/catalogs';
String apiUserCollection2(String userId) => '$kApiHost/user/$userId/collection2';
String apiUserCollectionsStatus2(String userId) => '$kApiHost/user/$userId/collections/status2';
String apiUserMono(String userId) => '$kApiHost/user/$userId/mono';
String apiUserSay(String userId) => '$kApiHost/user/$userId/say';
String apiUserRoles(String userId) => '$kApiHost/user/$userId/roles';
String apiUserNetwork(String userId) => '$kApiHost/user/$userId/network';
String apiUserLikes(String userId) => '$kApiHost/user/$userId/likes';

/// v0
String apiV0Me() => '$kApiV0/me';
String apiV0Users(String userId) => '$kApiV0/users/$userId';
String apiV0UsersCollections(String userId, String subjectType, int limit, int offset, String type) =>
    '$kApiV0/users/$userId/collections?subject_type=$subjectType&type=$type&limit=$limit&offset=$offset';
String apiV0UsersCollection(String userId, int subjectId) =>
    '$kApiV0/users/$userId/collections/$subjectId';
String apiV0UsersEpisodes(String userId, int subjectId) =>
    '$kApiV0/users/$userId/collections/$subjectId/episodes';
String apiV0SubjectImage(int subjectId, String type) =>
    '$kApiV0/subjects/$subjectId/image?type=$type';

/// p1
String apiP1UsersTimeline(String userId) => '$kApiP1/users/$userId/timeline';

/// 电波提醒 (站内信)
String apiNotifyCount() => '$kApiHost/notify/count';
String apiNotify() => '$kApiHost/notify';
String apiPm() => '$kApiHost/pm';
String apiPmChat() => '$kApiHost/pm/chat';
String apiPmSend() => '$kApiHost/pm/send';

/// 其他站点同步
String apiBilibiliSync() => '$kApiHost/bilibili/sync';
String apiDoubanSync() => '$kApiHost/douban/sync';

/// 小圣杯
String apiTinygrailCharaList() => '$kTinygrailHost/api/chara/list';
String apiTinygrailChara(int monoId) => '$kTinygrailHost/api/chara/$monoId';
String apiTinygrailDepth(int monoId) => '$kTinygrailHost/api/chara/depth/$monoId';
String apiTinygrailCharaPool(int monoId) => '$kTinygrailHost/api/chara/pool/$monoId';
String apiTinygrailList(String type, int page, int limit) =>
    '$kTinygrailHost/api/chara/$type/$page/$limit';
String apiTinygrailValhallaList(int page, int limit) =>
    '$kTinygrailHost/api/valhalla/$page/$limit';
String apiTinygrailFantasyList(int page, int limit) =>
    '$kTinygrailHost/api/fantasy/$page/$limit';
String apiTinygrailRefineTemple() => '$kTinygrailHost/api/temple/refine';
String apiTinygrailRich(int page, int limit) => '$kTinygrailHost/api/rich/$page/$limit';
String apiTinygrailStar(int page, int limit) => '$kTinygrailHost/api/star/$page/$limit';
String apiTinygrailStarLogs(int page, int limit) => '$kTinygrailHost/api/star/logs/$page/$limit';
String apiTinygrailCharts(int monoId, String start) =>
    '$kTinygrailHost/api/chara/charts/$monoId?start=$start';
String apiTinygrailIssuePrice(int monoId) => '$kTinygrailHost/api/issue/price/$monoId';
String apiTinygrailLogout() => '$kTinygrailHost/api/account/logout';
String apiTinygrailHash() => '$kTinygrailHost/api/account/recommend';
String apiTinygrailAssets(String hash) => '$kTinygrailHost/api/user/assets/$hash';
String apiTinygrailCharaAssets(String hash) => '$kTinygrailHost/api/user/chara/assets/$hash';
String apiTinygrailUserChara(int monoId) => '$kTinygrailHost/api/user/chara/$monoId';
String apiTinygrailCharaAll(String hash) => '$kTinygrailHost/api/chara/all/$hash';
String apiTinygrailTemple(String hash) => '$kTinygrailHost/api/temple/$hash';
String apiTinygrailValhallaChara(int monoId) => '$kTinygrailHost/api/valhalla/chara/$monoId';
String apiTinygrailUserTempleTotal(String hash) => '$kTinygrailHost/api/user/temple/total/$hash';
String apiTinygrailUserCharaTotal(String hash) => '$kTinygrailHost/api/user/chara/total/$hash';
String apiTinygrailBid(int monoId, int price, int amount) =>
    '$kTinygrailHost/api/chara/bid/$monoId/$price/$amount';
String apiTinygrailAsk(int monoId, int price, int amount) =>
    '$kTinygrailHost/api/chara/ask/$monoId/$price/$amount';
String apiTinygrailCancelBid(int id) => '$kTinygrailHost/api/chara/bid/cancel/$id';
String apiTinygrailCancelAsk(int id) => '$kTinygrailHost/api/chara/ask/cancel/$id';
String apiTinygrailMyCharaAssets() => '$kTinygrailHost/api/chara/assets/0/1/1000';
String apiTinygrailBalance(int page) => '$kTinygrailHost/api/balance/$page';
String apiTinygrailInit(int monoId) => '$kTinygrailHost/api/init/$monoId';
String apiTinygrailInitial(int icoId, int page) =>
    '$kTinygrailHost/api/initial/$icoId/$page/400';
String apiTinygrailJoin(int icoId, int amount) => '$kTinygrailHost/api/join/$icoId/$amount';
String apiTinygrailUsers(int monoId) => '$kTinygrailHost/api/users/$monoId/0/200';
String apiTinygrailCharaTemple(int monoId) => '$kTinygrailHost/api/chara/temple/$monoId';
String apiTinygrailTempleLast(int page, int limit) =>
    '$kTinygrailHost/api/temple/last/$page/$limit';
String apiTinygrailMyTemple(String hash, int keyword) =>
    '$kTinygrailHost/api/temple/my/$hash/$keyword';
String apiTinygrailSacrifice(int monoId, int amount, bool isSale) =>
    '$kTinygrailHost/api/chara/sacrifice/$monoId/$amount/${isSale ? 1 : 0}';
String apiTinygrailAuction(int page, int limit) =>
    '$kTinygrailHost/api/auction/list/$page/$limit';
String apiTinygrailAuctionBid(int auctionId, int price) =>
    '$kTinygrailHost/api/auction/bid/$auctionId/$price';

/// 第三方
String apiMosaicTile(String username, String type) =>
    'https://bangumi-mosaic-tile.aho.im/users/$username/timelines/$type.json';
String apiSetu(int num) =>
    'https://api.lolicon.app/setu/v2?r18=0&num=$num&size=small&dateAfter=1609459200000';
String apiRandomAvatar() => 'https://api.yimian.xyz/img?type=head';
String apiAnitabi(int subjectId) => 'https://api.anitabi.cn/bangumi/$subjectId/lite';
String apiBgmStatus() => 'https://bgm-status.ry.mk';

/// 图片: 条目封面
String coverUrl(String url, {String size = 'm'}) {
  if (url.isEmpty) return '';
  return url
      .replaceAll('/pic/cover/', '/pic/cover/$size/')
      .replaceAll('/pic/crt/', '/pic/crt/$size/');
}
