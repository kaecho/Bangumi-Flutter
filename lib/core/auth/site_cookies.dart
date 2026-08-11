import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../html/bgm_html_parser.dart';

/// bgm.tv 站点 Cookie 存储
///
/// 站点登录态 (chii_auth / chii_sid 等) 用于:
/// - PM 短信、电波提醒、时间线 ajax、点赞、好友申请 等站点认证功能
/// - 与原项目一致: 所有请求自动附带 (见 ApiClient)
///
/// 来源: ① OAuth 登录后从 WebView 自动捕获; ② 设置页手动粘贴
class SiteCookiesStore {
  SiteCookiesStore._();

  static final SiteCookiesStore instance = SiteCookiesStore._();

  static const _kCookieHeader = 'site_cookie_header';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 当前 Cookie header (原始值, 如 "chii_sid=xxx; chii_auth=yyy")
  String? get cookieHeader {
    final v = _prefs.getString(_kCookieHeader);
    if (v == null || v.isEmpty) return null;
    return v;
  }

  bool get hasCookies => cookieHeader != null && cookieHeader!.isNotEmpty;

  Future<void> setCookieHeader(String? header) async {
    final v = header?.trim() ?? '';
    if (v.isEmpty) {
      await _prefs.remove(_kCookieHeader);
    } else {
      await _prefs.setString(_kCookieHeader, v);
    }
  }

  /// 从浏览器导出的 JSON cookie 数组写入
  Future<void> setFromJson(List<dynamic> cookies) async {
    await setCookieHeader(buildCookieHeaderFromJson(cookies));
  }

  Future<void> clear() async {
    await _prefs.remove(_kCookieHeader);
  }
}

final siteCookiesProvider = Provider<SiteCookiesStore>((ref) {
  return SiteCookiesStore.instance;
});

/// formhash (站点操作令牌, 来自登录页 /settings/privacy)
/// 点赞/加好友等站点操作需要; 依赖站点 Cookie
final formhashProvider = FutureProvider<String>((ref) async {
  final client = ref.read(apiClientProvider);
  final html = await client.fetchHtml('$kHost/settings/privacy');
  if (htmlRequiresLogin(html)) return '';
  return parseFormhash(html);
});
