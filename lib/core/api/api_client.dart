import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'api_endpoints.dart';

/// 全局 HTTP 客户端
///
/// - 主域名 api.bgmapi.com, 失败自动降级到 api.bgm.tv (与原项目一致)
/// - 自动附带 Authorization Bearer token (已登录时)
/// - 请求超时 15s
class ApiClient {
  ApiClient({this._tokenProvider}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: kApiHost,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 15),
        headers: {'User-Agent': 'Bangumi/Flutter (https://github.com/kaecho/Bangumi-Flutter)'},
      ),
    );
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _tokenProvider?.call();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  late final Dio _dio;
  final String? Function()? _tokenProvider;

  /// 发起 GET 请求; [host] 覆盖 baseUrl (小圣杯等第三方域)
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    String? host,
    bool auth = false,
  }) async {
    final uri = Uri.parse('${host ?? kApiHost}$path').replace(queryParameters: query);
    try {
      final resp = await _dio.getUri<dynamic>(uri);
      return resp.data;
    } on DioException catch (e) {
      // 主域名失败时降级到备用域名 (仅 bgm 官方 API)
      if (host == null && e.response?.statusCode != null && e.response!.statusCode! >= 500) {
        final backup = uri.replace(scheme: 'https', host: Uri.parse(kApiHostBackup).host);
        final resp = await _dio.getUri<dynamic>(backup);
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
  }) async {
    final uri = Uri.parse('${host ?? kApiHost}$path').replace(queryParameters: query);
    final resp = await _dio.postUri<dynamic>(uri, data: data);
    return resp.data;
  }

  /// 发起 PUT 请求
  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    String? host,
  }) async {
    final uri = Uri.parse('${host ?? kApiHost}$path').replace(queryParameters: query);
    final resp = await _dio.putUri<dynamic>(uri, data: data);
    return resp.data;
  }

  /// 发起 DELETE 请求
  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    String? host,
  }) async {
    final uri = Uri.parse('${host ?? kApiHost}$path').replace(queryParameters: query);
    final resp = await _dio.deleteUri<dynamic>(uri, data: data);
    return resp.data;
  }

  /// 抓取原始 HTML (bgm.tv 页面, 浏览器 UA)
  /// 供超展开等页面解析使用 (原项目 fetchHTML 等价)
  Future<String> fetchHtml(String url) async {
    final resp = await _dio.getUri<String>(
      Uri.parse(url),
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Mobile Safari/537.36',
          'Referer': kHost,
          'Accept-Language': 'zh-CN,zh;q=0.9',
        },
      ),
    );
    return resp.data ?? '';
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokenProvider: () => ref.read(authTokenProvider));
});

/// 统一错误文案
String apiErrorMessage(Object error) {
  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        '网络超时, 请稍后重试',
      DioExceptionType.connectionError => '网络连接失败, 请检查网络',
      DioExceptionType.badResponse => '请求失败 (${error.response?.statusCode})',
      _ => '网络错误, 请稍后重试',
    };
  }
  return error.toString();
}
