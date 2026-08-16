import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/app_bar.dart';

/// 同步类 WebView 页面骨架 (bilibili/豆瓣 同步共用)
///
/// 流程: 网页内登录第三方账号 → 完成同步 → (跳转回本域视为成功) → 点「完成」返回
class SyncWebViewScaffold extends StatefulWidget {
  final String title;
  final String url;

  /// 初始域名 (如 account.bilibili.com), 离开该域名视为授权/同步成功
  final String domain;
  final String? notePath;

  const SyncWebViewScaffold({
    super.key,
    required this.title,
    required this.url,
    required this.domain,
    this.notePath,
  });

  @override
  State<SyncWebViewScaffold> createState() => _SyncWebViewScaffoldState();
}

class _SyncWebViewScaffoldState extends State<SyncWebViewScaffold> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _done = false;
  String _status = '请在网页中登录并完成同步';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) {
            // 离开初始域 (授权回调) 视为同步成功
            final uri = Uri.parse(request.url);
            if (uri.host.isNotEmpty && !uri.host.endsWith(widget.domain)) {
              setState(() {
                _done = true;
                _status = '同步完成, 点击「完成」返回';
              });
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: BgmAppBar(
        title: widget.title,
        actions: [
          if (widget.notePath != null)
            BgmHeaderAction(
              tooltip: '说明',
              icon: const Icon(Icons.info_outline),
              onPressed: () => context.push(widget.notePath!),
            ),
          BgmHeaderAction(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading) const Loading(),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            color: _done
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Icon(
                    _done ? Icons.check_circle : Icons.sync,
                    color: _done ? scheme.primary : scheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: scheme.onSurface),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BgmButton(
                    '完成',
                    expand: false,
                    onPressed: () => context.pop(),
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
