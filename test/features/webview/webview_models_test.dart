import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/features/timeline/say_screen.dart';
import 'package:bangumi/features/webview/versions_screen.dart';
import 'package:bangumi/shared/models/timeline.dart';

void main() {
  group('GitHubRelease.fromJson', () {
    test('解析 releases/latest 响应字段', () {
      final release = GitHubRelease.fromJson({
        'tag_name': 'v1.1.0',
        'name': 'v1.1.0',
        'html_url': 'https://github.com/kaecho/Bangumi-Flutter/releases/tag/v1.1.0',
        'body': '更新内容',
        'published_at': '2026-08-01T00:00:00Z',
      });

      expect(release.tagName, 'v1.1.0');
      expect(release.htmlUrl, contains('releases/tag/v1.1.0'));
      expect(release.body, '更新内容');
      expect(release.publishedAt, '2026-08-01T00:00:00Z');
    });

    test('缺失字段时安全降级', () {
      final release = GitHubRelease.fromJson({});
      expect(release.tagName, '');
      expect(release.htmlUrl, '');
    });
  });

  group('isNewerVersion', () {
    test('新版本大于当前版本', () {
      expect(isNewerVersion('v1.1.0', '1.0.0'), isTrue);
      expect(isNewerVersion('v1.0.1', '1.0.0'), isTrue);
      expect(isNewerVersion('2.0.0', 'v1.9.9'), isTrue);
    });

    test('相同或更旧版本返回 false', () {
      expect(isNewerVersion('v1.0.0', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.0', 'v1.0.0+1'), isFalse);
      expect(isNewerVersion('0.9.9', '1.0.0'), isFalse);
    });

    test('不同段数版本号比较', () {
      expect(isNewerVersion('v1.10', '1.9.9'), isTrue);
      expect(isNewerVersion('1.0.1', 'v1.0'), isTrue);
      expect(isNewerVersion('v1.0', '1.0.1'), isFalse);
    });
  });

  group('吐槽模型解析', () {
    test('SayComment.fromJson 解析评论字段', () {
      final comment = SayComment.fromJson({
        'id': 7,
        'user': {
          'id': 99,
          'username': 'sai',
          'nickname': '某科学的超电磁炮',
          'avatar': {'large': '//lain.bgm.tv/pic/user/l/000/00/99.jpg'},
        },
        'content': '不错',
        'created_at': '2026-08-01 12:00:00',
        'likes': 3,
      });

      expect(comment.id, 7);
      expect(comment.user?.id, 99);
      expect(comment.user?.displayName, '某科学的超电磁炮');
      expect(comment.content, '不错');
      expect(comment.likes, 3);
    });

    test('Say.fromJson 解析吐槽与点赞列表', () {
      final say = Say.fromJson({
        'id': 123,
        'user_id': 99,
        'content': '今日份吐槽',
        'created_at': '2026-08-01 12:00:00',
        'likes': [
          {'uid': 1},
          {'uid': 2},
        ],
      });

      expect(say.id, 123);
      expect(say.userId, 99);
      expect(say.content, '今日份吐槽');
      expect(say.likes.length, 2);
    });
  });
}
