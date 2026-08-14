import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';

/// 原项目 screens/web-view/information 补充说明页
String extraNotePath({
  required String title,
  required List<String> message,
  String? url,
  bool advance = false,
  bool ai = false,
}) {
  return Uri(
    path: '/note',
    queryParameters: {
      'title': title,
      'message': message.join('\n'),
      if (url != null && url.isNotEmpty) 'url': url,
      if (advance) 'advance': '1',
      if (ai) 'ai': '1',
    },
  ).toString();
}

class ExtraNoteScreen extends StatelessWidget {
  final String title;
  final String message;
  final String url;
  final bool advance;
  final bool ai;

  const ExtraNoteScreen({
    super.key,
    required this.title,
    this.message = '',
    this.url = '',
    this.advance = false,
    this.ai = false,
  });

  factory ExtraNoteScreen.fromUri(Uri uri) {
    return ExtraNoteScreen(
      title: uri.queryParameters['title'] ?? '',
      message: uri.queryParameters['message'] ?? '',
      url: uri.queryParameters['url'] ?? '',
      advance: uri.queryParameters['advance'] == '1',
      ai: uri.queryParameters['ai'] == '1',
    );
  }

  List<String> get _lines => [
    for (final line in message.split('\n'))
      if (line.trim().isNotEmpty)
        line
            .replaceAll(',', '，')
            .replaceAll('?', '？')
            .replaceAll('(', '「')
            .replaceAll(')', '」'),
  ];

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    final size = lines.length >= 10 ? 14.0 : 16.0;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (title.isNotEmpty)
            Text(
              '「$title」补充说明',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(line, style: TextStyle(fontSize: size, height: 1.45)),
            ),
          if (ai)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                '内容整理自 @DeepSeek',
                textAlign: TextAlign.right,
                style: context.ds.meta,
              ),
            ),
          if (url.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => openExternalUrl(url),
                child: const Text('内容引用地址 〉'),
              ),
            ),
          if (advance)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/settings/qiafan'),
                child: const Text('关于会员 〉'),
              ),
            ),
        ],
      ),
    );
  }
}
