import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/user.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

/// 认证状态
class AuthState {
  final String token;
  final User? user;
  final bool loading;

  const AuthState({this.token = '', this.user, this.loading = false});

  bool get isLoggedIn => token.isNotEmpty && user != null;

  AuthState copyWith({String? token, User? user, bool? loading}) => AuthState(
        token: token ?? this.token,
        user: user ?? this.user,
        loading: loading ?? this.loading,
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
      refreshUser();
    }
  }

  /// 用 OAuth code 换取 token
  Future<bool> loginWithCode(String code) async {
    state = state.copyWith(loading: true);
    try {
      final data = await ref.read(apiClientProvider).post(
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
      state = state.copyWith(user: user);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUserKey, jsonEncode({
            'id': user.id,
            'url': user.url,
            'username': user.username,
            'nickname': user.nickname,
            'avatar': {'large': user.avatar.large, 'medium': user.avatar.medium, 'small': user.avatar.small},
            'sign': user.sign,
            'user_group': user.userGroup,
          }));
    } catch (_) {
      // 网络失败静默, 保留旧用户信息
    }
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
