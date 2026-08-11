import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/core/html/bgm_html_parser.dart';

void main() {
  group('htmlDecode', () {
    test('反转义实体', () {
      expect(htmlDecode('a&amp;b &lt;c&gt; &quot;d&quot; &nbsp;'), 'a&b <c> "d"  ');
    });
  });

  group('htmlMatch', () {
    test('提取片段 (不含 end 标记, 与原项目一致)', () {
      expect(htmlMatch('xx<div id="a">content</div>yy', '<div id="a">', '</div>'),
          '<div id="a">content');
    });
    test('起点缺失返回空', () {
      expect(htmlMatch('no marker here', '<div id="a">', '</div>'), '');
    });
  });

  group('relativeEnToEpoch', () {
    final loaded = DateTime(2026, 8, 11, 12, 0, 0).millisecondsSinceEpoch;

    test('刚刚', () {
      expect(relativeEnToEpoch('刚刚', loaded), loaded);
    });
    test('N分钟前', () {
      expect(relativeEnToEpoch('5分钟前', loaded), loaded - 5 * 60 * 1000);
    });
    test('N小时前', () {
      expect(relativeEnToEpoch('3小时前', loaded), loaded - 3 * 3600 * 1000);
    });
    test('N天前', () {
      expect(relativeEnToEpoch('2天前', loaded), loaded - 2 * 86400 * 1000);
    });
    test('M月D日', () {
      expect(relativeEnToEpoch('8月10日', loaded),
          DateTime(2026, 8, 10).millisecondsSinceEpoch);
    });
    test('YYYY-M-D', () {
      expect(relativeEnToEpoch('2025-1-1', loaded),
          DateTime(2025, 1, 1).millisecondsSinceEpoch);
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
        <a class="title" href="/group/350677">这是一个测试帖子</a>
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
      expect(item.href, '/group/350677');
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
<div id="comment_list">
  <div class="commentList">
    <div class="row_replyclearit" id="post_123">
      <span class="avatarNeue" style="background-image: url('//lain.bgm.tv/pic/user/l/1.jpg')"></span>
      <a class="l" href="/user/42">用户A</a>
      <span class="sign">签名</span>
      <div class="action"><small>#1 - 5分钟前</small></div>
      <div class="reply_content"><div class="message">楼上说得对 <q>引用</q></div></div>
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
      expect(f.messageHtml, contains('楼上说得对'));
    });
  });
}
