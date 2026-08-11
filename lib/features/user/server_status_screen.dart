import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 探针目标 (移植自原项目 server-status utils)
const kPingTargets = [
  ('bgm.tv', '主站', 'https://bgm.tv'),
  ('api.bgm.tv', '主站 API', 'https://api.bgm.tv/v0/me'),
  ('bgmapi.com', 'API 镜像', 'https://api.bgmapi.com/calendar'),
  ('tinygrail.com', '小圣杯 API', 'https://tinygrail.com'),
  ('bgm-status.ry.mk', '服务器状态站', 'https://bgm-status.ry.mk'),
];

class PingResult {
  final String title;
  final String desc;
  final String url;
  final int statusCode;
  final int elapsedMs;
  final String? error;

  const PingResult({
    required this.title,
    required this.desc,
    required this.url,
    this.statusCode = 0,
    this.elapsedMs = 0,
    this.error,
  });

  String get statusText => switch (statusCode) {
        200 || 204 => '正常',
        _ => error ?? '异常',
      };

  Color color(BuildContext context) {
    if (statusCode == 200 || statusCode == 204) return Colors.green;
    if (statusCode != 0) return Colors.orange;
    return Theme.of(context).colorScheme.error;
  }
}

/// 服务器状态 (网络探针)
class ServerStatusScreen extends ConsumerStatefulWidget {
  const ServerStatusScreen({super.key});

  @override
  ConsumerState<ServerStatusScreen> createState() => _ServerStatusScreenState();
}

class _ServerStatusScreenState extends ConsumerState<ServerStatusScreen> {
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
    sendTimeout: const Duration(seconds: 6),
    headers: {'User-Agent': 'Bangumi/Flutter'},
  ));

  List<PingResult> _results = const [];
  bool _pinging = false;

  Future<void> _pingAll() async {
    if (_pinging) return;
    setState(() {
      _pinging = true;
      _results = const [];
    });
    final results = <PingResult>[];
    for (final (title, desc, url) in kPingTargets) {
      final watch = Stopwatch()..start();
      try {
        final resp = await _dio.get<dynamic>(url);
        watch.stop();
        results.add(PingResult(
          title: title,
          desc: desc,
          url: url,
          statusCode: resp.statusCode ?? 0,
          elapsedMs: watch.elapsedMilliseconds,
        ));
      } catch (e) {
        watch.stop();
        String message = e.toString();
        if (e is DioException) {
          message = switch (e.type) {
            DioExceptionType.connectionTimeout ||
            DioExceptionType.sendTimeout ||
            DioExceptionType.receiveTimeout =>
              '超时',
            DioExceptionType.connectionError => '连接失败',
            _ => 'HTTP ${e.response?.statusCode ?? '错误'}',
          };
        }
        results.add(PingResult(
          title: title,
          desc: desc,
          url: url,
          statusCode: 0,
          elapsedMs: watch.elapsedMilliseconds,
          error: message,
        ));
      }
      if (mounted) setState(() => _results = List.of(results));
    }
    if (mounted) setState(() => _pinging = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器状态'),
        actions: [
          TextButton(
            onPressed: _pinging ? null : _pingAll,
            child: Text(_pinging ? '检测中…' : '全部检测'),
          ),
        ],
      ),
      body: _results.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monitor_heart_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('点击右上角开始检测'),
                  const SizedBox(height: 8),
                  Text(
                    '同时检测 api.bgm.tv 与 bgm-status.ry.mk',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final r = _results[index];
                return Card(
                  child: ListTile(
                    leading: Icon(Icons.circle, size: 14, color: r.color(context)),
                    title: Text('${r.title} (${r.desc})'),
                    subtitle: Text(
                      '${r.url}\n${r.statusCode == 200 || r.statusCode == 204 ? '${r.elapsedMs}ms' : r.statusText}',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                );
              ),
            ),
    );
  }
}
