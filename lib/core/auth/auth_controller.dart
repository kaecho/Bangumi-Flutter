import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/user.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import 'site_cookies.dart';

/// 认证状态
class AuthState {
  final String token;
  final User? user;
  final bool loading;
  final bool outdate;

  const AuthState({
    this.token = '',
    this.user,
    this.loading = false,
    this.outdate = false,
  });

  bool get isLoggedIn => token.isNotEmpty && user != null;

  AuthState copyWith({
    String? token,
    User? user,
    bool? loading,
    bool? outdate,
  }) => AuthState(
    token: token ?? this.token,
    user: user ?? this.user,
    loading: loading ?? this.loading,
    outdate: outdate ?? this.outdate,
  );
}

/// 认证控制器: token 持久化 + 用户信息
class AuthController extends Notifier<AuthState> {
  static const _kTokenKey = 'auth_access_token';
  static const _kUserKey = 'auth_user';

  @override
  AuthState build() {
    _restore();
    return const AuthState();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kTokenKey) ?? '';
    final userRaw = prefs.getString(_kUserKey);
    User? user;
    if (userRaw != null) {
      try {
        user = User.fromJson(jsonDecode(userRaw) as Map<String, dynamic>);
      } catch (_) {}
    }
    state = AuthState(token: token, user: user);
    if (token.isNotEmpty) {
      unawaited(refreshUser());
    }
  }

  /// 用 OAuth code 换取 token
  Future<bool> loginWithCode(String code) async {
    state = state.copyWith(loading: true);
    try {
      final data = await ref
          .read(apiClientProvider)
          .post(
            kApiAccessToken,
            data: {
              'grant_type': 'authorization_code',
              'client_id': kAppId,
              'client_secret': kAppSecret,
              'code': code,
              'redirect_uri': kOauthRedirect,
            },
            host: kHost,
          );
      final token = (data as Map<String, dynamic>)['access_token'] as String?;
      if (token == null || token.isEmpty) return false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokenKey, token);
      state = state.copyWith(token: token, loading: false);
      await refreshUser();
      return true;
    } catch (_) {
      state = state.copyWith(loading: false);
      return false;
    }
  }

  /// 刷新当前用户信息
  Future<void> refreshUser() async {
    if (state.token.isEmpty) return;
    try {
      final data = await ref.read(apiClientProvider).get(apiV0Me());
      final user = User.fromJson(data as Map<String, dynamic>);
      state = state.copyWith(user: user, outdate: false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kUserKey,
        jsonEncode({
          'id': user.id,
          'url': user.url,
          'username': user.username,
          'nickname': user.nickname,
          'avatar': {
            'large': user.avatar.large,
            'medium': user.avatar.medium,
            'small': user.avatar.small,
          },
          'sign': user.sign,
          'user_group': user.userGroup,
        }),
      );
    } catch (_) {
      // 网络失败静默, 保留旧用户信息
    }
  }

  /// 授权过期 (原项目 userStore.outdate)
  void markOutdate() {
    if (!state.outdate) state = state.copyWith(outdate: true);
  }

  /// 直接使用 access token 登录 (原项目 login/token 页)
  /// 校验失败时回滚旧 token
  Future<bool> loginWithToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return false;
    final old = state.token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, trimmed);
    state = state.copyWith(token: trimmed);
    final before = state.user;
    await refreshUser();
    if (state.user == null) {
      // 校验失败: 恢复旧 token (原项目逻辑)
      if (old.isEmpty) {
        await prefs.remove(_kTokenKey);
        state = const AuthState();
      } else {
        await prefs.setString(_kTokenKey, old);
        state = AuthState(token: old, user: before);
      }
      return false;
    }
    return true;
  }

  /// 退出登录
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUserKey);
    state = const AuthState();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// 当前 access token (供 ApiClient 使用)
final authTokenProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider).token.isEmpty
      ? null
      : ref.watch(authControllerProvider).token;
});

/// 当前用户
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authControllerProvider).user;
});

/// 是否已登录
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).isLoggedIn;
});

/// 授权是否过期 (原项目 userStore.outdate)
final authOutdateProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).outdate;
});

/// 能否以登录态操作: OAuth 登录 或 站点 Cookie 登录 任一
/// 站点 Cookie 可支持: 短信/电波提醒/点赞/时间线/回复 等站点认证功能
final canActAsLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(isLoggedInProvider) ||
      ref.watch(siteCookiesProvider).hasCookies;
});
