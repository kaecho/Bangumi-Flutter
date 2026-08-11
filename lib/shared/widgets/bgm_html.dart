import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// 通用 HTML 渲染 (帖子/日志/楼层内容)
///
/// - body 14px, 行高 1.6
/// - 引用块 (<q>) 左侧主题色边框 + 浅底色
/// - 图片最大宽度 100%, 点击进入全屏查看器
/// - 链接主题色, bgm 站内链接跳转对应页面, 其余用系统浏览器打开
class BgmHtml extends StatelessWidget {
  final String data;
  final TextStyle? textStyle;
  final Color? quoteBackground;

  /// 是否渲染 <img> (楼层图片自动加载设置)
  final bool showImages;

  const BgmHtml({
    super.key,
    required this.data,
    this.textStyle,
    this.quoteBackground,
    this.showImages = true,
  });

  static const _imageExt = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var html = data;
    if (!showImages) {
      html = html.replaceAll(RegExp(r'<img[^>]*>', caseSensitive: false), '');
    }
    if (html.trim().isEmpty) return const SizedBox.shrink();
    final bodyStyle = textStyle ??
        TextStyle(
          fontSize: 14,
          height: 1.6,
          color: theme.colorScheme.onSurface,
        );
    final accent = theme.colorScheme.primary;
    final quoteBg = quoteBackground ??
        (theme.brightness == Brightness.light
            ? const Color(0xFFF2F3F5)
            : const Color(0xFF2A2A2A));

    return Html(
      data: data,
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(bodyStyle.fontSize ?? 14),
          lineHeight: LineHeight.number(bodyStyle.height ?? 1.6),
          color: bodyStyle.color,
        ),
        'q': Style(
          display: Display.block,
          margin: Margins.symmetric(vertical: 6, horizontal: 0),
          padding: HtmlPaddings.symmetric(vertical: 8, horizontal: 10),
          backgroundColor: quoteBg,
          border: Border(
            left: BorderSide(color: accent, width: 3),
          ),
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: FontSize(13),
        ),
        'blockquote': Style(
          display: Display.block,
          margin: Margins.symmetric(vertical: 6, horizontal: 0),
          padding: HtmlPaddings.symmetric(vertical: 8, horizontal: 10),
          backgroundColor: quoteBg,
          border: Border(
            left: BorderSide(color: accent, width: 3),
          ),
          color: theme.colorScheme.onSurfaceVariant,
        ),
        'pre': Style(
          backgroundColor: theme.brightness == Brightness.light
              ? const Color(0xFFF6F6F6)
              : const Color(0xFF1E1E1E),
          padding: HtmlPaddings.all(8),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          fontSize: FontSize(12.5),
          fontFamily: 'monospace',
        ),
        'code': Style(
          backgroundColor: theme.brightness == Brightness.light
              ? const Color(0xFFF0F0F0)
              : const Color(0xFF2A2A2A),
          fontSize: FontSize(12.5),
        ),
        'a': Style(color: accent, textDecoration: TextDecoration.none),
        'img': Style(
          // 无尺寸属性的图片限制为容器宽度
          width: Width(100, WidthUnit.percent),
        ),
      },
      customRender: {
        // 图片点击 → 全屏查看
        'img': (context, child) {
          final src = context.tree.element.attributes['src'] ?? '';
          if (src.isEmpty) return child;
          return GestureDetector(
            onTap: () => _openImage(context, src),
            child: child,
          );
        },
      },
      onLinkTap: (url, attributes, element) {
        if (url == null || url.isEmpty) return;
        _handleLink(context, url);
      },
    );
  }

  void _openImage(BuildContext context, String src) {
    final url = src.startsWith('//') ? 'https:$src' : src;
    context.push('/rakuen/image?url=${Uri.encodeComponent(url)}');
  }

  void _handleLink(BuildContext context, String url) {
    var href = url;
    if (href.startsWith('//')) href = 'https:$href';

    // bgm 站内帖子/日志/条目 → 站内页面
    final topic = RegExp(r'^(?:https?://bgm\.tv)?/rakuen/topic/([^/]+/\d+)').firstMatch(href);
    if (topic != null) {
      context.push('/rakuen/topic/${topic.group(1)}');
      return;
    }
    final topic2 = RegExp(r'^(?:https?://bgm\.tv)?/(group|subject)/topic/(\d+)').firstMatch(href);
    if (topic2 != null) {
      context.push('/rakuen/topic/${topic2.group(1)}/${topic2.group(2)}');
      return;
    }
    final blog = RegExp(r'^(?:https?://bgm\.tv)?/blog/(\d+)').firstMatch(href);
    if (blog != null) {
      context.push('/rakuen/blog/${blog.group(1)}');
      return;
    }
    final subject = RegExp(r'^(?:https?://bgm\.tv)?/subject/(\d+)').firstMatch(href);
    if (subject != null) {
      context.push('/subject/${subject.group(1)}');
      return;
    }
    // 图片链接 → 查看器
    final lower = href.toLowerCase();
    if (_imageExt.any(lower.endsWith)) {
      _openImage(context, href);
      return;
    }
    launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
  }
}
