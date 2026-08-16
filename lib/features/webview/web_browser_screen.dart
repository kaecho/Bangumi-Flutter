import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/utils/display.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/loading.dart';

/// 内置浏览器 (移植自原项目 screens/web-view/web-browser)
///
/// 路由: /web/:url (url 需 Uri.encodeComponent 编码)
class WebBrowserScreen extends StatefulWidget {
  final String url;
  final String? title;

  const WebBrowserScreen({super.key, required this.url, this.title});

  @override
  State<WebBrowserScreen> createState() => _WebBrowserScreenState();
}

class _WebBrowserScreenState extends State<WebBrowserScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) => setState(() => _progress = progress),
          onPageStarted: (_) => setState(() {
            _loading = true;
            _error = null;
          }),
          onPageFinished: (_) => setState(() => _loading = false),
        ),
      );
    if (widget.url.isEmpty) {
      _error = '链接无效';
      _loading = false;
    } else {
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  void _refresh() {
    _controller.reload();
  }

  Future<void> _share() async {
    final url = await _controller.currentUrl() ?? widget.url;
    await SharePlus.instance.share(ShareParams(text: url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: widget.title ?? '浏览器',
        actions: [
          BgmHeaderAction(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          BgmHeaderAction(
            tooltip: '浏览器查看',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openExternalUrl(widget.url),
          ),
          BgmHeaderAction(
            tooltip: '分享',
            icon: const Icon(Icons.share_outlined),
            onPressed: _share,
          ),
        ],
        bottom: _loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress / 100),
              )
            : null,
      ),

      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading && _progress == 0) const Loading(),
          if (_error != null) BgmRetry(onRetry: _refresh, message: _error),
        ],
      ),
    );
  }
}
