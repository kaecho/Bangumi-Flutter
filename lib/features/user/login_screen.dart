import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/captcha_ocr.dart';
import '../../core/auth/site_cookies.dart';
import '../../core/html/bgm_html_parser.dart';
import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/mesume.dart';
import '../../shared/widgets/tab_title.dart';

/// 登录页: 原版 login/v2 看板娘预览 + 账号密码验证码; OAuth / Token 为次入口
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _captcha = TextEditingController();
  String _formhash = '';
  String _cookie = '';
  Uint8List? _captchaBytes;
  String? _info;
  bool _loading = false;
  bool _captchaBusy = true;
  bool _clicked = false;
  bool _ocrBusy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _captcha.dispose();
    super.dispose();
  }

  Future<void> _absorb(Iterable<String> set) async {
    _cookie = mergeSiteCookies(_cookie, set);
  }

  Future<void> _resetSession() async {
    setState(() {
      _captchaBusy = true;
      _captchaBytes = null;
      _captcha.clear();
    });
    try {
      final client = ref.read(apiClientProvider);
      final page = await client.getSiteRaw(htmlLogin(), cookie: _cookie);
      await _absorb(page.setCookies);
      _formhash = parseFormhash(page.body);
      final cap = await client.getBytes(htmlSignupCaptcha(), cookie: _cookie);
      await _absorb(cap.setCookies);
      if (!mounted) return;
      setState(() {
        _captchaBytes = Uint8List.fromList(cap.bytes);
        _captchaBusy = false;
        if (_formhash.isEmpty) {
          _info = '连接主站失败, 获取验证码失败';
        }
      });
      unawaited(_fillCaptcha(cap.bytes));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _captchaBusy = false;
        _info = '连接主站失败, 获取验证码失败';
      });
    }
  }

  Future<void> _fillCaptcha(List<int> bytes) async {
    setState(() => _ocrBusy = true);
    final guess = await recognizeLoginCaptcha(bytes);
    if (!mounted) return;
    if (guess != null && _captcha.text.isEmpty) {
      _captcha.text = guess;
    }
    setState(() => _ocrBusy = false);
  }

  Future<void> _openForm() async {
    if (_clicked) return;
    setState(() => _clicked = true);
    await _resetSession();
  }

  Future<void> _onLogin() async {
    final email = _email.text.trim();
    final password = _password.text;
    final captcha = _captcha.text.replaceAll(' ', '');
    if (email.isEmpty || password.isEmpty || captcha.isEmpty) {
      setState(() => _info = '请填写以上字段');
      return;
    }
    setState(() {
      _loading = true;
      _info = '登录请求中...';
    });
    try {
      final err = await ref
          .read(authControllerProvider.notifier)
          .loginWithPassword(
            email: email,
            password: password,
            captcha: captcha,
            formhash: _formhash,
            cookie: _cookie,
          );
      if (!mounted) return;
      if (err == null) {
        context.go('/progress');
        return;
      }
      setState(() {
        _loading = false;
        _info = err;
      });
      await _resetSession();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _info = apiErrorMessage(e);
      });
      await _resetSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LogoHeader(),
      body: _clicked ? _buildForm(context) : _buildPreview(context),
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      child: Column(
        children: [
          const Spacer(),
          const Mesume(size: 160),
          const SizedBox(height: 28),
          BgmButton('账号登录', onPressed: _openForm),
          const SizedBox(height: 12),
          BgmButton(
            '游客预览',
            type: BgmButtonType.plain,
            onPressed: () => showBgmToast(context, '游客预览依赖原版私有 cookie, 未移植'),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _LoginFooterLink(
                label: '注册',
                external: true,
                onTap: () => _confirmRegister(context),
              ),
              _LoginFooterLink(
                label: '隐私保护政策',
                external: true,
                onTap: () => openExternalUrl(htmlPrivacy()),
              ),
              _LoginFooterLink(
                label: '授权登录',
                onTap: () => context.push('/login/oauth'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final ds = context.ds;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
      children: [
        const Mesume(size: 96),
        const SizedBox(height: 20),
        BgmField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          hintText: 'Email',
        ),
        const SizedBox(height: 12),
        BgmField(
          controller: _password,
          obscureText: true,
          hintText: '密码',
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: BgmField(
                controller: _captcha,
                textInputAction: TextInputAction.done,
                hintText: _ocrBusy ? '正在识别验证码…' : '验证码',
                onSubmitted: (_) => _onLogin(),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _captchaBusy ? null : _resetSession,
              child: Container(
                width: 118,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ds.surfaceCard,
                  borderRadius: AppRadius.lAll,
                ),
                child: _captchaBusy
                    ? const BgmSpinner()
                    : _captchaBytes == null
                    ? Icon(Icons.refresh, color: ds.textSecondary)
                    : Image.memory(_captchaBytes!, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
        if (_info != null) ...[
          const SizedBox(height: 12),
          Text(_info!, style: ds.caption.copyWith(color: ds.error)),
        ],
        const SizedBox(height: 20),
        BgmButton(
          _loading ? '登录中…' : '登录',
          loading: _loading,
          onPressed: _loading ? null : _onLogin,
        ),
        const SizedBox(height: 16),
        Text(
          '隐私策略: 我们十分尊重您的隐私, 我们不会收集上述信息. (多次登录失败后可能一段时间内不能再次登录)',
          style: ds.caption,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: BgmTextAction(
            '遇到连接问题？点击设置代理',
            onPressed: () => context.push('/proxy-help'),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: () => showTokenLoginDialog(context),
            child: Text('Token 登录', style: ds.meta),
          ),
        ),

      ],
    );
  }
}

class _LoginFooterLink extends StatelessWidget {
  final String label;
  final bool external;
  final VoidCallback onTap;

  const _LoginFooterLink({
    required this.label,
    required this.onTap,
    this.external = false,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: ds.meta.copyWith(fontWeight: FontWeight.w700)),
          if (external) ...[
            const SizedBox(width: 2),
            Icon(Icons.open_in_new, size: 12, color: ds.textSecondary),
          ],
        ],
      ),
    );
  }
}

Future<void> _confirmRegister(BuildContext context) async {
  final ok = await showBgmConfirm(
    context,
    title: '提示',
    message:
        '声明: 本客户端的性质为第三方，只提供显示数据和简单的操作，没有修复和改变网站业务的能力。\n\n'
        '在移动端浏览器注册会经常遇到验证码错误，碰到错误建议在浏览器里使用电脑版 UA，再不行推荐使用电脑 Chrome 注册。\n\n'
        '注册后会有激活码发到邮箱，经观察过只会发送一次，请务必在激活有效时间内激活，否则这个注册邮箱就废了。\n\n'
        '输入激活码前，若下方提示出现文字「服务不可用」的请务必等待到浏览器加载条完成再操作，否则可能一直会提示激活码错误。',
    confirmLabel: '前往注册',
  );
  if (ok) await openExternalUrl(htmlSignup());
}

/// 过时的 OAuth WebView (原项目 login/index, 授权登录入口)
class OauthLoginScreen extends ConsumerStatefulWidget {
  const OauthLoginScreen({super.key});

  @override
  ConsumerState<OauthLoginScreen> createState() => _OauthLoginScreenState();
}

class _OauthLoginScreenState extends ConsumerState<OauthLoginScreen> {
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
            if (url.startsWith(kOauthRedirect)) {
              final uri = Uri.parse(url);
              final code = uri.queryParameters['code'];
              if (code != null && code.isNotEmpty) {
                final ok = await ref
                    .read(authControllerProvider.notifier)
                    .loginWithCode(code);
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
                } catch (_) {}
                if (mounted) {
                  if (ok) {
                    context.go('/progress');
                  } else {
                    setState(() {
                      _error = '登录失败, 请重试';
                      _loading = false;
                    });
                  }
                }
                return NavigationDecision.prevent;
              }
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
      appBar: const BgmAppBar(title: ''),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('这是一个过时的功能，不保证能正常使用'),
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading) const Loading(),
                if (_error != null)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!),
                        GestureDetector(
                          onTap: () {
                            setState(() => _error = null);
                            _controller.loadRequest(Uri.parse(kOauthAuthorize));
                          },
                          child: Text(
                            '重试',
                            style: context.ds.caption.copyWith(
                              color: context.ds.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Token 登录对话框 (移植自原项目 login/token 页)
Future<void> showTokenLoginDialog(BuildContext context) {
  final controller = TextEditingController();
  var busy = false;
  return showBgmDialog<void>(
    context: context,
    title: 'Token 登录',
    content: Consumer(
      builder: (ctx, ref, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('粘贴 bgm.tv 的 access_token (OAuth2)。', style: context.ds.caption),
          Align(
            alignment: Alignment.centerRight,
            child: BgmTextAction(
              '如何获取',
              onPressed: () => openExternalUrl('$kHost/group/topic/370315'),
            ),
          ),
          const SizedBox(height: 12),
          BgmField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            hintText: '用户令牌，必填',
          ),
        ],
      ),
    ),
    actions: (ctx) => [
      BgmButton(
        '取消',
        type: BgmButtonType.plain,
        expand: false,
        onPressed: () => Navigator.of(ctx).pop(),
      ),
      BgmButton(
        '登录',
        expand: false,
        onPressed: busy
            ? null
            : () async {
                busy = true;
                final container = ProviderScope.containerOf(ctx);
                final ok = await container
                    .read(authControllerProvider.notifier)
                    .loginWithToken(controller.text);
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                showBgmToast(context, ok ? '登录成功' : '更新失败, 请确保用户令牌可用');
                if (ok) context.go('/progress');
              },
      ),
    ],
  );
}
