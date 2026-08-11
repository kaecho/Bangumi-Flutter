import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/api/api_endpoints.dart';
import 'tinygrail_api.dart';
import 'tinygrail_screen.dart';

/// 小圣杯授权登录页
///
/// 流程 (与原项目一致):
/// 1. WebView 打开 bgm.tv OAuth 授权页 (client_id 为小圣杯 App)
/// 2. 用户在 bgm.tv 上登录并授权, 跳转到 tinygrail 回调
/// 3. tinygrail 服务端下发会话 cookie, 拦截回调后从 WebView 提取 cookie 并持久化
class TinygrailLoginScreen extends ConsumerStatefulWidget {
  const TinygrailLoginScreen({super.key});

  @override
  ConsumerState<TinygrailLoginScreen> createState() => _TinygrailLoginScreenState();
}

class _TinygrailLoginScreenState extends ConsumerState<TinygrailLoginScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;
  bool _handled = false;

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
            // tinygrail 回调: 服务端已下发 cookie, 提取并完成授权
            if (url.startsWith(kTinygrailOauthRedirect) && !_handled) {
              _handled = true;
              await _finishLogin();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(kTinygrailOauthAuthorize()));
  }

  Future<void> _finishLogin() async {
    try {
      // 等待 tinygrail 服务端 Set-Cookie 落地
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      final cookies = await WebViewCookieManager().getCookies(domain: Uri.parse(kTinygrailHost));
      if (cookies.isEmpty) {
        if (mounted) setState(() => _error = '授权失败, 未获取到会话, 请重试');
        _handled = false;
        return;
      }
      final cookie = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      await ref.read(tinygrailCookieProvider.notifier).set(cookie);
      ref.invalidate(tinygrailUserProvider);
      ref.invalidate(tinygrailStateProvider);
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = '授权失败: $e');
      _handled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('小圣杯授权')),
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
                      setState(() {
                        _error = null;
                        _handled = false;
                      });
                      _controller.loadRequest(Uri.parse(kTinygrailOauthAuthorize()));
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
