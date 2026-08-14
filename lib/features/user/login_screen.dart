import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/site_cookies.dart';
import '../../core/utils/display.dart';

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
                final ok = await ref
                    .read(authControllerProvider.notifier)
                    .loginWithCode(code);
                // 登录成功后捕获 bgm.tv 站点 cookie (PM/电波提醒等需要)
                try {
                  final cookies = await WebViewCookieManager().getCookies(
                    domain: Uri.parse('https://bgm.tv'),
                  );
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
        actions: [
          TextButton(
            onPressed: () => openExternalUrl(htmlSignup()),
            child: const Text('注册'),
          ),
          TextButton(
            onPressed: () => openExternalUrl(htmlPrivacy()),
            child: const Text('隐私'),
          ),
          IconButton(
            icon: const Icon(Icons.key_outlined),
            tooltip: 'Token 登录',
            onPressed: () => showTokenLoginDialog(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
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

/// Token 登录对话框 (移植自原项目 login/token 页):
/// 粘贴 access_token → 保存并校验用户信息, 失败自动回滚
Future<void> showTokenLoginDialog(BuildContext context) {
  final controller = TextEditingController();
  var busy = false;
  return showDialog<void>(
    context: context,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) => AlertDialog(
        title: const Text('Token 登录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '粘贴 bgm.tv 的 access_token (OAuth2), 可在 bgm.tv 设置页获取。',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'access_token',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    busy = true;
                    final ok = await ref
                        .read(authControllerProvider.notifier)
                        .loginWithToken(controller.text);
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? '登录成功' : '更新失败, 请确保用户令牌可用')),
                    );
                  },
            child: const Text('登录'),
          ),
        ],
      ),
    ),
  );
}
