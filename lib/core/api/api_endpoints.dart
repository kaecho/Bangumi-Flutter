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

/// v0 条目 (详情含 infobox/tags/eps)
String apiV0Subject(int subjectId) => '$kApiV0/subjects/$subjectId?responseGroup=large';
String apiV0SubjectCharacters(int subjectId) => '$kApiV0/subjects/$subjectId/characters';
String apiV0SubjectPersons(int subjectId) => '$kApiV0/subjects/$subjectId/persons';
String apiV0SubjectSeries(int subjectId) => '$kApiV0/subjects/$subjectId/subjects';

/// v0 角色 / 人物
String apiV0Character(int id) => '$kApiV0/characters/$id';
String apiV0CharacterSubjects(int id) => '$kApiV0/characters/$id/subjects';
String apiV0Person(int id) => '$kApiV0/persons/$id';
String apiV0PersonSubjects(int id) => '$kApiV0/persons/$id/subjects';

/// v0 标签搜索条目 (typerank)
String apiV0TagSubjects(String type, String tag, {int limit = 30, int offset = 0}) =>
    '$kApiV0/subjects?tag=${Uri.encodeComponent(tag)}&type=$type&limit=$limit&offset=$offset';

/// 主站 HTML 页面 (吐槽箱 / 目录 / 维基 / 预览)
String htmlSubjectComments(int subjectId, {int page = 1}) =>
    '$kHost/subject/$subjectId/comments?page=$page';
String htmlEpPage(int epId) => '$kHost/ep/$epId';
String htmlCharacterPage(int id) => '$kHost/character/$id';
String htmlSubjectCatalogs(int subjectId, {int page = 1}) =>
    '$kHost/subject/$subjectId/index?page=$page';
String htmlSubjectWikiEdit(int subjectId) => '$kHost/subject/$subjectId/edit';

/// 第三方: 番剧截图预览 (bangumi-data + bilibili)
const String kBangumiDataUrl =
    'https://cdn.jsdelivr.net/gh/bangumi-data/bangumi-data@master/dist/data.json';
String apiBilibiliSeasonSection(int seasonId) =>
    'https://api.bilibili.com/pgc/web/season/section?season_id=$seasonId';

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
String apiGroupJoin(String name) => '$kApiHost/group/$name/join';
String apiTopic(String topicId) => '$kApiHost/topic/$topicId';
String apiTopicNewReply(String topicId) => '$kApiHost/topic/$topicId/new_reply';
String apiBlog(String blogId) => '$kApiHost/blog/$blogId';
String apiBlogNewReply(String blogId) => '$kApiHost/blog/$blogId/new_reply';
String apiComment(int id) => '$kApiHost/comment/$id';
String apiSearch(String keywords) => '$kApiHost/search/subject/$keywords';
String apiSearchTopic(String keywords, {int page = 1}) =>
    '$kApiHost/search/topic/$keywords?page=$page';
String apiUserTopics(String userId) => '$kApiHost/user/$userId/topics';

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

/// 点赞 (站内 ajax 接口, 需 host: [kHost])
/// type: LIKE_TYPE_TIMELINE=40 / LIKE_TYPE_SAY=50; main_id: 吐槽/条目 id
String apiLike(int type, int mainId) => '/like?type=$type&main_id=$mainId&ajax=1';

/// GitHub Releases (需 host: [kGithubApiHost])
const String kGithubApiHost = 'https://api.github.com';
const String kGithubRepo = 'kaecho/Bangumi-Flutter';
String apiGithubReleasesLatest() => '/repos/$kGithubRepo/releases/latest';

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

/// 小圣杯 (live API 正确路径; 与上方旧版 apiTinygrail* 并存, 均为新增)
/// 角色列表: type = mvc 最高市值 / mrc 最大涨幅 / mfc 最大跌幅 / msrc 最高股息 /
/// mvi ico资金 / mpi ico人气 / mri ico结束 / rai ico活跃 / recent 最近活跃 /
/// nbc 新番活跃 / tnbc 新番市值 / bid 买盘 / asks 卖盘
String apiTinygrailRankList(String type, int page, int limit) =>
    '$kTinygrailHost/api/chara/$type/$page/$limit';

/// 角色详情
String apiTinygrailCharaDetail(int monoId) => '$kTinygrailHost/api/chara/$monoId';

/// 深度图
String apiTinygrailCharaDepth(int monoId) => '$kTinygrailHost/api/chara/depth/$monoId';

/// 奖池
String apiTinygrailCharaPool2(int monoId) => '$kTinygrailHost/api/chara/pool/$monoId';

/// K 线 (date 形如 2026-08-11T00:00:00+08:00 或 2026-08-11)
String apiTinygrailCharts2(int monoId, String date) =>
    '$kTinygrailHost/api/chara/charts/$monoId/$date';

/// 发行价 (历史第一笔成交)
String apiTinygrailIssuePrice2(int monoId) =>
    '$kTinygrailHost/api/chara/charts/$monoId/2021-08-08';

/// 英灵殿
String apiTinygrailValhalla(int page, int limit) =>
    '$kTinygrailHost/api/chara/user/chara/tinygrail/$page/$limit';

/// 幻想乡
String apiTinygrailFantasy(int page, int limit) =>
    '$kTinygrailHost/api/chara/user/chara/blueleaf/$page/$limit';

/// 精炼排行
String apiTinygrailRefineRank(int page, int limit) =>
    '$kTinygrailHost/api/chara/refine/temple/$page/$limit';

/// 番市首富
String apiTinygrailRichList(int page, int limit) => '$kTinygrailHost/api/chara/top/$page/$limit';

/// 圣星 (通天塔)
String apiTinygrailBabel(int page, int limit) => '$kTinygrailHost/api/chara/babel/$page/$limit';

/// 圣星记录
String apiTinygrailStarLogList(int page, int limit) =>
    '$kTinygrailHost/api/chara/star/log/$page/$limit';

/// 每周萌王
String apiTinygrailTopWeek() => '$kTinygrailHost/api/chara/topweek';

/// 每周萌王历史 (一页含两周数据)
String apiTinygrailTopWeekHistory(int prev) =>
    '$kTinygrailHost/api/chara/topweek/history/$prev';

/// 搜索
String apiTinygrailSearch2(String keyword) => '$kTinygrailHost/api/chara/search?keyword=$keyword';

/// 用户资产 (hash 为空表示自己)
String apiTinygrailUserAssets(String hash) =>
    '$kTinygrailHost/api/chara/user/assets${hash.isEmpty ? '' : '/$hash'}';

/// 用户资产概览 (characters + initials)
String apiTinygrailUserCharaAssets2(String hash) =>
    '$kTinygrailHost/api/chara/user/assets/$hash/true';

/// 我的持仓 (只显示有流动股的角色)
String apiTinygrailMyCharaAssets2() => '$kTinygrailHost/api/chara/user/assets/0/true';

/// 用户挂单和交易记录
String apiTinygrailCharaUserLogs(int monoId) => '$kTinygrailHost/api/chara/user/$monoId';

/// 用户所有角色信息
String apiTinygrailUserCharaAll2(String hash) =>
    '$kTinygrailHost/api/chara/user/chara/$hash/1/1000';

/// 用户所有圣殿信息
String apiTinygrailUserTemple2(String hash) =>
    '$kTinygrailHost/api/chara/user/temple/$hash/1/1000';

/// 用户圣殿数量
String apiTinygrailUserTempleTotal2(String hash) =>
    '$kTinygrailHost/api/chara/user/temple/$hash/1/1';

/// 用户角色数量
String apiTinygrailUserCharaTotal2(String hash) =>
    '$kTinygrailHost/api/chara/user/chara/$hash/1/1';

/// 可拍卖信息
String apiTinygrailValhallaChara2(int monoId) =>
    '$kTinygrailHost/api/chara/user/$monoId/tinygrail/false';

/// 我的买单
String apiTinygrailMyBids() => '$kTinygrailHost/api/chara/bids/0/1/800';

/// 我的卖单
String apiTinygrailMyAsks() => '$kTinygrailHost/api/chara/asks/0/1/800';

/// 我的拍卖列表
String apiTinygrailMyAuction() => '$kTinygrailHost/api/chara/user/auction/1/200';

/// [POST] 当前拍卖状态 (body 为角色 ID 数组)
String apiTinygrailAuctionStatus() => '$kTinygrailHost/api/chara/auction/list';

/// [POST] 竞拍
String apiTinygrailAuctionBid2(int monoId, int price, int amount) =>
    '$kTinygrailHost/api/chara/auction/$monoId/$price/$amount';

/// [POST] 取消竞拍
String apiTinygrailAuctionCancel(int id) => '$kTinygrailHost/api/chara/auction/cancel/$id';

/// 上周拍卖结果
String apiTinygrailAuctionLastWeek(int monoId) =>
    '$kTinygrailHost/api/chara/auction/list/$monoId/1';

/// 资金日志
String apiTinygrailBalance2(int page) => '$kTinygrailHost/api/chara/user/balance/$page/200';

/// [POST] 启动 ICO
String apiTinygrailInit2(int monoId) => '$kTinygrailHost/api/chara/init/$monoId/10000';

/// ICO 参与者
String apiTinygrailInitialUsers(int icoId, int page) =>
    '$kTinygrailHost/api/chara/initial/users/$icoId/$page';

/// [POST] 参与 ICO
String apiTinygrailJoin2(int icoId, int amount) => '$kTinygrailHost/api/chara/join/$icoId/$amount';

/// 董事会
String apiTinygrailUsers2(int monoId) => '$kTinygrailHost/api/chara/users/$monoId/1/80';

/// 最近圣殿
String apiTinygrailTempleLast2(int page, int limit) =>
    '$kTinygrailHost/api/chara/temple/last/$page/$limit';

/// 我的某角色圣殿
String apiTinygrailMyTemple2(String hash, int keyword) =>
    '$kTinygrailHost/api/chara/user/temple/$hash/1/1?keyword=$keyword';

/// [POST] 灌注星之力
String apiTinygrailCharaStar2(int monoId, int amount) =>
    '$kTinygrailHost/api/chara/star/$monoId/$amount';

/// [POST] 角色关联
String apiTinygrailLink(int monoId, int toMonoId) =>
    '$kTinygrailHost/api/chara/link/$monoId/$toMonoId';

/// [POST] 批量获取角色 (body 为角色 ID 数组)
String apiTinygrailCharaList2() => '$kTinygrailHost/api/chara/list';

/// 我的道具
String apiTinygrailMyItems() => '$kTinygrailHost/api/chara/user/item/0/1/50';

/// [POST] 使用道具 (type: chaos/guidepost/stardust/starbreak/fisheye/refine)
String apiTinygrailMagic(int monoId, String type, int toMonoId, int amount, bool isTemple) =>
    '$kTinygrailHost/api/chara/magic/$monoId/$type/$toMonoId/$amount/${isTemple ? 1 : 0}';

/// 环保刮刮乐
String apiTinygrailScratch() => '$kTinygrailHost/api/event/scratch/bonus2';

/// 今日刮刮乐次数
String apiTinygrailDailyCount() => '$kTinygrailHost/api/event/daily/count/10';

/// 小圣杯 OAuth 授权页 (bgm.tv 登录授权)
String kTinygrailOauthAuthorize() =>
    '$kHost/oauth/authorize?client_id=$kTinygrailAppId&response_type=code&redirect_uri=$kTinygrailOauthRedirect';

/// 发现页: 目录 / 日志 / 小组 / 维基 / 系列
String apiIndexList({int page = 1}) => '$kApiHost/index/list?page=$page';
String apiIndex(int id, {String orderby = 'rank'}) => '$kApiHost/index/$id?orderby=$orderby';
String apiBlogList({int page = 1}) => '$kApiHost/blog/list?page=$page';
String apiGroupList({int page = 1}) => '$kApiHost/group/list?page=$page';
String apiWikiTop() => '$kApiHost/wiki/top';
String apiUserSeries(String userId) => '$kApiHost/user/$userId/series';
String apiUserRecommend(String userId) => '$kApiHost/user/$userId/recommend';
String apiUserCharacters(String userId) => '$kApiHost/user/$userId/characters';
String apiUserCollectionsSmall(String userId, int limit, int offset) =>
    '$kApiHost/user/$userId/collections?limit=$limit&offset=$offset&responseGroup=small';

/// 发现页: 新番 (bgm.tv 主站 JSON 接口, 调用时传 host: kHost)
String apiAnimeBrowser({int? year, int? month, String? sort, int? page, String? type}) {
  final query = <String>[
    if (year != null) 'year=$year',
    if (month != null) 'month=$month',
    if (sort != null && sort.isNotEmpty) 'sort=$sort',
    if (page != null) 'page=$page',
    if (type != null && type.isNotEmpty) 'type=$type',
  ].join('&');
  return '/anime/browser${query.isEmpty ? '' : '?$query'}';
}

/// 每日放送放送时间 (bangumi-data 开源数据, 与原项目 onAir 同源; 调用时传 host: 'https://bangumi-data.github.io')
String apiBangumiData() => '/bangumi-data/data.json';

/// 第三方
String apiMosaicTile(String username, String type) =>
    'https://bangumi-mosaic-tile.aho.im/users/$username/timelines/$type.json';
String apiSetu(int num) =>
    'https://api.lolicon.app/setu/v2?r18=0&num=$num&size=small&dateAfter=1609459200000';
String apiRandomAvatar() => 'https://api.yimian.xyz/img?type=head';
String apiAnitabi(int subjectId) => 'https://api.anitabi.cn/bangumi/$subjectId/lite';
String apiBgmStatus() => 'https://bgm-status.ry.mk';

/// 用户域: 主站 HTML 页面 (调用时传 host: kHost)
/// 旧版 JSON API 已下线, 日志/好友/目录/时光机/短信仅主站提供
String apiUserTimelineHtml(String userId, {String type = 'all', int page = 1}) =>
    '$kHost/user/$userId/timeline?type=$type&page=$page&ajax=1';
String apiUserBlogsHtml(String userId, {int page = 1}) =>
    '$kHost/user/$userId/blog?page=$page';
String apiUserCatalogsHtml(String userId, {int page = 1}) =>
    '$kHost/user/$userId/index?page=$page';
String apiUserFriendsHtml(String userId) => '$kHost/user/$userId/friends';
String apiUserMonoHtml(String userId, {String kind = 'character', int page = 1}) =>
    '$kHost/user/$userId/mono/$kind?page=$page';
String apiPmInboxHtml({int page = 1}) => '$kHost/pm/inbox.chii?page=$page';
String apiPmConversationHtml(int conversationId, {int page = 1, String? thread}) =>
    '$kHost/pm/conversation/$conversationId.chii?page=$page${thread != null ? '&thread=$thread' : ''}';
String apiPmComposeParamsHtml(String userId) => '$kHost/pm/compose/$userId.chii';
String apiPmCreateHtml() => '$kHost/pm/create.chii';

/// 图片: 条目封面
String coverUrl(String url, {String size = 'm'}) {
  if (url.isEmpty) return '';
  return url
      .replaceAll('/pic/cover/', '/pic/cover/$size/')
      .replaceAll('/pic/crt/', '/pic/crt/$size/');
}
