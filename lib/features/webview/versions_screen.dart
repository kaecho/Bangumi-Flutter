import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_endpoints.dart';

/// 当前应用版本 (与 pubspec.yaml version 保持一致)
const String kAppVersion = '1.0.0';

/// GitHub Release 信息
class GitHubRelease {
  final String tagName;
  final String name;
  final String htmlUrl;
  final String body;
  final String publishedAt;

  const GitHubRelease({
    this.tagName = '',
    this.name = '',
    this.htmlUrl = '',
    this.body = '',
    this.publishedAt = '',
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) => GitHubRelease(
        tagName: json['tag_name'] as String? ?? '',
        name: json['name'] as String? ?? '',
        htmlUrl: json['html_url'] as String? ?? '',
        body: json['body'] as String? ?? '',
        publishedAt: json['published_at'] as String? ?? '',
      );
}

/// 版本号比较 (支持 v1.2.3 / 1.2.3): latest > current 返回 true
bool isNewerVersion(String latest, String current) {
  List<int> parse(String v) {
    final cleaned = v.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final parts = cleaned.split(RegExp(r'[.\-+]'));
    return [for (final p in parts) int.tryParse(p) ?? 0];
  }

  final a = parse(latest);
  final b = parse(current);
  final len = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < len; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// 更新日志 (assets/changelog.md)
final changelogProvider = FutureProvider<String>(
  (ref) => rootBundle.loadString('assets/changelog.md'),
);

/// GitHub 最新 Release 检查 (仅用于版本比对, 不走认证拦截器)
final releaseCheckProvider = FutureProvider<GitHubRelease?>((ref) async {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  try {
    final resp = await dio.get('$kGithubApiHost${apiGithubReleasesLatest()}');
    final data = resp.data as Map<String, dynamic>?;
    if (data == null) return null;
    return GitHubRelease.fromJson(data);
  } catch (_) {
    return null;
  }
});

/// 版本信息 (移植自原项目 screens/web-view/versions)
///
/// 当前版本 + 更新日志 + GitHub Releases 检查更新。
/// 路由: /versions
class VersionsScreen extends ConsumerWidget {
  const VersionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final changelog = ref.watch(changelogProvider);
    final release = ref.watch(releaseCheckProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('版本信息'),
        actions: [
          IconButton(
            tooltip: '重新检查',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(releaseCheckProvider),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline, color: scheme.primary),
              title: const Text('当前版本'),
              subtitle: Text('Bangumi Flutter v$kAppVersion'),
            ),
          ),
          const SizedBox(height: 8),
          ...release.when(
            loading: () => const [Card(child: ListTile(title: Text('正在检查更新...')))],
            error: (_, _) => const [Card(child: ListTile(title: Text('检查更新失败')))],
            data: (value) {
              if (value == null) {
                return const [Card(child: ListTile(title: Text('检查更新失败'))]);
              }
              final newer = isNewerVersion(value.tagName, kAppVersion);
              return [
                Card(
                  color: newer ? scheme.primaryContainer : null,
                  child: ListTile(
                    leading: Icon(
                      newer ? Icons.system_update_alt : Icons.check_circle_outline,
                      color: scheme.primary,
                    ),
                    title: Text(newer ? '发现新版本 ${value.tagName}' : '已是最新版本'),
                    subtitle: Text(newer ? value.name : '当前版本已是最新'),
                    trailing: newer
                        ? TextButton(
                            onPressed: () => launchUrl(Uri.parse(value.htmlUrl)),
                            child: const Text('查看'),
                          )
                        : null,
                  ),
                ),
              ];
            },
          ),
          const SizedBox(height: 16),
          const Text('更新日志', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          changelog.when(
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )),
            error: (_, _) => const Text('更新日志加载失败'),
            data: (text) => SelectableText(
              text,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
