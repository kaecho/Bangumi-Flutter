import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/site_cookies.dart';
import '../debug/debug_log.dart';
import '../storage/settings_store.dart';
import 'api_endpoints.dart';

/// 主站通信错误 (原项目 userStore.websiteError)
final websiteErrorProvider = StateProvider<bool>((ref) => false);

/// 全局 HTTP 客户端
///
/// - 主域名 api.bgmapi.com, 失败自动降级到 api.bgm.tv (与原项目一致)
/// - 自动附带 Authorization Bearer token (已登录时)
/// - 自动附带 bgm.tv 站点 Cookie (与原项目一致: 所有请求都带 chii_auth 等,
///   供 PM/电波提醒/点赞/formhash 等站点认证功能使用)
/// - 请求超时 15s
class ApiClient {
  ApiClient({
    this._tokenProvider,
    this._cookieProvider,
    this.onLog,
    this.onAuthExpired,
    this.onWebsiteError,
  });

  late final Dio _dio =
      Dio(
          BaseOptions(
            baseUrl: kApiHost,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 15),
            headers: {'User-Agent': kApiUserAgent},
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final token = _tokenProvider?.call();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              final skipCookies = options.extra['skipCookies'] == true;
              if (!skipCookies) {
                final cookie = _cookieProvider?.call();
                if (cookie != null && cookie.isNotEmpty) {
                  options.headers['Cookie'] = cookie;
                }
              }
              // 主站会按 UA 验 Cookie; API 域名保持应用标识
              final host = options.uri.host;
              if (host == 'bgm.tv' || host.endsWith('.bgm.tv')) {
                options.headers['User-Agent'] = kSiteUserAgent;
              }
              handler.next(options);
            },

            onError: (error, handler) {
              if (isWebsiteError(
                error.requestOptions.uri.host,
                error.response?.statusCode,
              )) {
                onWebsiteError?.call();
              }
              if (isAuthExpiredStatus(error.response?.statusCode)) {
                onAuthExpired?.call();
              }
              handler.next(error);
            },
          ),
        );

  final String? Function()? _tokenProvider;

  /// 站点 Cookie header (chii_auth 等), 附加到所有请求
  final String? Function()? _cookieProvider;

  /// 调试日志回调 (由调用方决定是否落盘; 不记录 Authorization/Cookie 等敏感信息)
  final void Function(String line)? onLog;

  /// 授权过期 (原项目 userStore.outdate)
  final void Function()? onAuthExpired;

  /// 主站 502 (原项目 userStore.websiteError)
  final void Function()? onWebsiteError;

  void _log(String line) => onLog?.call(line);

  /// 执行请求并记录日志: 方法 + URL + 状态码/错误 + 耗时
  Future<Response<T>> _track<T>(
    String method,
    Uri uri,
    Future<Response<T>> Function() run,
  ) async {
    final sw = Stopwatch()..start();
    try {
      final resp = await run();
      _log('$method $uri → ${resp.statusCode} (${sw.elapsedMilliseconds}ms)');
      return resp;
    } on DioException catch (e) {
      _log('$method $uri → ${_describeError(e)} (${sw.elapsedMilliseconds}ms)');
      rethrow;
    }
  }

  static String _describeError(DioException e) {
    final status = e.response?.statusCode;
    if (status != null) {
      final data = e.response?.data;
      if (data is String && data.trim().isNotEmpty) {
        final s = data.trim();
        return 'HTTP $status: ${s.length > 200 ? s.substring(0, 200) : s}';
      }
      if (data is Map) {
        final desc = data['description'] ?? data['error'];
        if (desc is String && desc.isNotEmpty) return 'HTTP $status: $desc';
      }
      return 'HTTP $status';
    }
    final msg = e.message;
    return '${e.type.name}${msg != null && msg.isNotEmpty ? ': $msg' : ''}';
  }

  /// 发起 GET 请求; [host] 覆盖 baseUrl (小圣杯等第三方域)
  ///
  /// [skipCookies] 对齐原版 `!` URL: 全站时间线等不带站点 Cookie。
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    String? host,
    bool auth = false,
    bool skipCookies = false,
  }) async {
    final uri = buildApiUri(path, host: host, query: query);
    Options? options;
    if (skipCookies) {
      options = Options(extra: const {'skipCookies': true});
    }
    try {
      final resp = await _track(
        'GET',
        uri,
        () => _dio.getUri<dynamic>(uri, options: options),
      );

      return resp.data;
    } on DioException catch (e) {
      // 主域名失败时降级到备用域名 (仅 bgm 官方 API)
      if (host == null &&
          e.response?.statusCode != null &&
          e.response!.statusCode! >= 500) {
        final backup = uri.replace(
          scheme: 'https',
          host: Uri.parse(kApiHostBackup).host,
        );
        final resp = await _track(
          'GET',
          backup,
          () => _dio.getUri<dynamic>(backup),
        );
        return resp.data;
      }
      rethrow;
    }
  }

  /// 发起 POST 请求
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    String? host,
    bool auth = false,
    bool form = false,
  }) async {
    final uri = buildApiUri(path, host: host, query: query);
    Object? body = data;
    Options? options;
    if (form && data is Map) {
      body = FormData.fromMap(Map<String, dynamic>.from(data));
    }
    final resp = await _track(
      'POST',
      uri,
      () => _dio.postUri<dynamic>(uri, data: body, options: options),
    );
    return resp.data;
  }

  /// 站点表单 POST (urlencoded), 跟随重定向, 返回 HTML + Set-Cookie
  Future<({String body, List<String> setCookies})> postSiteForm(
    String url,
    Map<String, String> fields, {
    String? cookie,
  }) async {
    final uri = Uri.parse(url);
    final resp = await _track(
      'POST',
      uri,
      () => _dio.postUri<String>(
        uri,
        data: fields,
        options: Options(
          responseType: ResponseType.plain,
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: true,
          extra: const {'skipCookies': true},
          validateStatus: (s) => s != null && s < 400,
          headers: {
            'User-Agent': kSiteUserAgent,
            'Referer': htmlLogin(),
            'Accept-Language': 'zh-CN,zh;q=0.9',
            if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
          },
        ),
      ),
    );
    return (body: resp.data ?? '', setCookies: cookieValues(resp.headers));
  }

  /// 已登录站点表单 POST (urlencoded, 带 Cookie, 对齐 xhr HTML_USER_SETTING)
  Future<String> postSiteFields(String url, Map<String, String> fields) async {
    final uri = Uri.parse(url);
    final resp = await _track(
      'POST',
      uri,
      () => _dio.postUri<String>(
        uri,
        data: fields,
        options: Options(
          responseType: ResponseType.plain,
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: true,
          validateStatus: (s) => s != null && s < 400,
          headers: {
            'User-Agent': kSiteUserAgent,
            'Referer': url,
            'Accept-Language': 'zh-CN,zh;q=0.9',
          },
        ),
      ),
    );
    return resp.data ?? '';
  }

  /// 站点 GET, 不跟重定向 (OAuth authorize 抽 code)
  Future<({String body, String? location, List<String> setCookies})> getSiteRaw(
    String url, {
    String? cookie,
    bool followRedirects = true,
  }) async {
    final uri = Uri.parse(url);
    final resp = await _track(
      'GET',
      uri,
      () => _dio.getUri<String>(
        uri,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: followRedirects,
          validateStatus: (s) => s != null && s < 400 || s == 302 || s == 301,
          extra: const {'skipCookies': true},
          headers: {
            'User-Agent': kSiteUserAgent,
            'Referer': kHost,
            'Accept-Language': 'zh-CN,zh;q=0.9',
            if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
          },
        ),
      ),
    );
    return (
      body: resp.data ?? '',
      location: resp.headers.value('location'),
      setCookies: cookieValues(resp.headers),
    );
  }

  /// 站点 POST, 不跟重定向 (OAuth authorize)
  Future<({String body, String? location, List<String> setCookies})>
  postSiteRaw(String url, Map<String, String> fields, {String? cookie}) async {
    final uri = Uri.parse(url);
    final resp = await _track(
      'POST',
      uri,
      () => _dio.postUri<String>(
        uri,
        data: fields,
        options: Options(
          responseType: ResponseType.plain,
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          validateStatus: (s) => s != null && s < 400 || s == 302 || s == 301,
          extra: const {'skipCookies': true},
          headers: {
            'User-Agent': kSiteUserAgent,
            'Referer': kHost,
            'Accept-Language': 'zh-CN,zh;q=0.9',
            if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
          },
        ),
      ),
    );
    return (
      body: resp.data ?? '',
      location: resp.headers.value('location'),
      setCookies: cookieValues(resp.headers),
    );
  }

  /// 验证码 GIF 字节
  Future<({List<int> bytes, List<String> setCookies})> getBytes(
    String url, {
    String? cookie,
  }) async {
    final uri = Uri.parse(url);
    final resp = await _track(
      'GET',
      uri,
      () => _dio.getUri<List<int>>(
        uri,
        options: Options(
          responseType: ResponseType.bytes,
          extra: const {'skipCookies': true},
          headers: {
            'User-Agent': kSiteUserAgent,
            'Referer': htmlLogin(),
            if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
          },
        ),
      ),
    );
    return (
      bytes: resp.data ?? const <int>[],
      setCookies: cookieValues(resp.headers),
    );
  }

  /// 发起 PUT 请求
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    String? host,
  }) async {
    final uri = buildApiUri(path, host: host, query: query);
    final resp = await _track(
      'PUT',
      uri,
      () => _dio.putUri<dynamic>(uri, data: data),
    );
    return resp.data;
  }

  /// 发起 DELETE 请求
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    String? host,
  }) async {
    final uri = buildApiUri(path, host: host, query: query);
    final resp = await _track(
      'DELETE',
      uri,
      () => _dio.deleteUri<dynamic>(uri, data: data),
    );
    return resp.data;
  }

  /// 抓取原始 HTML (bgm.tv 页面, 浏览器 UA + 站点 Cookie)
  /// 供超展开等页面解析使用 (原项目 fetchHTML 等价)
  Future<String> fetchHtml(String url) async {
    final uri = Uri.parse(url);
    final resp = await _track(
      'GET',
      uri,
      () => _dio.getUri<String>(
        uri,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'User-Agent': kSiteUserAgent,

            'Referer': kHost,
            'Accept-Language': 'zh-CN,zh;q=0.9',
          },
        ),
      ),
    );
    return resp.data ?? '';
  }

  /// 抓取原始 HTML, 额外追加 cookie (如搜索所需的 chii_searchDateLine)
  /// 站点 cookie (拦截器已附) 与 [extraCookie] 用 '; ' 连接
  Future<String> fetchHtmlWithCookie(String url, String extraCookie) async {
    final uri = Uri.parse(url);
    final base = _cookieProvider?.call() ?? '';
    final cookie = base.isEmpty ? extraCookie : '$base; $extraCookie';
    final resp = await _track(
      'GET',
      uri,
      () => _dio.getUri<String>(
        uri,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'User-Agent': kSiteUserAgent,

            'Referer': kHost,
            'Accept-Language': 'zh-CN,zh;q=0.9',
            'Cookie': cookie,
          },
        ),
      ),
    );
    return resp.data ?? '';
  }
}

/// 构建 API 请求 URI:
/// - [path] 为绝对 URL (https://…) 时直接使用 (不再拼接 base, 否则 host 会重复)
/// - 相对路径拼接 [host] ?? [kApiHost]
/// - [query] 合并进最终 URL
Uri buildApiUri(String path, {String? host, Map<String, dynamic>? query}) {
  final base = host ?? kApiHost;
  final uri = path.startsWith('http')
      ? Uri.parse(path)
      : Uri.parse('$base$path');
  if (query == null || query.isEmpty) return uri;
  return uri.replace(queryParameters: query);
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenProvider: () => ref.read(authTokenProvider),
    cookieProvider: () => ref.read(siteCookiesProvider).cookieHeader,
    onAuthExpired: () =>
        ref.read(authControllerProvider.notifier).markOutdate(),
    onWebsiteError: () => ref.read(websiteErrorProvider.notifier).state = true,
    onLog: (line) {
      if (SettingsStore.instance.debugLog) {
        unawaited(DebugLog.instance.write(line));
        debugPrint(line);
      }
    },
  );
});

/// 统一错误文案
String apiErrorMessage(Object error) {
  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => '网络超时, 请稍后重试',
      DioExceptionType.connectionError => '网络连接失败, 请检查网络',
      DioExceptionType.badResponse => '请求失败 (${error.response?.statusCode})',
      _ => '网络错误, 请稍后重试',
    };
  }
  return error.toString();
}

/// 从 JSON cookie 数组构造 Cookie header (浏览器导出格式)
String buildCookieHeaderFromJson(List<dynamic> cookies) {
  final parts = <String>[];
  for (final c in cookies) {
    if (c is! Map) continue;
    final name = c['name']?.toString() ?? '';
    final value = c['value']?.toString() ?? '';
    if (name.isEmpty) continue;
    parts.add('$name=$value');
  }
  return normalizeCookieTime(parts.join('; '));
}

/// 处理 cookie 中的 chii_cookietime (等价原项目 normalizeCookieTime)
/// 站点以 chii_cookietime=2592000 表示记住登录, 否则会话关闭后失效
String normalizeCookieTime(String cookie) {
  if (cookie.isEmpty) return '';
  if (cookie.contains('chii_cookietime=0')) {
    return cookie.replaceFirst('chii_cookietime=0', 'chii_cookietime=2592000');
  }
  if (!cookie.contains('chii_cookietime=2592000')) {
    return '$cookie; chii_cookietime=2592000';
  }
  return cookie;
}

/// 检查 HTML 是否要求登录 (含 "需要您 登录")
///
/// 游客首页也有 `/login` 链接, 不能单看这个字符串。优先认
/// `CHOBITS_UID = 0` (站点脚本全局), 再认 "需要您 … /login"。
bool htmlRequiresLogin(String html) {
  final uid = RegExp(r'CHOBITS_UID = (\d+)').firstMatch(html);

  if (uid != null) return uid.group(1) == '0';
  return html.contains('需要您') && html.contains('/login');
}

/// 从主站 HTML 抽出已登录用户名 (CHOBITS_USERNAME)
String parseLoggedInUsername(String html) {
  final m = RegExp(r"CHOBITS_USERNAME = '([^']*)'").firstMatch(html);
  return m?.group(1) ?? '';
}

/// 原项目 userStore.websiteError: 主站 502
bool isWebsiteError(String host, int? status) =>
    host.contains('bgm.tv') && status == 502;

/// 原项目 userStore.outdate: 授权 401
bool isAuthExpiredStatus(int? status) => status == 401;

/// 抽出响应 Set-Cookie
List<String> cookieValues(Headers headers) {
  final raw = headers.map['set-cookie'] ?? headers.map['Set-Cookie'];
  if (raw == null) return const [];
  return [
    for (final v in raw)
      if (v.isNotEmpty) v,
  ];
}

/// 合并 Set-Cookie 到现有 header, 只保留原版关心的 chii_* 键
String mergeSiteCookies(String current, Iterable<String> setCookies) {
  const keep = {
    'chii_auth',
    'chii_cookietime',
    'chii_sec',
    'chii_sec_id',
    'chii_sid',
    'chii_theme',
    'chii_sid_raw',
  };
  final map = <String, String>{};
  for (final part in current.split(';')) {
    final kv = part.trim();
    final i = kv.indexOf('=');
    if (i <= 0) continue;
    final key = kv.substring(0, i);
    if (!keep.contains(key) && !key.startsWith('chii_')) continue;
    map[key] = kv.substring(i + 1);
  }

  for (final raw in setCookies) {
    final first = raw.split(';').first.trim();
    final i = first.indexOf('=');
    if (i <= 0) continue;
    final key = first.substring(0, i);
    final value = first.substring(i + 1);
    if (!keep.contains(key) && !key.startsWith('chii_')) continue;
    if (value == 'delete') {
      map.remove(key);
    } else {
      map[key] = value;
    }
  }
  return map.entries.map((e) => '${e.key}=${e.value}').join('; ');
}

/// 从 Location / URL 抽 OAuth code
String? oauthCodeFromUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  return Uri.tryParse(url)?.queryParameters['code'];
}

/// 登录失败文案
String? loginFailMessage(String html) {
  if (html.contains('分钟内您将不能登录本站')) {
    return '累计 5 次错误尝试, 15 分钟内您将不能登录本站';
  }
  if (html.contains('验证码') && html.contains('错误')) {
    return '验证码错误';
  }
  return null;
}

bool htmlHasLogout(String html) => html.contains('class="logout"');

String? logoutHref(String html) {
  final m = RegExp(r'href="([^"]*/logout/[^"]*)"').firstMatch(html);
  return m?.group(1);
}
