import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/loading.dart';

/// 原版 HeaderV2 title
const kServerStatusTitle = '网络探针';

/// 探针目标 (移植自原项目 server-status utils)
const kPingTargets = [
  ('bgm.tv', '主站 (必要)', 'https://bgm.tv'),
  ('api.bgm.tv', '主站 API (必要)', 'https://api.bgm.tv/v0/me'),
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
    if (statusCode == 200 || statusCode == 204) {
      if (elapsedMs <= 150) return Colors.green;
      if (elapsedMs <= 1000) return context.ds.star;
      return Theme.of(context).colorScheme.error;
    }
    if (statusCode != 0) return context.ds.star;
    return Theme.of(context).colorScheme.error;
  }
}

/// 网络探针 (原版 ServerStatus)
class ServerStatusScreen extends ConsumerStatefulWidget {
  const ServerStatusScreen({super.key});

  @override
  ConsumerState<ServerStatusScreen> createState() => _ServerStatusScreenState();
}

class _ServerStatusScreenState extends ConsumerState<ServerStatusScreen> {
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
      sendTimeout: const Duration(seconds: 6),
      headers: {'User-Agent': 'Bangumi/Flutter'},
    ),
  );

  final List<PingResult?> _results = List<PingResult?>.filled(
    kPingTargets.length,
    null,
  );
  final List<bool> _loading = List<bool>.filled(kPingTargets.length, false);
  bool _pinging = false;

  Future<PingResult> _pingAt(int index) async {
    final (title, desc, url) = kPingTargets[index];
    final watch = Stopwatch()..start();
    try {
      final resp = await _dio.get<dynamic>(url);
      watch.stop();
      return PingResult(
        title: title,
        desc: desc,
        url: url,
        statusCode: resp.statusCode ?? 0,
        elapsedMs: watch.elapsedMilliseconds,
      );
    } catch (e) {
      watch.stop();
      String message = e.toString();
      if (e is DioException) {
        message = switch (e.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout => '超时',
          DioExceptionType.connectionError => '连接失败',
          _ => 'HTTP ${e.response?.statusCode ?? '错误'}',
        };
      }
      return PingResult(
        title: title,
        desc: desc,
        url: url,
        statusCode: 0,
        elapsedMs: watch.elapsedMilliseconds,
        error: message,
      );
    }
  }

  Future<void> _pingOne(int index) async {
    if (_pinging) return;
    setState(() {
      _pinging = true;
      _loading[index] = true;
      _results[index] = null;
    });
    final result = await _pingAt(index);
    if (!mounted) return;
    setState(() {
      _results[index] = result;
      _loading[index] = false;
      _pinging = false;
    });
  }

  Future<void> _pingAll() async {
    if (_pinging) return;
    setState(() {
      _pinging = true;
      for (var i = 0; i < _results.length; i++) {
        _results[i] = null;
        _loading[i] = false;
      }
    });
    for (var i = 0; i < kPingTargets.length; i++) {
      if (!mounted) return;
      setState(() => _loading[i] = true);
      final result = await _pingAt(i);
      if (!mounted) return;
      setState(() {
        _results[i] = result;
        _loading[i] = false;
      });
    }
    if (mounted) setState(() => _pinging = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BgmAppBar(title: kServerStatusTitle),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text('这是一个过时的功能，目前已不作维护。', style: context.ds.caption),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: context.ds.caption,
                    children: [
                      const TextSpan(
                        text: '绿色 < 150ms',
                        style: TextStyle(color: Colors.green),
                      ),
                      const TextSpan(text: '，'),
                      TextSpan(
                        text: '黄色 < 1000ms',
                        style: TextStyle(color: context.ds.star),
                      ),
                      const TextSpan(text: '，'),
                      TextSpan(
                        text: '红色 (或超时) > 1000ms',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const TextSpan(text: '，若必要服务为红色则严重影响 App 的正常使用'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < kPingTargets.length; i++)
                  _PingRow(
                    index: i,
                    result: _results[i],
                    loading: _loading[i],
                    enabled: !_pinging,
                    onPing: () => _pingOne(i),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: BgmButton(
                '全部检测',
                loading: _pinging,
                onPressed: _pinging ? null : _pingAll,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PingRow extends StatelessWidget {
  final int index;
  final PingResult? result;
  final bool loading;
  final bool enabled;
  final VoidCallback onPing;

  const _PingRow({
    required this.index,
    required this.result,
    required this.loading,
    required this.enabled,
    required this.onPing,
  });

  @override
  Widget build(BuildContext context) {
    final target = kPingTargets[index];
    final r = result;
    final subtitle = r == null
        ? target.$1
        : '${target.$1}\n${r.statusCode == 200 || r.statusCode == 204 ? '${r.elapsedMs}ms' : r.statusText}';
    return BgmSettingRow(
      title: '${index + 1}. ${target.$2}',
      subtitle: subtitle,
      trailing: loading
          ? const SizedBox(
              width: 52,
              child: Center(child: BgmSpinner(size: 16)),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (r != null)
                  Icon(Icons.circle, size: 12, color: r.color(context)),
                const SizedBox(width: 8),
                BgmButton(
                  '检测',
                  expand: false,
                  type: BgmButtonType.plain,
                  onPressed: enabled ? onPing : null,
                ),
              ],
            ),
    );
  }
}
