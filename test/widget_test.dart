import 'package:flutter_test/flutter_test.dart';

import 'package:bangumi/shared/models/collection.dart';
import 'package:bangumi/shared/models/subject.dart';

void main() {
  test('Subject.fromJson 解析条目字段', () {
    final subject = Subject.fromJson({
      'id': 123,
      'name': 'Test',
      'name_cn': '测试',
      'type': 'anime',
      'images': {'common': '//lain.bgm.tv/pic/cover/m/123.jpg'},
      'rating': {'total': 100, 'score': 8.5, 'count': {'10': 50, '9': 50}},
      'collection': {'wish': 10, 'collect': 20, 'doing': 30, 'on_hold': 4, 'dropped': 5},
    });

    expect(subject.id, 123);
    expect(subject.displayName, '测试');
    expect(subject.rating?.score, 8.5);
    expect(subject.collection?.total, 69);
    expect(subject.images.common, 'https://lain.bgm.tv/pic/cover/m/123.jpg');
  });

  test('CollectionItem.fromJson 解析收藏字段', () {
    final item = CollectionItem.fromJson({
      'subject_id': 456,
      'subject_type': 'anime',
      'rate': 9,
      'type': 3,
      'ep_status': 12,
      'subject': {
        'id': 456,
        'name': 'Anime',
        'images': {'common': ''},
      },
    });

    expect(item.type, 3);
    expect(item.epStatus, 12);
    expect(item.subject.id, 456);
    expect(CollectionStatus.text(item.type), '在看');
  });

  test('CollectionStatus 文案', () {
    expect(CollectionStatus.text(1), '想看');
    expect(CollectionStatus.text(2), '看过');
    expect(CollectionStatus.text(3), '在看');
    expect(CollectionStatus.text(4), '搁置');
    expect(CollectionStatus.text(5), '抛弃');
  });
}
