import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/features/subject/html_parser.dart';
import 'package:bangumi/features/subject/subject_models.dart';
import 'package:bangumi/shared/models/collection.dart';
import 'package:bangumi/shared/models/ep.dart';
import 'package:bangumi/shared/models/subject.dart';

void main() {
  group('Subject.fromJson', () {
    test('解析旧版 API 数字类型 (2=anime)', () {
      final subject = Subject.fromJson({
        'id': 8,
        'url': 'http://bgm.tv/subject/8',
        'type': 2,
        'name': 'コードギアス',
        'name_cn': 'Code Geass',
        'summary': '简介',
        'air_date': '2008-04-06',
        'images': {'large': 'http://lain.bgm.tv/pic/cover/l/x.jpg'},
        'rating': {
          'total': 18611,
          'score': 8.3,
          'rank': 85,
          'count': {'1': 53, '10': 3046},
        },
        'collection': {
          'wish': 1,
          'collect': 2,
          'doing': 3,
          'on_hold': 4,
          'dropped': 5,
        },
      });

      expect(subject.id, 8);
      expect(subject.type, 'anime');
      expect(subject.displayName, 'Code Geass');
      expect(subject.rating?.score, 8.3);
      expect(subject.rating?.count[10], 3046);
      expect(subject.collection?.total, 15);
      expect(subject.images.large, 'https://lain.bgm.tv/pic/cover/l/x.jpg');
    });

    test('解析 v0 数字类型与字符串类型', () {
      expect(Subject.fromJson({'type': 1}).type, 'book');
      expect(Subject.fromJson({'type': 3}).type, 'music');
      expect(Subject.fromJson({'type': 4}).type, 'game');
      expect(Subject.fromJson({'type': 6}).type, 'real');
      expect(Subject.fromJson({'type': 'anime'}).type, 'anime');
      expect(Subject.fromJson({}).type, 'anime');
    });
  });

  group('Infobox.valueText', () {
    test('字符串与数字值', () {
      expect(const Infobox(key: '话数', value: '25').valueText, '25');
      expect(const Infobox(key: '话数', value: 25).valueText, '25');
    });

    test('v0 嵌套 [{v: ...}] 结构', () {
      const info = Infobox(
        key: '别名',
        value: [
          {'v': '叛逆的鲁路修'},
          {'v': 'Code Geass'},
        ],
      );
      expect(info.valueText, '叛逆的鲁路修 / Code Geass');
    });

    test('空值安全', () {
      expect(const Infobox(key: 'k', value: null).valueText, '');
    });
  });

  group('EpList.fromJson', () {
    test('按类型分组', () {
      final list = EpList.fromJson([
        {
          'id': 1,
          'type': 0,
          'sort': 1,
          'name': 'A',
          'duration': '24m',
          'airdate': '2008-04-06',
        },
        {'id': 2, 'type': 0, 'sort': 2, 'name': 'B'},
        {'id': 3, 'type': 1, 'sort': 1, 'name': '特典'},
        {'id': 4, 'type': 2, 'sort': 1, 'name': 'OP'},
        {'id': 5, 'type': 3, 'sort': 1, 'name': 'ED'},
      ]);

      expect(list.eps.length, 2);
      expect(list.type1.length, 1);
      expect(list.type2.length, 1);
      expect(list.type3.length, 1);
      expect(list.total, 5);
      expect(list.eps.first.duration, '24m');
    });
  });

  group('CollectionStatus', () {
    test('状态文案', () {
      expect(CollectionStatus.text(1), '想看');
      expect(CollectionStatus.text(2), '看过');
      expect(CollectionStatus.text(3), '在看');
      expect(CollectionStatus.text(4), '搁置');
      expect(CollectionStatus.text(5), '抛弃');
      expect(CollectionStatus.actionText(0), '收藏');
      expect(SubjectType.statusText(1, 'book'), '想读');
      expect(SubjectType.statusText(3, 'game'), '在玩');
    });
  });

  group('CollectionDetail.fromJson', () {
    test('解析旧版收藏接口 (status 内嵌)', () {
      final detail = CollectionDetail.fromJson({
        'subject_id': 8,
        'rate': 9,
        'comment': '好看',
        'tags': ['神作', '机战'],
        'ep_status': 12,
        'status': {'id': 123, 'type': 2},
      });

      expect(detail.subjectId, 8);
      expect(detail.rate, 9);
      expect(detail.type, 2);
      expect(detail.epStatus, 12);
      expect(detail.tags, ['神作', '机战']);
      expect(detail.hasCollection, isTrue);
    });

    test('未收藏时 hasCollection 为 false', () {
      expect(
        CollectionDetail.fromJson({'subject_id': 1}).hasCollection,
        isFalse,
      );
    });
  });

  group('CharacterVo.fromJson (v0 角色含声优)', () {
    test('解析 actors', () {
      final char = CharacterVo.fromJson({
        'id': 1,
        'name': 'ルルーシュ',
        'name_cn': '鲁路修',
        'relation': '主角',
        'images': {'large': 'http://lain.bgm.tv/pic/crt/l/1.jpg'},
        'actors': [
          {
            'id': 3818,
            'name': '福山潤',
            'name_cn': '福山润',
            'career': ['seiyu'],
          },
        ],
      });

      expect(char.displayName, '鲁路修');
      expect(char.relation, '主角');
      expect(char.actors.length, 1);
      expect(char.actors.first.displayName, '福山润');
      expect(char.images.large, 'https://lain.bgm.tv/pic/crt/l/1.jpg');
    });
  });

  group('EpStatusMap', () {
    test('progressOf 计算连续已看数', () {
      final map = EpStatusMap(watched: {1: true, 2: true, 3: false});
      expect(map.isWatched(1), isTrue);
      expect(map.isWatched(3), isFalse);
      expect(
        map.progressOf(const [
          Ep(id: 1, sort: 1),
          Ep(id: 2, sort: 2),
          Ep(id: 3, sort: 3),
        ]),
        2,
      );
    });

    test('无状态时取 ep_status 兜底', () {
      expect(const EpStatusMap(epStatus: 5).progressOf(const [Ep(id: 1)]), 5);
    });
  });

  group('parseSubjectCommentsHtml', () {
    test('解析吐槽条目字段', () {
      final page = parseSubjectCommentsHtml('''
        <div id="SecTab"><a class="chiiBtn" href="/subject/1/comments?version=current">当前版本</a></div>

        <div class="page_inner"><strong class="p_cur">1</strong>
          <span class="p_edge">(&nbsp;1&nbsp;/&nbsp;2&nbsp;)</span></div>
        <div class="item clearit" data-item-user="745654">
          <a href="/user/745654" class="avatar">
            <span class="avatarNeue avatarSize32 ll" style="background-image:url('//lain.bgm.tv/pic/user/l/x.jpg')"></span></a>
          <div class="text_container text_main_even"><div class="text">
            <div class="actions_container"><div class="post_actions"></div></div>
            <a href="/user/745654" class="l">mudeki</a>
            <span class="starstop-s"><span class="starlight stars8"></span></span>
            <small class="grey"> 看过 </small>
            <small class="grey">@ 2026-8-1 12:00</small>
            <p class="comment">第一次补完，很好看</p>
          </div></div>
        </div>
      ''');

      expect(page.page, 1);
      expect(page.pageTotal, 2);
      expect(page.hasVersion, isTrue);
      expect(page.items.length, 1);
      final c = page.items.first;
      expect(c.userName, 'mudeki');
      expect(c.star, 8);
      expect(c.action, '看过');
      expect(c.content, '第一次补完，很好看');
      expect(c.avatar, 'https://lain.bgm.tv/pic/user/l/x.jpg');
    });

    test('空页面返回空列表', () {
      final page = parseSubjectCommentsHtml('<html><body></body></html>');
      expect(page.items, isEmpty);
      expect(page.page, 1);
    });
  });

  group('parseTopicCommentsHtml', () {
    test('解析章节楼层', () {
      final page = parseTopicCommentsHtml('''
        <div id="comment_list">
          <div id="post_20873" class="light_odd row row_reply  clearit" name="floor-1" data-item-user="demetrio">
            <div class="post_actions re_info"><div class="action">
              <small><a href="#post_20873" class="floor-anchor">#1</a> - 2011-5-9 11:17</small></div></div>
            <a href="/user/demetrio" class="avatar">
              <span class="avatarNeue avatarReSize40 ll" style="background-image:url('//lain.bgm.tv/pic/user/l/1.jpg')"></span></a>
            <div class="inner">
              <strong><a href="/user/demetrio" class="l post_author_20873">莫干山男爵</a></strong>
              <div class="reply_content"><div class="message clearit">二周目启动</div></div>
            </div>
          </div>
        </div>
      ''');

      expect(page.items.length, 1);
      final c = page.items.first;
      expect(c.id, '20873');
      expect(c.userName, '莫干山男爵');
      expect(c.time, '2011-5-9 11:17');
      expect(c.content, '二周目启动');
    });
  });

  group('parseCatalogsHtml', () {
    test('解析目录条目', () {
      final items = parseCatalogsHtml('''
        <li id="item_44847" class="clearit tml_item index-item">
          <span class="avatar"><a href="/user/mrwangbote" class="avatar">
            <span class="avatarNeue avatarReSize40 ll" style="background-image:url('//lain.bgm.tv/pic/user/l/a.jpg')"></span></a></span>
          <span class="info clearit"><div class="clearit">
            <span class="stats tip rr"><span class="num">1000</span></span>
            <a href="/index/44847" class="l"><h3>全年代日本动画佳作榜</h3></a>
          </div>
          <span class="time tip_i"><a href="/user/mrwangbote" class="l">隔壁的王某某</a> ·
            更新 <span class="tip_j">2026-8-2 17:22</span></span></span>
        </li>
      ''');

      expect(items.length, 1);
      final c = items.first;
      expect(c.id, 44847);
      expect(c.title, '全年代日本动画佳作榜');
      expect(c.userName, '隔壁的王某某');
      expect(c.collected, 1000);
      expect(c.updatedAt, '2026-8-2 17:22');
    });
  });

  group('parseWikiEditsHtml', () {
    test('解析修订记录', () {
      final edits = parseWikiEditsHtml('''
        <ul id="pagehistory"><li class="line_even">
          <span class="subjectRevisionEntry">
            <a href="#;" title="条目">2026-4-20 13:30</a>
            <a href="/user/xiaonvsheng" title="有职转死" class="l">有职转死</a>
            <span class="comment">(内容扩充)</span>
          </span>
          <span class="subjectRevisionChoices">
            <label class="subjectRevisionChoice"><input type="checkbox" name="rev[]" value="1803048" /></label>
          </span>
        </li></ul>
      ''');

      expect(edits.length, 1);
      final e = edits.first;
      expect(e.time, '2026-4-20 13:30');
      expect(e.userName, '有职转死');
      expect(e.summary, '内容扩充');
      expect(e.rev, 1803048);
    });
  });

  group('parseSubjectHtmlExtras', () {
    test('解析锁定提示、猜你喜欢与谁在看', () {
      final extras = parseSubjectHtmlExtras('''
        <div class="tipIntro"><div class="inner">
          <h3>条目已锁定</h3>
        </div></div>
        <ul class="coversSmall">
          <li>
            <a href="/subject/12" title="cowboy bebop">
              <span style="background-image:url('//lain.bgm.tv/pic/cover/s/12.jpg')"></span>
              <span class="l">cowboy bebop</span>
            </a>
          </li>
        </ul>
        <ul id="subjectPanelCollect">
          <li>
            <span class="avatarNeue" style="background-image:url('//lain.bgm.tv/pic/user/s/1.jpg')"></span>
            <div class="innerWithAvatar">
              <a href="/user/sai" class="avatar">sai</a>
              <span class="starlight stars8"></span>
              <small class="grey">2小时前</small>
            </div>
          </li>
        </ul>
      ''');
      expect(extras.lock, '条目已锁定');
      expect(extras.likes.first.id, 12);
      expect(extras.recent.length, 1);
      expect(extras.recent.first.userId, 'sai');
      expect(extras.recent.first.name, 'sai');
      expect(extras.recent.first.star, 8);
      expect(extras.recent.first.status, '2时前');
    });

    test('解析曲目列表', () {
      final extras = parseSubjectHtmlExtras('''
        <ul class="line_list_music">
          <li class="cat">Disc 1</li>
          <li><h6><a href="/ep/101">Opening</a></h6></li>
          <li><h6><a href="/ep/102">Tank!</a></h6></li>
          <li class="cat">Disc 2</li>
          <li><h6><a href="/ep/201">The Real Folk Blues</a></h6></li>
        </ul>
      ''');
      expect(extras.discs.length, 2);
      expect(extras.discs.first.title, 'Disc 1');
      expect(extras.discs.first.tracks.map((e) => e.title), [
        'Opening',
        'Tank!',
      ]);
      expect(extras.discs.first.tracks.first.epId, 101);
      expect(extras.discs.last.tracks.single.title, 'The Real Folk Blues');
    });

    test('解析单行本', () {
      final extras = parseSubjectHtmlExtras('''
        <h2 class="subtitle">单行本</h2>
        <ul class="browserCoverMedium">
          <li>
            <a href="/subject/200" title="第1卷">
              <span style="background-image:url('//lain.bgm.tv/pic/cover/s/1.jpg')"></span>
              <a class="title">第1卷</a>
            </a>
          </li>
        </ul>
      ''');
      expect(extras.comics.length, 1);
      expect(extras.comics.first.id, 200);
      expect(extras.comics.first.name, '第1卷');
    });

    test('解析好友评分', () {
      final extras = parseSubjectHtmlExtras('''
        <div class="frdScore">
          <span class="num">7.8</span>
          <a class="l">12 人评分</a>
        </div>
      ''');
      expect(extras.friendScore, 7.8);
      expect(extras.friendTotal, 12);
    });

    test('无 tipIntro 时 lock 为空', () {
      expect(parseSubjectHtmlExtras('<div></div>').lock, '');
      expect(parseSubjectHtmlExtras('<div></div>').likes, isEmpty);
      expect(parseSubjectHtmlExtras('<div></div>').recent, isEmpty);
    });
  });

  group('parseSubjectRatingHtml', () {
    test('解析人数和好友评分行', () {
      final page = parseSubjectRatingHtml('''
        <div id="columnInSubjectA">
          <ul class="secTab">
            <li>想看 11</li>
            <li>看过 22</li>
            <li>在看 33</li>
            <li>搁置 4</li>
            <li>抛弃 5</li>
          </ul>
          <ul id="memberUserList">
            <li>
              <a href="/user/abc" class="avatar">好友甲</a>
              <span class="avatarNeue" style="background-image:url('//lain.bgm.tv/pic/user/l/a.jpg')"></span>
              <span class="starlight stars9"></span>
              <p class="info">2026-8-1</p>
              <div class="userContainer">好友甲
2026-8-1
好看</div>
            </li>
          </ul>
        </div>
        <div id="columnInSubjectB"></div>
      ''');
      expect(page.wishes, 11);
      expect(page.collections, 22);
      expect(page.doings, 33);
      expect(page.onHold, 4);
      expect(page.dropped, 5);
      expect(page.items, hasLength(1));
      expect(page.items.first.userId, 'abc');
      expect(page.items.first.userName, '好友甲');
      expect(page.items.first.star, 9);
      expect(page.items.first.content, contains('好看'));
    });
  });

  group('RatingStats.deviation', () {
    test('全员同分时争议度为占位符', () {
      const stats = RatingStats(score: 8, total: 10, counts: {8: 10});
      expect(stats.deviation, 0);
      expect(stats.dispute, '-');
    });

    test('极端两极分化时争议度为厨黑大战', () {
      const stats = RatingStats(score: 5.5, total: 20, counts: {1: 10, 10: 10});
      expect(stats.deviation, greaterThan(1.75));
      expect(stats.dispute, '厨黑大战');
    });
  });
}
