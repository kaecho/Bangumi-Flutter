import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import 'tinygrail_models.dart';

/// 小圣杯请求封装
///
/// tinygrail API 与 bgm API 独立: 响应统一为 `{State, Value, Message}` 信封,
/// 登录态为 OAuth 回调后 tinygrail 下发的 cookie (与原项目一致)。
/// 请求同时携带 bgm Bearer token (已登录时, 部分接口兼容) 与 tinygrail cookie。
class TinygrailApi {
  TinygrailApi(this._cookie) {
    _dio = Dio(BaseOptions(
      baseUrl: kTinygrailHost,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 15),
      headers: {'User-Agent': 'Bangumi/Flutter (https://github.com/kaecho/Bangumi-Flutter)'},
    ));
  }

  late final Dio _dio;
  String _cookie;

  String get cookie => _cookie;

  void setCookie(String cookie) => _cookie = cookie;

  /// 发起请求并解包 `{State, Value}` 信封; 返回 Value
  Future<dynamic> _unwrap(Future<Response<dynamic>> Function() run) async {
    final resp = await run();
    final data = resp.data;
    if (data is! Map<String, dynamic>) return data;
    final state = data['State'] as num? ?? 1;
    if (state != 0) {
      throw TinygrailException(data['Message'] as String? ?? '请求失败 ($state)');
    }
    return data['Value'];
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) {
    return _unwrap(() => _dio.getUri(
          Uri.parse('$kTinygrailHost$path').replace(queryParameters: query),
          options: _options(auth),
        ));
  }

  Future<dynamic> post(
    String path, {
    Object? data,
    bool auth = true,
  }) {
    return _unwrap(() => _dio.postUri(
          Uri.parse('$kTinygrailHost$path'),
          data: data,
          options: _options(auth),
        ));
  }

  Options _options(bool auth) {
    final headers = <String, String>{};
    if (_cookie.isNotEmpty) headers['Cookie'] = _cookie;
    if (auth) {
      final token = _token;
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    }
    return Options(headers: headers.isEmpty ? null : headers);
  }

  String? _token;
  set token(String? t) => _token = t;

  // -------------------- 登录 --------------------

  /// 获取用户 hash; 未登录返回空串
  Future<String> fetchHash() async {
    try {
      final value = await get(apiTinygrailHash());
      if (value is Map<String, dynamic>) {
        return value['Hash'] as String? ?? value['hash'] as String? ?? '';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  /// 用户资产 (自己)
  Future<TinygrailUser> fetchAssets([String hash = '']) async {
    final value = await get(apiTinygrailUserAssets(hash));
    return _userFrom(value);
  }

  TinygrailUser _userFrom(dynamic value) {
    if (value is! Map<String, dynamic>) return const TinygrailUser();
    return TinygrailUser(
      hash: value['Hash'] as String? ?? '',
      nickname: value['Nickname'] as String? ?? '',
      avatar: value['Avatar'] as String? ?? '',
      balance: (value['Balance'] as num?)?.toInt() ?? 0,
      principal: (value['Principal'] as num?)?.toInt() ?? 0,
      amount: (value['Assets'] ?? value['Amount'] ?? 0) as num as int,
      total: (value['Total'] ?? value['Assets'] ?? 0) as num as int,
      lastIndex: (value['LastIndex'] as num?)?.toInt() ?? 0,
    );
  }

  // -------------------- 角色 --------------------

  /// 角色详情
  Future<TinygrailChara> fetchChara(int monoId) async {
    final value = await get(apiTinygrailCharaDetail(monoId), auth: false);
    final map = value is Map<String, dynamic> ? value : <String, dynamic>{};
    return TinygrailChara.fromJson(map);
  }

  /// 批量角色 (POST body 为 ID 数组)
  Future<List<TinygrailChara>> fetchCharaByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final value = await post(apiTinygrailCharaList2(), data: ids);
    final list = value is List ? value : <dynamic>[];
    return list.map((e) => TinygrailChara.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 列表 (type 见 apiTinygrailRankList 注释)
  Future<List<TinygrailChara>> fetchList(String type, {int page = 1, int limit = 400}) async {
    final value = await get(apiTinygrailRankList(type, page, limit), auth: false);
    final list = value is List ? value : (value is Map && value['Items'] is List ? value['Items'] as List : <dynamic>[]);
    return list.map((e) => TinygrailChara.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// K 线
  Future<List<TinygrailKline>> fetchKline(int monoId, {String? date}) async {
    date ??= _today();
    final value = await get(apiTinygrailCharts2(monoId, date), auth: false);
    if (value is! List) return const [];
    return value.map((e) => TinygrailKline.fromJson(e as Map<String, dynamic>)).toList();
  }

  String _today() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}T00:00:00+08:00';
  }

  /// 发行价
  Future<int> fetchIssuePrice(int monoId) async {
    final value = await get(apiTinygrailIssuePrice2(monoId), auth: false);
    if (value is List && value.isNotEmpty) {
      return ((value.first as Map<String, dynamic>)['Begin'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  /// 深度
  Future<TinygrailDepth> fetchDepth(int monoId) async {
    final value = await get(apiTinygrailCharaDepth(monoId), auth: false);
    return value is Map<String, dynamic> ? TinygrailDepth.fromJson(value) : const TinygrailDepth();
  }

  /// 奖池
  Future<int> fetchPool(int monoId) async {
    final value = await get(apiTinygrailCharaPool2(monoId), auth: false);
    return (value as num?)?.toInt() ?? 0;
  }

  /// 搜索
  Future<List<TinygrailSearchItem>> search(String keyword) async {
    final value = await get(apiTinygrailSearch2(keyword), auth: false);
    if (value is! List) return const [];
    return value.map((e) => TinygrailSearchItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  // -------------------- 用户数据 --------------------

  /// 我的持仓 (chara + ico)
  Future<({List<TinygrailChara> chara, List<TinygrailChara> ico})> fetchMyCharaAssets() async {
    final value = await get(apiTinygrailMyCharaAssets2());
    if (value is! Map<String, dynamic>) return (chara: const [], ico: const []);
    List<TinygrailChara> parse(dynamic raw) => (raw is List)
        ? raw.map((e) => TinygrailChara.fromJson(e as Map<String, dynamic>)).toList()
        : const [];
    return (chara: parse(value['Characters']), ico: parse(value['Initials']));
  }

  /// 用户所有角色
  Future<List<TinygrailChara>> fetchCharaAll(String hash) async {
    final value = await get(apiTinygrailUserCharaAll2(hash));
    if (value is! Map<String, dynamic>) return const [];
    final items = value['Items'] as List? ?? const [];
    return items.map((e) => TinygrailChara.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 我的买单
  Future<List<TinygrailChara>> fetchMyBids() async {
    return _items(apiTinygrailMyBids());
  }

  /// 我的卖单
  Future<List<TinygrailChara>> fetchMyAsks() async {
    return _items(apiTinygrailMyAsks());
  }

  Future<List<TinygrailChara>> _items(String path) async {
    final value = await get(path);
    if (value is! Map<String, dynamic>) return const [];
    final items = value['Items'] as List? ?? const [];
    return items.map((e) => TinygrailChara.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 我的拍卖
  Future<List<TinygrailAuctionItem>> fetchMyAuction() async {
    final value = await get(apiTinygrailMyAuction());
    if (value is! Map<String, dynamic>) return const [];
    final items = value['Items'] as List? ?? const [];
    return items
        .map((e) => TinygrailAuctionItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 当前拍卖状态 (人数/股数)
  Future<({int state, int type})> fetchAuctionStatus(int monoId) async {
    try {
      final value = await post(apiTinygrailAuctionStatus(), data: [monoId]);
      if (value is List && value.isNotEmpty) {
        final item = value.first as Map<String, dynamic>;
        return (
          state: (item['State'] as num?)?.toInt() ?? 0,
          type: (item['Type'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (_) {}
    return (state: 0, type: 0);
  }

  /// 上周拍卖结果
  Future<List<TinygrailLog>> fetchAuctionLastWeek(int monoId) async {
    final value = await get(apiTinygrailAuctionLastWeek(monoId), auth: false);
    if (value is! List) return const [];
    return value
        .map((e) => TinygrailLog.fromJson({
              'Id': (e as Map<String, dynamic>)['CharacterId'],
              'CharacterId': e['CharacterId'],
              'Amount': e['Amount'],
              'Price': e['Price'],
              'Type': e['State'],
              'TradeTime': e['Bid'] ?? '',
            }))
        .toList();
  }

  /// 可拍卖信息 (英灵殿)
  Future<int> fetchValhallaChara(int monoId) async {
    try {
      final value = await get(apiTinygrailValhallaChara2(monoId));
      if (value is Map<String, dynamic>) {
        return (value['Amount'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  /// 资金日志
  Future<List<TinygrailBalance>> fetchBalance(int page) async {
    final value = await get(apiTinygrailBalance2(page));
    if (value is! Map<String, dynamic>) return const [];
    final items = value['Items'] as List? ?? const [];
    return items.map((e) => TinygrailBalance.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 用户挂单 + 交易记录
  Future<({
    List<TinygrailLog> bids,
    List<TinygrailLog> asks,
    List<TinygrailLog> bidHistory,
    List<TinygrailLog> askHistory,
    int sacrifices,
    int amount,
  })> fetchUserLogs(int monoId) async {
    final value = await get(apiTinygrailCharaUserLogs(monoId));
    if (value is! Map<String, dynamic>) {
      return (bids: const [], asks: const [], bidHistory: const [], askHistory: const [], sacrifices: 0, amount: 0);
    }
    List<TinygrailLog> parse(dynamic raw) => (raw is List)
        ? raw.map((e) => TinygrailLog.fromJson(e as Map<String, dynamic>)).toList()
        : const [];
    return (
      bids: parse(value['Bids']),
      asks: parse(value['Asks']),
      bidHistory: parse(value['BidHistory']),
      askHistory: parse(value['AskHistory']),
      sacrifices: (value['Sacrifices'] as num?)?.toInt() ?? 0,
      amount: (value['Amount'] as num?)?.toInt() ?? 0,
    );
  }

  /// 我的圣殿
  Future<List<TinygrailTemple>> fetchMyTemple(String hash) async {
    final value = await get(apiTinygrailUserTemple2(hash));
    if (value is! Map<String, dynamic>) return const [];
    final items = value['Items'] as List? ?? const [];
    return items.map((e) => TinygrailTemple.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 最近圣殿
  Future<List<TinygrailTemple>> fetchTempleLast({int page = 1, int limit = 24}) async {
    final value = await get(apiTinygrailTempleLast2(page, limit), auth: false);
    if (value is! Map<String, dynamic>) return const [];
    final items = value['Items'] as List? ?? const [];
    return items.map((e) => TinygrailTemple.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 角色圣殿
  Future<List<TinygrailTemple>> fetchCharaTemple(int monoId) async {
    final value = await get(apiTinygrailCharaTemple(monoId), auth: false);
    if (value is! List) return const [];
    return value.map((e) => TinygrailTemple.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 董事会
  Future<List<TinygrailUserBoard>> fetchUsers(int monoId) async {
    final value = await get(apiTinygrailUsers2(monoId), auth: false);
    if (value is! Map<String, dynamic>) return const [];
    final items = value['Items'] as List? ?? const [];
    return items.map((e) => TinygrailUserBoard.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// ICO 参与者
  Future<List<TinygrailInitial>> fetchInitial(int icoId, int page) async {
    final value = await get(apiTinygrailInitialUsers(icoId, page), auth: false);
    if (value is! Map<String, dynamic>) return const [];
    final items = value['Items'] as List? ?? const [];
    return items.map((e) => TinygrailInitial.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 富豪榜
  Future<List<TinygrailRich>> fetchRich(int page, int limit) async {
    final value = await get(apiTinygrailRichList(page, limit), auth: false);
    if (value is! List) return const [];
    return [
      for (var i = 0; i < value.length; i++)
        TinygrailRich.fromJson(value[i] as Map<String, dynamic>, rank: i + 1),
    ];
  }

  /// 圣星 (通天塔)
  Future<List<TinygrailChara>> fetchStar(int page, int limit) async {
    final value = await get(apiTinygrailBabel(page, limit), auth: false);
    if (value is! List) return const [];
    return value.map((e) => TinygrailChara.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 圣星记录
  Future<List<TinygrailStarLog>> fetchStarLogs(int page, int limit) async {
    final value = await get(apiTinygrailStarLogList(page, limit), auth: false);
    if (value is! Map<String, dynamic>) return const [];
    final items = value['Items'] as List? ?? const [];
    return items.map((e) => TinygrailStarLog.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 英灵殿 / 幻想乡
  Future<List<TinygrailChara>> fetchValhalla({int page = 1, int limit = 400}) async {
    final value = await get(apiTinygrailValhalla(page, limit), auth: false);
    if (value is! Map<String, dynamic>) return const [];
    final items = value['Items'] as List? ?? const [];
    return items.map((e) => TinygrailChara.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TinygrailChara>> fetchFantasy({int page = 1, int limit = 100}) async {
    final value = await get(apiTinygrailFantasy(page, limit), auth: false);
    if (value is! Map<String, dynamic>) return const [];
    final items = value['Items'] as List? ?? const [];
    return items.map((e) => TinygrailChara.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 精炼排行
  Future<List<TinygrailRefine>> fetchRefineRank({int page = 1, int limit = 100}) async {
    final value = await get(apiTinygrailRefineRank(page, limit), auth: false);
    if (value is! Map<String, dynamic>) return const [];
    final items = value['Items'] as List? ?? const [];
    return items.map((e) => TinygrailRefine.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 每周萌王
  Future<List<TinygrailTopWeek>> fetchTopWeek() async {
    final value = await get(apiTinygrailTopWeek(), auth: false);
    if (value is! List) return const [];
    return [
      for (var i = 0; i < value.length; i++)
        TinygrailTopWeek.fromJson(value[i] as Map<String, dynamic>, rank: i + 1),
    ];
  }

  /// 每周萌王历史
  Future<List<TinygrailTopWeek>> fetchTopWeekHistory(int prev) async {
    final value = await get(apiTinygrailTopWeekHistory(prev), auth: false);
    if (value is! Map<String, dynamic>) return const [];
    final items = value['Items'] as List? ?? const [];
    return [
      for (var i = 0; i < items.length; i++)
        TinygrailTopWeek.fromJson(items[i] as Map<String, dynamic>, rank: i + 1),
    ];
  }

  /// 我的道具
  Future<List<TinygrailItems>> fetchItems() async {
    final value = await get(apiTinygrailMyItems());
    if (value is! Map<String, dynamic>) return const [];
    final items = value['Items'] as List? ?? const [];
    return items.map((e) => TinygrailItems.fromJson(e as Map<String, dynamic>)).toList();
  }

  // -------------------- 交易动作 --------------------

  /// 买入
  Future<bool> doBid(int monoId, int price, int amount) async {
    await post(apiTinygrailBid(monoId, price, amount));
    return true;
  }

  /// 卖出
  Future<bool> doAsk(int monoId, int price, int amount) async {
    await post(apiTinygrailAsk(monoId, price, amount));
    return true;
  }

  /// 取消买单
  Future<bool> doCancelBid(int id) async {
    await post(apiTinygrailCancelBid(id));
    return true;
  }

  /// 取消卖单
  Future<bool> doCancelAsk(int id) async {
    await post(apiTinygrailCancelAsk(id));
    return true;
  }

  /// 参与 ICO
  Future<bool> doJoin(int icoId, int amount) async {
    await post(apiTinygrailJoin2(icoId, amount));
    return true;
  }

  /// 资产重组 (献祭)
  Future<bool> doSacrifice(int monoId, int amount, bool isSale) async {
    await post(apiTinygrailSacrifice(monoId, amount, isSale));
    return true;
  }

  /// 拍卖
  Future<bool> doAuction(int monoId, int price, int amount) async {
    await post(apiTinygrailAuctionBid2(monoId, price, amount));
    return true;
  }

  /// 取消拍卖
  Future<bool> doAuctionCancel(int id) async {
    await post(apiTinygrailAuctionCancel(id));
    return true;
  }

  /// 灌注星之力
  Future<bool> doStarForces(int monoId, int amount) async {
    await post(apiTinygrailCharaStar2(monoId, amount));
    return true;
  }

  /// 启动 ICO
  Future<bool> doInit(int monoId) async {
    await post(apiTinygrailInit2(monoId));
    return true;
  }

  /// 使用道具
  Future<bool> doMagic(int monoId, String type, int toMonoId, int amount, bool isTemple) async {
    await post(apiTinygrailMagic(monoId, type, toMonoId, amount, isTemple));
    return true;
  }

  /// 刮刮乐
  Future<dynamic> doScratch() async {
    return post(apiTinygrailScratch());
  }

  /// 今日刮刮乐次数
  Future<int> doDailyCount() async {
    try {
      final value = await get(apiTinygrailDailyCount());
      return (value as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 登出
  Future<void> doLogout() async {
    try {
      await post(apiTinygrailLogout());
    } catch (_) {}
  }
}

/// tinygrail API 错误
class TinygrailException implements Exception {
  final String message;
  const TinygrailException(this.message);

  @override
  String toString() => message;
}

/// tinygrail cookie (SharedPreferences 持久化)
final tinygrailCookieProvider = NotifierProvider<TinygrailCookie, String>(TinygrailCookie.new);

class TinygrailCookie extends Notifier<String> {
  static const _key = 'tinygrail_cookie';

  @override
  String build() {
    _restore();
    return '';
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key) ?? '';
  }

  Future<void> set(String cookie) async {
    state = cookie;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, cookie);
  }

  Future<void> clear() async {
    state = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// tinygrail API 实例
final tinygrailApiProvider = Provider<TinygrailApi>((ref) {
  final api = TinygrailApi(ref.watch(tinygrailCookieProvider));
  api.token = ref.watch(authTokenProvider);
  ref.listen(tinygrailCookieProvider, (_, next) => api.setCookie(next));
  return api;
});

/// 当前登录用户 (hash + 资产); 未绑定返回 null
final tinygrailUserProvider = FutureProvider<TinygrailUser?>((ref) async {
  final api = ref.watch(tinygrailApiProvider);
  final hash = await api.fetchHash();
  if (hash.isEmpty) return null;
  try {
    final user = await api.fetchAssets(hash);
    return user.hash.isEmpty ? TinygrailUser(hash: hash) : user;
  } catch (_) {
    return TinygrailUser(hash: hash);
  }
});

/// 金额格式化: 分 -> ¥x.xx (>=1万 -> x.xx万, >=1亿 -> x.xx亿)
String tgMoney(num fen) {
  final v = fen.toDouble() / 100;
  if (v.abs() >= 100000000) return '${(v / 100000000).toStringAsFixed(2)}亿';
  if (v.abs() >= 10000) return '${(v / 10000).toStringAsFixed(2)}万';
  return v == v.roundToDouble() ? '¥${v.toStringAsFixed(0)}' : '¥${v.toStringAsFixed(2)}';
}

/// 数字缩略 (分, 不显示货币符号)
String tgAmount(num fen) {
  final v = fen.toDouble();
  if (v.abs() >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}亿';
  if (v.abs() >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
  return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
}

/// 价格显示: 分 -> 两位小数
String tgPrice(num fen) => (fen / 100).toStringAsFixed(2);

/// 涨跌幅显示
String tgFluctuation(num fluctuation) {
  if (fluctuation == 0) return '-%';
  final f = fluctuation > 0 ? '+${fluctuation.toStringAsFixed(2)}%' : '${fluctuation.toStringAsFixed(2)}%';
  return f;
}
