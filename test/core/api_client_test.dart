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
      expect(
        uri.toString(),
        'https://api.bgmapi.com/v0/subjects?type=anime&limit=30',
      );
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
      expect(
        apiV0UsersCollections('u', 'book', 1, 0, '1'),
        contains('subject_type=1'),
      );
      expect(
        apiV0UsersCollections('u', 'real', 1, 0, '1'),
        contains('subject_type=6'),
      );
      expect(
        apiV0UsersCollections('u', 'game', 1, 0, '1'),
        contains('subject_type=4'),
      );
    });
  });

  group('htmlSubjectComments', () {
    test('默认只有页码', () {
      expect(
        htmlSubjectComments(1),
        'https://bgm.tv/subject/1/comments?page=1',
      );
    });
    test('拼收藏状态和当前版本', () {
      expect(
        htmlSubjectComments(8, page: 2, interestType: 'doings', version: true),
        'https://bgm.tv/subject/8/comments?page=2&interest_type=doings&version=current',
      );
    });
  });

  group('htmlSubjectRating', () {
    test('默认看过页', () {
      expect(
        htmlSubjectRating(8),
        'https://bgm.tv/subject/8/collections?page=1',
      );
    });
    test('好友筛选拼 filter=friends', () {
      expect(
        htmlSubjectRating(8, status: 'doings', friends: true, page: 2),
        'https://bgm.tv/subject/8/doings?page=2&filter=friends',
      );
    });
  });

  group('htmlTimeline', () {
    test('好友/全站走主站 /timeline', () {
      expect(htmlTimeline(), 'https://bgm.tv/timeline?type=&page=1');
      expect(
        htmlTimeline(type: 'say', page: 2),
        'https://bgm.tv/timeline?type=say&page=2',
      );
    });
  });

  group('apiUserCatalogsHtml', () {
    test('创建的走 /index, 收藏的走 /index/collect', () {
      expect(
        apiUserCatalogsHtml('sakura'),
        'https://bgm.tv/user/sakura/index?page=1',
      );
      expect(
        apiUserCatalogsHtml('sakura', collect: true, page: 2),
        'https://bgm.tv/user/sakura/index/collect?page=2',
      );
    });
  });

  group('apiUserBlogsHtml', () {
    test('按页拉取用户日志', () {
      expect(
        apiUserBlogsHtml('sakura', page: 3),
        'https://bgm.tv/user/sakura/blog?page=3',
      );
    });
  });

  group('apiUserMonoHtml', () {
    test('按页拉取收藏角色/人物', () {
      expect(
        apiUserMonoHtml('sakura', kind: 'character', page: 2),
        'https://bgm.tv/user/sakura/mono/character?page=2',
      );
      expect(
        apiUserMonoHtml('sakura', kind: 'person', page: 1),
        'https://bgm.tv/user/sakura/mono/person?page=1',
      );
    });
  });

  group('htmlUserMonoRecents', () {
    test('人物近况走 /mono/update', () {
      expect(htmlUserMonoRecents(page: 2), 'https://bgm.tv/mono/update?page=2');
    });
  });

  group('htmlDollars', () {
    test('聊天室与轮询参数', () {
      expect(htmlDollars(), 'https://bgm.tv/dollars');
      expect(
        htmlDollars(sinceId: '123', ts: 9),
        'https://bgm.tv/dollars?since_id=123&_=9',
      );
      expect(htmlDollarsSend(), 'https://bgm.tv/dollars?ajax=1');
    });
  });

  group('htmlCatalogDetail', () {
    test('目录详情走主站 /index/{id}', () {
      expect(htmlCatalogDetail(8), 'https://bgm.tv/index/8');
    });
  });

  group('htmlNewTopic', () {
    test('全局与小组发帖地址', () {
      expect(htmlNewTopic(), 'https://bgm.tv/rakuen/new_topic');
      expect(htmlNewTopic(group: 'dev'), 'https://bgm.tv/group/dev/new_topic');
    });
  });

  group('websiteError / auth expiry extras', () {
    test('仅主站 502 记 websiteError', () {
      expect(isWebsiteError('bgm.tv', 502), isTrue);
      expect(isWebsiteError('api.bgmapi.com', 502), isFalse);
      expect(isWebsiteError('bgm.tv', 500), isFalse);
    });

    test('401 记授权过期', () {
      expect(isAuthExpiredStatus(401), isTrue);
      expect(isAuthExpiredStatus(403), isFalse);
    });
  });

  group('server status extras', () {
    test('mini 接口走 bgm-status', () {
      expect(apiMkStatusMini(), 'https://bgm-status.ry.mk/api/mini');
    });
  });

  group('htmlBlogList extras', () {
    test('全部类型走 /blog/{page}.html', () {
      expect(htmlBlogList(), '/blog/1.html');
      expect(htmlBlogList(type: 'all', page: 2), '/blog/2.html');
    });

    test('分类型走 /{type}/blog/{page}.html', () {
      expect(htmlBlogList(type: 'anime'), '/anime/blog/1.html');
      expect(htmlBlogList(type: 'book', page: 3), '/book/blog/3.html');
    });
  });
}
