import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/site_cookies.dart';

/// 站点 Cookie 设置页
///
/// 粘贴浏览器导出的 bgm.tv Cookie (JSON 数组或原始 Cookie header),
/// 用于站点认证功能 (短信/电波提醒/点赞/时间线 ajax 等)。
/// 也可在登录后自动从 OAuth WebView 捕获。
class CookieSettingScreen extends ConsumerStatefulWidget {
  const CookieSettingScreen({super.key});

  @override
  ConsumerState<CookieSettingScreen> createState() => _CookieSettingScreenState();
}

class _CookieSettingScreenState extends ConsumerState<CookieSettingScreen> {
  final _controller = TextEditingController();
  bool _saved = false;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(siteCookiesProvider).cookieHeader ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final input = _controller.text.trim();
    final store = ref.read(siteCookiesProvider);
    if (input.isEmpty) {
      await store.clear();
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清除站点 Cookie')),
      );
      return;
    }
    // 支持浏览器导出的 JSON cookie 数组
    if (input.startsWith('[')) {
      try {
        final decoded = Uri.decodeComponent(input);
        final list = (decoded as List).cast<Map<String, dynamic>>();
        await store.setFromJson(list);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JSON 格式不正确, 请检查后重试')),
        );
        return;
      }
    } else {
      await store.setCookieHeader(normalizeCookieTime(input));
    }
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('站点 Cookie 已保存')),
    );
  }

  /// 用保存的 cookie 请求 /notify, 验证登录态
  Future<void> _test() async {
    setState(() => _statusText = '检测中...');
    final client = ref.read(apiClientProvider);
    try {
      final html = await client.fetchHtml('https://bgm.tv/notify');
      if (htmlRequiresLogin(html)) {
        setState(() => _statusText = '检测结果: Cookie 无效 (页面要求登录)');
      } else if (html.contains('没有新提醒') || html.contains('提醒')) {
        setState(() => _statusText = '检测结果: Cookie 有效 ✓ (已登录)');
      } else {
        setState(() => _statusText = '检测结果: 已登录 (页面正常返回)');
      }
    } catch (e) {
      setState(() => _statusText = '检测失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCookies = ref.watch(siteCookiesProvider).hasCookies;
    return Scaffold(
      appBar: AppBar(title: const Text('站点 Cookie 登录')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'bgm.tv 站点 Cookie 用于站点认证功能: 短信、电波提醒、点赞、'
            '时间线、好友申请等。登录 App 后会自动捕获; 也可以手动粘贴浏览器导出的 Cookie。',
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText:
                  '支持两种格式:\n1. Cookie header: chii_sid=xxx; chii_auth=yyy\n2. 浏览器导出 JSON: [{"name":"chii_auth","value":"..."}]',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(onPressed: _save, child: const Text('保存')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _test, child: const Text('检测登录态')),
              const Spacer(),
              TextButton(
                onPressed: hasCookies || _saved
                    ? () async {
                        await ref.read(siteCookiesProvider).clear();
                        _controller.clear();
                        setState(() => _saved = false);
                      }
                    : null,
                child: const Text('清除'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_statusText.isNotEmpty)
            Text(_statusText, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    hasCookies ? Icons.check_circle : Icons.info_outline,
                    size: 20,
                    color: hasCookies
                        ? Colors.green
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasCookies ? '已保存站点 Cookie' : '未保存站点 Cookie',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
