import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/core/api/api_client.dart';
import 'package:bangumi/core/html/bgm_html_parser.dart';

void main() {
  group('buildCookieHeaderFromJson', () {
    test('浏览器导出 JSON → header', () {
      final cookies = [
        {'name': 'chii_sid', 'value': 'abc123'},
        {'name': 'chii_auth', 'value': 'tok%2Fen'},
        {'name': 'chii_cookietime', 'value': '0'},
      ];
      final header = buildCookieHeaderFromJson(cookies);
      expect(header, contains('chii_sid=abc123'));
      expect(header, contains('chii_auth=tok%2Fen'));
    });

    test('忽略无效条目', () {
      final header = buildCookieHeaderFromJson([
        {'name': '', 'value': 'x'},
        'not-a-map',
      ]);
      expect(header, '');
    });
  });

  group('normalizeCookieTime', () {
    test('chii_cookietime 归一化为 2592000 (记住登录)', () {
      final normalized = normalizeCookieTime('chii_sid=a; chii_cookietime=0; chii_auth=b');
      expect(normalized, contains('chii_cookietime=2592000'));
      expect(normalized, contains('chii_sid=a'));
    });

    test('无 chii_cookietime 时原样保留', () {
      expect(normalizeCookieTime('chii_sid=a'), 'chii_sid=a');
    });

    test('空输入返回空', () {
      expect(normalizeCookieTime(''), '');
    });
  });

  group('htmlRequiresLogin', () {
    test('登录提示页判定', () {
      const html = '<div class="message"><h2>呜咕，出错了</h2>'
          '<p class="text">抱歉，当前操作需要您 <a href="/login">登录</a> 后才能继续进行</p></div>';
      expect(htmlRequiresLogin(html), isTrue);
    });

    test('正常页面判定', () {
      expect(htmlRequiresLogin('<html><body>正常内容</body></html>'), isFalse);
    });
  });

  group('parseFormhash', () {
    test('提取隐藏字段', () {
      const html = '<form><input type="hidden" name="formhash" value="fH7x2Y"></form>';
      expect(parseFormhash(html), 'fH7x2Y');
    });

    test('无 formhash 返回空', () {
      expect(parseFormhash('<html></html>'), '');
    });
  });
}
