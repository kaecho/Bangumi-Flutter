import 'package:bangumi/core/api/api_client.dart';
import 'package:bangumi/core/api/api_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildApiUri', () {
    test('绝对 URL 直接使用, 不拼接 base (防 host 重复)', () {
      final uri = buildApiUri(apiV0Me());
      expect(uri.toString(), 'https://api.bgmapi.com/v0/me');
    });

    test('绝对 URL + host 参数: host 不参与拼接', () {
      final uri = buildApiUri(kApiAccessToken, host: kHost);
      expect(uri.toString(), 'https://bgm.tv/oauth/access_token');
    });

    test('相对路径拼接 kApiHost', () {
      final uri = buildApiUri('/calendar');
      expect(uri.toString(), 'https://api.bgmapi.com/calendar');
    });

    test('相对路径拼接指定 host', () {
      final uri = buildApiUri('/like?type=40&main_id=1&ajax=1', host: kHost);
      expect(uri.toString(), 'https://bgm.tv/like?type=40&main_id=1&ajax=1');
    });

    test('query 参数合并进最终 URL', () {
      final uri = buildApiUri(
        'https://api.bgmapi.com/v0/subjects',
        query: {'type': 'anime', 'limit': '30'},
      );
      expect(uri.toString(), 'https://api.bgmapi.com/v0/subjects?type=anime&limit=30');
    });
  });

  group('apiV0UsersCollections', () {
    test('字符串 subject_type 映射为 v0 整数枚举', () {
      final url = apiV0UsersCollections('sakurairo', 'anime', 100, 0, '3');
      expect(url, contains('subject_type=2'));
      expect(url, contains('type=3'));
      expect(url, isNot(contains('subject_type=anime')));
    });

    test('已是数字串时原样保留', () {
      final url = apiV0UsersCollections('u', '6', 30, 0, '2');
      expect(url, contains('subject_type=6'));
    });

    test('book/real/game 映射', () {
      expect(apiV0UsersCollections('u', 'book', 1, 0, '1'), contains('subject_type=1'));
      expect(apiV0UsersCollections('u', 'real', 1, 0, '1'), contains('subject_type=6'));
      expect(apiV0UsersCollections('u', 'game', 1, 0, '1'), contains('subject_type=4'));
    });
  });
}
