import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/core/utils/url_match.dart';

void main() {
  group('matchBgmUrl', () {
    test('提取链接', () {
      expect(
        matchBgmUrl('看看这个 https://bgm.tv/subject/123 怎么样'),
        'https://bgm.tv/subject/123',
      );
    });
    test('无链接返回 null', () {
      expect(matchBgmUrl('没有链接'), isNull);
    });
    test('支持 bangumi.tv 与 chii.in', () {
      expect(
        matchBgmUrl('https://bangumi.tv/subject/456'),
        startsWith('https://bangumi.tv'),
      );
      expect(
        matchBgmUrl('https://chii.in/subject/789'),
        startsWith('https://chii.in'),
      );
    });
  });

  group('bgmUrlToRoute', () {
    test('条目', () {
      expect(bgmUrlToRoute('https://bgm.tv/subject/123'), '/subject/123');
    });
    test('条目吐槽箱 (进入条目页)', () {
      expect(
        bgmUrlToRoute('https://bgm.tv/subject/123/comments'),
        '/subject/123',
      );
    });
    test('小组帖子', () {
      expect(
        bgmUrlToRoute('https://bgm.tv/group/350677'),
        '/rakuen/group/350677',
      );
    });
    test('小组帖子 topic 形式', () {
      expect(
        bgmUrlToRoute('https://bgm.tv/group/topic/350677'),
        '/rakuen/topic/group/350677',
      );
    });
    test('rakuen 帖子', () {
      expect(
        bgmUrlToRoute('https://bgm.tv/rakuen/topic/group/350677'),
        '/rakuen/topic/group/350677',
      );
    });
    test('用户', () {
      expect(bgmUrlToRoute('https://bgm.tv/user/sai'), '/user/sai');
    });
    test('用户目录', () {
      expect(
        bgmUrlToRoute('https://bgm.tv/user/sai/index'),
        '/user/sai/catalogs',
      );
    });
    test('用户日志', () {
      expect(bgmUrlToRoute('https://bgm.tv/user/sai/blog'), '/user/sai/blogs');
    });
    test('用户人物', () {
      expect(bgmUrlToRoute('https://bgm.tv/user/sai/mono'), '/user/sai/mono');
    });
    test('用户好友', () {
      expect(
        bgmUrlToRoute('https://bgm.tv/user/sai/friends'),
        '/user/sai/friends',
      );
    });
    test('标签', () {
      expect(bgmUrlToRoute('https://bgm.tv/anime/tag/TV'), '/tags/anime/TV');
    });
    test('角色', () {
      expect(
        bgmUrlToRoute('https://bgm.tv/character/111328'),
        '/mono/character/111328',
      );
    });
    test('人物', () {
      expect(
        bgmUrlToRoute('https://bgm.tv/person/40794'),
        '/mono/person/40794',
      );
    });
    test('人物角色进独立页', () {
      expect(
        bgmUrlToRoute('https://bgm.tv/person/40794/works/voice'),
        '/mono/person/40794/voices',
      );
    });

    test('日志', () {
      expect(bgmUrlToRoute('https://bgm.tv/blog/1234'), '/rakuen/blog/1234');
    });
    test('目录', () {
      expect(bgmUrlToRoute('https://bgm.tv/index/1234'), '/catalog/1234');
    });

    test('外站链接返回 null', () {
      expect(bgmUrlToRoute('https://example.com/subject/123'), isNull);
    });
  });
}
