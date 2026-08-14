import 'package:bangumi/core/status/server_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldNotifyServerStatus', () {
    test('none 永不提示, down 仅中断, degraded 含降级', () {
      expect(shouldNotifyServerStatus('none', 'down'), isFalse);
      expect(shouldNotifyServerStatus('down', 'degraded'), isFalse);
      expect(shouldNotifyServerStatus('down', 'down'), isTrue);
      expect(shouldNotifyServerStatus('degraded', 'degraded'), isTrue);
      expect(shouldNotifyServerStatus('degraded', 'down'), isTrue);
      expect(shouldNotifyServerStatus('degraded', 'ok'), isFalse);
    });
  });
}
