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

  group('apiEpStatus', () {
    test('对齐原版 watched/queue/drop/remove', () {
      expect(
        apiEpStatus(12, 'watched'),
        'https://api.bgmapi.com/ep/12/status/watched',
      );
      expect(
        apiEpStatus(12, 'queue'),
        'https://api.bgmapi.com/ep/12/status/queue',
      );
      expect(
        apiEpStatus(12, 'drop'),
        'https://api.bgmapi.com/ep/12/status/drop',
      );
      expect(
        apiEpStatus(12, 'remove'),
        'https://api.bgmapi.com/ep/12/status/remove',
      );
    });
  });

  group('htmlTimelineReply', () {
    test('回复吐槽走主站 ajax', () {
      expect(htmlTimelineReply(99), '/timeline/99/new_reply?ajax=1');
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

  group('htmlUserMonoPage', () {
    test('用户人物走 /user/{id}/mono', () {
      expect(htmlUserMonoPage('sakura'), 'https://bgm.tv/user/sakura/mono');
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
    test('目录留言走主站 /index/{id}/comments', () {
      expect(htmlCatalogComments(8), 'https://bgm.tv/index/8/comments');
    });

    test('新建目录与添加条目走主站 POST', () {
      expect(htmlCatalogCreate(), 'https://bgm.tv/index/create');
      expect(htmlCatalogAddRelated(8), 'https://bgm.tv/index/8/add_related');
    });
    test('网页版目录和反向解除好友', () {
      expect(
        htmlSpaCatalogDetail(8),
        'https://bangumi-app.5t5.top/iframe.html?id=screens-catalogdetail--catalog-detail'
        '&viewMode=story&catalogId=8',
      );
      expect(
        spaStoryId('CatalogDetail'),
        'screens-catalogdetail--catalog-detail',
      );
      expect(
        spaStoryId('DiscoveryBlog'),
        'screens-discoveryblog--discovery-blog',
      );
      expect(spaStoryId('Staff'), 'screens-staff--staff');
      expect(
        htmlSpa('DiscoveryBlog'),
        'https://bangumi-app.5t5.top/iframe.html?id=screens-discoveryblog--discovery-blog&viewMode=story',
      );
      expect(htmlMonoVoices(8), 'https://bgm.tv/person/8/works/voice');
      expect(
        htmlMonoVoices(8, position: '/anime'),
        'https://bgm.tv/person/8/works/voice/anime',
      );
      expect(
        htmlMonoWorks('person', 8),
        'https://bgm.tv/person/8/works?sort=date&page=1',
      );
      expect(
        htmlMonoWorks('person', 8, position: '/position/1', sort: 'rank'),
        'https://bgm.tv/person/8/works/position/1?sort=rank&page=1',
      );

      expect(
        apiDisconnectRev('12', 'hash'),
        'https://bgm.tv/disconnect/rev/12?gh=hash',
      );
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

  group('site / api UA', () {
    test('主站 UA 是桌面 Chrome, 不是 Android 126', () {
      expect(kSiteUserAgent, contains('Windows NT 10.0'));
      expect(kSiteUserAgent, contains('Chrome/151'));
      expect(kSiteUserAgent, isNot(contains('Android 14')));
    });

    test('API UA 仍是应用标识', () {
      expect(kApiUserAgent, startsWith('Bangumi/Flutter'));
    });
  });

  group('htmlTopicReply / coverUrl', () {
    test('对齐原版 HTML_ACTION_RAKUEN_REPLY', () {
      expect(
        htmlTopicReply('group/468754'),
        'https://bgm.tv/group/topic/468754/new_reply?ajax=1',
      );
      expect(
        htmlTopicReply('subject/123'),
        'https://bgm.tv/subject/topic/123/new_reply?ajax=1',
      );
      expect(
        htmlTopicReply('ep/1705009'),
        'https://bgm.tv/subject/ep/1705009/new_reply?ajax=1',
      );
      expect(
        htmlTopicReply('crt/1'),
        'https://bgm.tv/character/1/new_reply?ajax=1',
      );
      expect(
        htmlTopicReply('prsn/2'),
        'https://bgm.tv/person/2/new_reply?ajax=1',
      );
      expect(
        htmlBlogReply(378305),
        'https://bgm.tv/blog/entry/378305/new_reply?ajax=1',
      );
    });

    test('coverUrl 不破坏 r/N/l', () {
      const src = 'https://lain.bgm.tv/r/400/pic/cover/l/ab/cd.jpg';
      expect(coverUrl(src), src);
      expect(
        coverUrl('https://lain.bgm.tv/pic/cover/l/ab/cd.jpg', size: 'c'),
        'https://lain.bgm.tv/pic/cover/c/ab/cd.jpg',
      );
    });
  });

  group('login / cookie merge', () {
    test('mergeSiteCookies 只保留 chii_* 并覆盖同名', () {
      expect(
        mergeSiteCookies('chii_sid=old; foo=bar', [
          'chii_auth=token; Path=/',
          'chii_sid=new; HttpOnly',
          'unrelated=x',
        ]),
        'chii_sid=new; chii_auth=token',
      );
    });

    test('oauthCodeFromUrl 抽 query', () {
      expect(
        oauthCodeFromUrl('https://bgm.tv/dev/app?code=abc123&state=1'),
        'abc123',
      );
      expect(oauthCodeFromUrl(null), isNull);
    });

    test('loginFailMessage 识别封禁', () {
      expect(loginFailMessage('累计错误, 15 分钟内您将不能登录本站。'), contains('15 分钟'));
    });

    test('htmlSignupCaptcha 可固定时间戳', () {
      expect(htmlSignupCaptcha(1), 'https://bgm.tv/signup/captcha?1');
      expect(htmlLogin(), 'https://bgm.tv/login');
      expect(htmlFollowTheRabbit(), 'https://bgm.tv/FollowTheRabbit');
    });
  });

  group('html tag extras', () {
    test('htmlTypeTag 空关键字走类型页, 有关键字走 search/tag', () {
      expect(htmlTypeTag('anime'), '/anime/tag');
      expect(htmlTypeTag('anime', page: 2), '/anime/tag?page=2');
      expect(htmlTypeTag('book', filter: 'TV'), '/search/tag/book/TV?page=1');
    });

    test('htmlTagSubjects 拼 sort airtime meta', () {
      expect(
        htmlTagSubjects('anime', 'TV'),
        '/anime/tag/TV?sort=collects&page=1&meta=',
      );
      expect(
        htmlTagSubjects(
          'anime',
          'TV',
          sort: 'rank',
          airtime: '2024-4',
          meta: true,
        ),
        '/anime/tag/TV/airtime/2024-4?sort=rank&page=1&meta=1',
      );
    });

    test('p1 用户时间线默认 limit=1', () {
      expect(
        apiP1UsersTimeline('sai'),
        'https://next.bgm.tv/p1/users/sai/timeline?limit=1',
      );
    });
  });
}
