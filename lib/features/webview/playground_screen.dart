import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_endpoints.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/app_bar.dart';

/// 开发沙盒 (API 调试)
///
/// 输入完整 URL (或相对路径, 自动拼接 bgm 主域名), 发起 GET 请求并查看响应。
/// 路由: /playground
class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({super.key});

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  final _controller = TextEditingController(text: '$kApiHost/calendar');
  bool _loading = false;
  String? _error;
  int? _statusCode;
  String _response = '';

  Future<void> _send() async {
    var input = _controller.text.trim();
    if (input.isEmpty) return;
    if (!input.startsWith('http://') && !input.startsWith('https://')) {
      input = '$kApiHost$input';
    }
    setState(() {
      _loading = true;
      _error = null;
      _response = '';
      _statusCode = null;
    });
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          headers: {
            'User-Agent':
                'Bangumi/Flutter (https://github.com/kaecho/Bangumi-Flutter)',
          },
        ),
      );
      final resp = await dio.get<dynamic>(input);
      setState(() {
        _statusCode = resp.statusCode;
        _response = _pretty(resp.data);
      });
    } on DioException catch (e) {
      setState(() {
        _statusCode = e.response?.statusCode;
        _error = '请求失败: ${e.type.name}';
        _response = _pretty(e.response?.data);
      });
    } catch (e) {
      setState(() => _error = '请求失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _pretty(dynamic data) {
    if (data is String) return data;
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: BgmAppBar(
        title: 'API 沙盒',
        actions: [
          BgmHeaderAction(
            tooltip: '发送',
            icon: _loading ? const BgmSpinner() : const Icon(Icons.send),
            onPressed: _loading ? null : _send,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: BgmField(
              controller: _controller,
              hintText: '输入 URL 或相对路径, 如 /calendar',
              keyboardType: TextInputType.url,
              onSubmitted: (_) => _send(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (_statusCode != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (_statusCode! >= 200 && _statusCode! < 300)
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'HTTP $_statusCode',
                      style: TextStyle(
                        fontSize: 12,
                        color: (_statusCode! >= 200 && _statusCode! < 300)
                            ? Colors.green.shade900
                            : Colors.red.shade900,
                      ),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(fontSize: 12, color: scheme.error),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          const BgmHairline(),
          Expanded(
            child: _response.isEmpty && !_loading
                ? const Center(child: Text('输入地址后点击发送'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      _response.isEmpty ? '请求中...' : _response,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
