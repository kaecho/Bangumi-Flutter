import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/site_cookies.dart';

/// 登录页: OAuth2 网页授权流程
/// 1. WebView 打开 https://bgm.tv/oauth/authorize?client_id=...&redirect_uri=https://bgm.tv/dev/app
/// 2. 用户登录并授权, 跳转 redirect_uri?code=xxx
/// 3. 拦截回调 URL, 提取 code, 换取 access_token
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _loading = true;
            _error = null;
          }),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) async {
            final url = request.url;
            // 拦截授权回调
            if (url.startsWith(kOauthRedirect)) {
              final uri = Uri.parse(url);
              final code = uri.queryParameters['code'];
              if (code != null && code.isNotEmpty) {
                final ok = await ref.read(authControllerProvider.notifier).loginWithCode(code);
                // 登录成功后捕获 bgm.tv 站点 cookie (PM/电波提醒等需要)
                try {
                  final cookies = await WebViewCookieManager()
                      .getCookies(domain: Uri.parse('https://bgm.tv'));
                  if (cookies.isNotEmpty) {
                    final header = cookies
                        .map((c) => '${c.name}=${c.value}')
                        .join('; ');
                    await SiteCookiesStore.instance.setCookieHeader(header);
                  }
                } catch (_) {
                  // cookie 捕获失败不影响 OAuth 登录
                }
                if (mounted) {
                  if (ok) {
                    context.go('/progress');
                  } else {
                    setState(() => _error = '登录失败, 请重试');
                    _loading = false;
                  }
                }
                return NavigationDecision.prevent;
              }
            }
            // 已登录时自动跳转 (bgm.tv 首页会带上已登录状态)
            if (url.contains('/dev/app') || url.contains('/oauth/')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(kOauthAuthorize));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录 Bangumi'),
        leading: BackButton(onPressed: () => context.go('/progress')),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() => _error = null);
                      _controller.loadRequest(Uri.parse(kOauthAuthorize));
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
