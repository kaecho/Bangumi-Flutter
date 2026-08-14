import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/core/html/bgm_html_parser.dart';

void main() {
  group('htmlDecode', () {
    test('反转义实体', () {
      expect(
        htmlDecode('a&amp;b &lt;c&gt; &quot;d&quot; &nbsp;'),
        'a&b <c> "d"  ',
      );
    });
  });

  group('htmlMatch', () {
    test('提取片段 (不含 end 标记, 与原项目一致)', () {
      expect(
        htmlMatch('xx<div id="a">content</div>yy', '<div id="a">', '</div>'),
        '<div id="a">content',
      );
    });
    test('起点缺失返回空', () {
      expect(htmlMatch('no marker here', '<div id="a">', '</div>'), '');
    });
  });

  group('relativeEnToEpoch', () {
    final loaded = DateTime(2026, 8, 11, 12, 0, 0).millisecondsSinceEpoch;

    test('刚刚 (无法解析为偏移, 与 RN 一致)', () {
      expect(relativeToEpoch('刚刚', loaded), isNull);
    });
    test('中文 N分钟前', () {
      expect(relativeToEpoch('5分钟前', loaded), loaded - 5 * 60 * 1000);
    });
    test('中文 组合格式 (3天15时前)', () {
      expect(
        relativeToEpoch('3天15时前', loaded),
        loaded - (3 * 86400 + 15 * 3600) * 1000,
      );
    });
    test('中文 小时 词 (3小时前 无法解析, 与 RN 一致)', () {
      expect(relativeToEpoch('3小时前', loaded), isNull);
    });
    test('中文 N天前', () {
      expect(relativeToEpoch('2天前', loaded), loaded - 2 * 86400 * 1000);
    });
    test('英文 ago 格式', () {
      expect(relativeEnToEpoch('...3m ago', loaded), loaded - 3 * 60 * 1000);
      expect(
        relativeEnToEpoch('...1h 2m ago', loaded),
        loaded - (3600 + 120) * 1000,
      );
      expect(relativeEnToEpoch('...2d ago', loaded), loaded - 2 * 86400 * 1000);
    });
    test('无法识别返回 null', () {
      expect(relativeEnToEpoch('明年', loaded), isNull);
    });
  });

  group('parseRakuenList', () {
    test('解析列表项', () {
      const html = '''
<div id="eden_tpc_list">
  <ul>
    <li class="item_list">
      <span class="avatarNeue" style="background-image: url('//lain.bgm.tv/pic/user/l/000/00/00/1.jpg?r=1')" data-user="12345"></span>
      <div class="inner">
        <a class="title" href="/rakuen/topic/group/350677">这是一个测试帖子</a>
        <span class="row">
          <a href="/group/bgm">小组名</a>
          <small class="time">5分钟前</small>
          <small class="grey">10</small>
        </span>
      </div>
    </li>
  </ul>
</div>
''';
      final items = parseRakuenList(html);
      expect(items.length, 1);
      final item = items.first;
      expect(item.title, '这是一个测试帖子');
      expect(item.href, '/rakuen/topic/group/350677');
      expect(item.topicId, 'group/350677');
      expect(item.userId, '12345');
      expect(item.group, '小组名');
      expect(item.replies.trim(), '10');
      expect(item.time, '5分钟前');
      expect(item.avatar, contains('1.jpg'));
    });

    test('无列表返回空', () {
      expect(parseRakuenList('<html><body>空</body></html>'), isEmpty);
    });
  });

  group('parseRakuenFloors', () {
    test('解析楼层', () {
      const html = '''
<div id="comment_list" class="commentList">
  <div id="post_123" class="row row_reply clearit">
    <div class="post_actions"><div class="action"><small><a class="floor-anchor">#1</a> - 5分钟前</small></div></div>
    <a href="/user/42" class="avatar"><span class="avatarNeue" style="background-image:url('//lain.bgm.tv/pic/user/l/1.jpg')"></span></a>
    <div class="inner">
      <span class="userInfo"><strong><a class="l" href="/user/42">用户A</a></strong> <span class="sign">签名</span></span>
      <div class="reply_content"><div class="message">楼上说得对 <q>引用</q></div></div>
      <div class="likes_grid">3</div>
    </div>
  </div>
</div>
''';
      final floors = parseRakuenFloors(html);
      expect(floors.length, 1);
      final f = floors.first;
      expect(f.id, '123');
      expect(f.userName, '用户A');
      expect(f.userId, '42');
      expect(f.floor, '#1');
      expect(f.time, '5分钟前');
      expect(f.source, '');
      expect(f.messageHtml, contains('楼上说得对'));
      expect(f.likes, 3);
    });

    test('解析楼层来源', () {
      const html = '''
<div id="comment_list" class="commentList">
  <div id="post_9" class="row row_reply clearit">
    <div class="post_actions"><div class="action"><small><a class="floor-anchor">#2</a> - 3小时前 · Bangumi for android</small></div></div>
    <a href="/user/7" class="avatar"><span class="avatarNeue" style="background-image:url('//lain.bgm.tv/pic/user/l/1.jpg')"></span></a>
    <div class="inner">
      <span class="userInfo"><strong><a class="l" href="/user/7">用户B</a></strong></span>
      <div class="reply_content"><div class="message">来了</div></div>
    </div>
  </div>
</div>
''';
      final floors = parseRakuenFloors(html);
      expect(floors.single.time, '3小时前');
      expect(floors.single.source, 'Bangumi for android');
    });
  });

  group('rakueHtmlUrl', () {
    test('空 type 无 query', () {
      expect(rakueHtmlUrl('topiclist', ''), 'https://bgm.tv/rakuen/topiclist');
    });
    test('简单 type', () {
      expect(
        rakueHtmlUrl('topiclist', 'group'),
        'https://bgm.tv/rakuen/topiclist?type=group',
      );
    });
    test('带 filter 的 type', () {
      expect(
        rakueHtmlUrl('topiclist', 'my_group&filter=topic'),
        'https://bgm.tv/rakuen/topiclist?type=my_group&filter=topic',
      );
    });
  });
}
