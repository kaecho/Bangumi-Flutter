import 'package:flutter/material.dart';

/// 代理帮助段落
class ProxySection {
  final String title;
  final List<(String, String)> items; // (小节标题, 内容)

  const ProxySection({required this.title, required this.items});
}

/// 网络连接说明 (移植自原项目 screens/web-view/proxy-help)
const List<ProxySection> kProxySections = [
  ProxySection(
    title: '连接模式说明',
    items: [
      ('直连', '所有请求直连默认服务器，不做任何处理，跟客户端以往一致。'),
      ('镜像 / 反代', '通过自建或社区提供的服务访问 Bangumi。需要填写地址，推荐到超展开社区寻找可用服务。'),
      ('自建 Worker 转发', '关闭「直接转发」: 由节点自行处理转发（如 Nginx 直接覆写域名）。'
          '开启「直接转发」: 由 Worker 帮你处理 cookie、重定向等转发细节。推荐保持关闭，直接使用社区提供的服务即可。'),
      ('ECH 模式 (Android)', '自动接管 Bangumi 域名请求，无需配置。通过加密 SNI 和 DNS 保护你的隐私，防止连接被识别和干扰。'
          '实验性功能，不一定有效。此模式开启后接管网址的 WebView 依然会受限。'),
    ],
  ),
  ProxySection(
    title: '什么是镜像 / 反代？',
    items: [
      ('', '反向代理（Reverse Proxy）是一种服务器技术，它位于用户和目标服务器之间，代替用户向目标服务器发起请求，再将结果返回给用户。'),
      ('', '简单来说: 你的请求先到中转服务器，再由中转服务器转发到目标地址，从而优化网络连接并保护你的隐私。'),
      ('', '⚠️ 使用第三方服务意味着你的请求会经过第三方服务器，敏感操作请谨慎。'),
    ],
  ),
  ProxySection(
    title: 'Cloudflare Workers',
    items: [
      ('', 'Cloudflare Workers 是一个免费的边缘计算平台，可以用来搭建中转服务。它的优点是:'),
      ('', '• 免费额度充足，个人使用完全够用\n• 全球节点多，速度快\n• 配置简单，只需一个脚本'),
      ('', '常见的搭建方式是使用开源项目，部署后会得到一个类似 your-name.workers.dev 的地址。'),
    ],
  ),
  ProxySection(
    title: '自建 Worker 需知',
    items: [
      ('', '在请求层层转发后，例如 cookie、授权后的 code、重定向地址等会丢失。'),
      ('', '如果是正常访问普通页面可能不需要，但是登录等复杂操作就必须要自行在 Worker 里捕获并转为例如 x-redirect-url、location、set-cookie 之类的头，透传返回给客户端提取使用。'),
      ('', '如需自建，请到 GitHub 项目目录复制作者提供的 Worker 文件部署到 Cloudflare Worker / Deno Deploy。'),
    ],
  ),
  ProxySection(
    title: 'SNI / ECH / DoH 是什么？',
    items: [
      ('SNI', 'SNI（Server Name Indication）是 TLS 握手时客户端告诉服务器「我要访问哪个域名」的机制。'
          '网络运营商或防火墙可以通过读取 SNI 来识别并拦截特定域名的连接，即使流量已加密。'),
      ('ECH', 'ECH（Encrypted Client Hello）是对 SNI 的加密扩展，将域名信息在 TLS 握手阶段就加密传输，'
          '保护你的隐私，使中间人无法获知你访问的真实域名。'),
      ('DoH', 'DoH（DNS over HTTPS）是通过 HTTPS 协议进行 DNS 查询的技术。传统 DNS 查询是明文的，'
          '容易被劫持或污染。DoH 加密了 DNS 查询内容，保护你的隐私，防止被中间人篡改。'),
    ],
  ),
];

/// 代理帮助 (移植自原项目 screens/web-view/proxy-help)
/// 路由: /proxy-help
class ProxyHelpScreen extends StatelessWidget {
  const ProxyHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('网络连接说明')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '网络连接说明',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const _Paragraph('本客户端支持自定义网络连接方式，保护你的隐私并优化访问体验。'),
          const _Paragraph('如果你已有其他解决方案，建议不要启用此功能，避免产生冲突。'),
          const _Paragraph('填写地址后会立即生效，请确保地址正确，否则会导致客户端无法正常使用。'),
          const _Paragraph('首次设置后，可能需要重新登录或重启应用才能生效。'),
          for (final section in kProxySections) ...[
            const SizedBox(height: 16),
            _SectionHeader(title: section.title),
            for (final (sub, content) in section.items) ...[
              if (sub.isNotEmpty) _SubTitle(text: sub),
              _Paragraph(content),
            ],
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _SubTitle extends StatelessWidget {
  final String text;

  const _SubTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}

class _Paragraph extends StatelessWidget {
  final String text;

  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: const TextStyle(fontSize: 14, height: 1.6)),
    );
  }
}
