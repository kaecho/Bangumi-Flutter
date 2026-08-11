import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/features/discovery/widgets/discovery_html.dart';
import 'package:bangumi/features/discovery/widgets/recommend_list.dart';
import 'package:bangumi/shared/models/subject.dart';

void main() {
  group('discovery_html 解析', () {
    test('parseSubjectList 解析浏览器条目页', () {
      const html = '''
<html><body>
<ul id="browserItemList">
<li id="item_326" class="item odd clearit" >
  <a href="/subject/326" class="subjectCover cover ll coverPortrait">
    <span class="image"><img src="//lain.bgm.tv/r/400/pic/cover/l/a6/66/326_D8wjw.jpg" class="cover" loading="lazy" /></span>
  </a>
  <div class="inner">
    <h3><a href="/subject/326" class="l">攻壳机动队 S.A.C. 2nd GIG</a> <small class="grey">攻殻機動隊 S.A.C. 2nd GIG</small></h3>
    <span class="rank"><small>Rank </small>1</span>
    <p class="info tip">26话 / 2004年1月1日 / 神山健治</p>
    <p class="rateInfo"><span class="starstop-s"><span class="starlight stars9"></span></span> <small class="fade">9.2</small> <span class="tip_j">(10055人评分)</span></p>
  </div>
</li>
</ul>
</body></html>
''';
      final subjects = parseSubjectList(html);
      expect(subjects, hasLength(1));
      final s = subjects.first;
      expect(s.id, 326);
      expect(s.nameCn, '攻壳机动队 S.A.C. 2nd GIG');
      expect(s.name, '攻殻機動隊 S.A.C. 2nd GIG');
      expect(s.rank, 1);
      expect(s.eps, 26);
      expect(s.airDate, '2004-1-1');
      expect(s.rating!.score, closeTo(9.2, 0.001));
      expect(s.rating!.total, 10055);
      expect(s.images.medium, 'https://lain.bgm.tv/r/400/pic/cover/l/a6/66/326_D8wjw.jpg');
    });

    test('parseBlogList 解析全站日志', () {
      const html = '''
<div id="columnA">
<div id="entry_list" class="entry-list ">
<div class="item clearit" data-item-user="1260714" >
  <p class="cover"> <a href="/blog/378382" title="t" class="avatar"> <img src="//lain.bgm.tv/pic/user/l/icon.jpg" class="avatarCover" /> </a> </p>
  <div class="entry">
    <h2 class="title"><a href="/blog/378382" class="l">海角为什么值得选择</a></h2>
    <div class="content"><a href="/blog/378382">正文内容一</a></div>
    <div class="time"> <a href="/user/1260714" class="l">纯</a>&nbsp;· 2026-8-11 20:06&nbsp;· <a href="/blog/378382" class="l">0 回复</a> </div>
  </div>
</div>
</div>
</div>
''';
      final rows = parseBlogList(html);
      expect(rows, hasLength(1));
      expect(rows.first.id, 378382);
      expect(rows.first.title, '海角为什么值得选择');
      expect(rows.first.username, '纯');
      expect(rows.first.userId, 1260714);
      expect(rows.first.time, '2026-8-11 20:06');
      expect(rows.first.replies, 0);
    });

    test('parseTagList 解析标签列表', () {
      const html = '''
<div id="tagList"><a href="/anime/tag/TV" class="l level1">TV</a><small class="grey">(1396928)</small> &nbsp; <a href="/anime/tag/%E6%BC%AB%E7%94%BB%E6%94%B9" class="l level1">漫画改</a><small class="grey">(857,680)</small></div>
''';
      final tags = parseTagList(html);
      expect(tags, hasLength(2));
      expect(tags[0].name, 'TV');
      expect(tags[0].count, 1396928);
      expect(tags[1].name, '漫画改');
      expect(tags[1].count, 857680);
    });

    test('parseGroupList 解析小组列表', () {
      const html = '''
<ul class="groupsLarge">
<li><a href="/group/pixiv" title="pixiv"><span class="pictureFrameGroup"><span class="image"><img src="//lain.bgm.tv/pic/icon/l/000/00/00/84.jpg"></span><span class="overlay"></span></span>pixiv</a><br /><small class="feed">16,038 位成员</small></li>
</ul>
''';
      final groups = parseGroupList(html);
      expect(groups, hasLength(1));
      expect(groups.first.name, 'pixiv');
      expect(groups.first.title, 'pixiv');
      expect(groups.first.members, 16038);
      expect(groups.first.icon, 'https://lain.bgm.tv/pic/icon/l/000/00/00/84.jpg');
    });

    test('parseTopicRows 解析 Dollars 论坛主题', () {
      const html = '''
<table class="topic_list"><tbody>
<tr class="topic even" data-item-user="553331">
  <td class="subject"><a href="/group/topic/358379" title="嗨多磨" class="l">嗨多磨</a></td>
  <td class="author"><a href="/user/553331" class="l">樱井龙之介</a></td>
  <td class="posts">2</td>
  <td class="lastpost"><small class="time">2020-8-18 17:53</small></td>
</tr>
</tbody></table>
''';
      final rows = parseTopicRows(html);
      expect(rows, hasLength(1));
      expect(rows.first.id, 358379);
      expect(rows.first.title, '嗨多磨');
      expect(rows.first.username, '樱井龙之介');
      expect(rows.first.replies, 2);
      expect(rows.first.lastTime, '2020-8-18 17:53');
    });

    test('parseV0Collections 解析收藏分页响应', () {
      final items = parseV0Collections({
        'total': 1,
        'limit': 100,
        'offset': 0,
        'data': [
          {
            'subject_id': 246430,
            'type': 3,
            'ep_status': 12,
            'updated_at': '2026-07-01T00:00:00.000+08:00',
            'subject': {
              'id': 246430,
              'name': 'Sample Anime',
              'name_cn': '示例动画',
              'images': {'large': 'https://lain.bgm.tv/pic/cover/l/x.jpg'},
              'rank': 42,
              'score': 8.5,
              'tags': [{'name': '原创', 'count': 1}],
            },
          },
        ],
      });
      expect(items, hasLength(1));
      expect(items.first.subjectId, 246430);
      expect(items.first.type, 3);
      expect(items.first.epStatus, 12);
      expect(items.first.subject.displayName, '示例动画');
      expect(items.first.subject.rank, 42);
    });
  });

  group('推荐评分', () {
    test('calcRecommendScore 高分条目得分更高', () {
      final good = calcRecommendScore(V0CollectionItem(
        subjectId: 1,
        type: 2,
        updatedAt: '2026-08-10T00:00:00.000+08:00',
        subject: Subject(
          id: 1,
          name: 'good',
          images: const SubjectImages(),
          rank: 10,
          rating: const Rating(score: 9.0, total: 100),
          tags: const [Tag(name: '原创', count: 1)],
        ),
      ));
      final poor = calcRecommendScore(V0CollectionItem(
        subjectId: 2,
        type: 5,
        updatedAt: '2020-01-01T00:00:00.000+08:00',
        subject: const Subject(
          id: 2,
          name: 'poor',
          images: SubjectImages(),
        ),
      ));
      expect(good, greaterThan(poor));
    });
  });
}
