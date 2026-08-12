import 'dart:io';

import 'package:bangumi/core/debug/debug_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('debug_log_test');
    DebugLog.instance.directory = tempDir;
  });

  tearDown(() {
    DebugLog.instance.clear();
    tempDir.deleteSync(recursive: true);
  });

  test('write 追加时间戳日志到文件', () async {
    await DebugLog.instance.write('GET /v0/me → 200 (12ms)');
    final f = File('${tempDir.path}/$kDebugLogFileName');
    expect(f.existsSync(), isTrue);
    final content = f.readAsStringSync();
    expect(content, contains('GET /v0/me → 200 (12ms)'));
    expect(content, matches(RegExp(r'^\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\]')));
  });

  test('内存尾部保留最近 200 行', () async {
    for (var i = 0; i < 250; i++) {
      await DebugLog.instance.write('line $i');
    }
    expect(DebugLog.instance.tail.length, 200);
    expect(DebugLog.instance.tail.first, 'line 50');
    expect(DebugLog.instance.tail.last, 'line 249');
  });

  test('超过 1MB 轮转到 .1 文件', () async {
    // 单条日志约 1KB, 写 1100 条超过 1MB 触发轮转
    for (var i = 0; i < 1100; i++) {
      await DebugLog.instance.write('line $i ${'x' * 1000}');
    }
    expect(File('${tempDir.path}/$kDebugLogFileName').existsSync(), isTrue);
    final old = File('${tempDir.path}/$kDebugLogFileName.1');
    expect(old.existsSync(), isTrue);
    // 轮转: 旧内容整体移入 .1, 新文件从头记录
    expect(old.readAsStringSync(), contains('line 0'));
    final fresh = File('${tempDir.path}/$kDebugLogFileName');
    expect(fresh.readAsStringSync(), isNot(contains('line 0')));
  });

  test('clear 删除文件并清空尾部', () async {
    await DebugLog.instance.write('a');
    await DebugLog.instance.clear();
    expect(File('${tempDir.path}/$kDebugLogFileName').existsSync(), isFalse);
    expect(DebugLog.instance.tail, isEmpty);
    expect(await DebugLog.instance.path(), isNull);
  });
}
