/// 调试日志 (设置 → 调试模式 开启后由 [ApiClient] 写入)
///
/// - 文件: 应用支持目录/debug.log, 超过 [kMaxBytes] 时轮转为 debug.log.1
/// - 内存: 保留最近 [kTailLines] 行, 供「开发」页即时展示
/// - 日志不包含 Authorization / Cookie 等敏感信息 (见 ApiClient 调用处)
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

const int kMaxBytes = 1024 * 1024; // 1MB 轮转
const int kTailLines = 200;
const String kDebugLogFileName = 'debug.log';

class DebugLog {
  DebugLog._();

  static final DebugLog instance = DebugLog._();

  final List<String> _tail = [];
  Directory? _dir;

  /// 测试可注入目录; 未设置时使用应用支持目录
  @visibleForTesting
  set directory(Directory value) => _dir = value;

  Future<Directory> _ensureDir() async {
    _dir ??= await getApplicationSupportDirectory();
    return _dir!;
  }

  Future<File> _file() async {
    final dir = await _ensureDir();
    return File('${dir.path}/$kDebugLogFileName');
  }

  /// 追加一行日志 (带时间戳)
  Future<void> write(String line) async {
    try {
      _tail.add(line);
      if (_tail.length > kTailLines) _tail.removeAt(0);
      final f = await _file();
      final size = f.existsSync() ? f.lengthSync() : 0;
      if (size > kMaxBytes) {
        // 轮转: 旧文件覆盖为 .1, 新日志另起
        final old = File('${f.path}.1');
        if (old.existsSync()) old.deleteSync();
        f.renameSync(old.path);
      }
      f.writeAsStringSync('[${_now()}] $line\n', mode: FileMode.append);
    } catch (_) {
      // 调试日志失败不影响业务
    }
  }

  /// 最近日志 (内存尾部, 供「开发」页即时展示)
  List<String> get tail => List.unmodifiable(_tail);

  Future<void> clear() async {
    _tail.clear();
    try {
      final f = await _file();
      if (f.existsSync()) f.deleteSync();
      final old = File('${f.path}.1');
      if (old.existsSync()) old.deleteSync();
    } catch (_) {}
  }

  Future<String?> path() async {
    try {
      final f = await _file();
      if (f.existsSync()) return f.path;
    } catch (_) {}
    return null;
  }

  static String _now() {
    final t = DateTime.now().toIso8601String();
    return t.substring(0, 19); // 2026-08-12T19:16:39
  }
}
