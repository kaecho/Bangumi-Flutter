import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/settings_store.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/mesume.dart';

/// 原版 Empty: 看板娘 + 空文案/到底了/随机吐槽 + 再搜索
class ProgressEmpty extends StatelessWidget {
  final String type;
  final String filter;
  final int length;

  const ProgressEmpty({
    super.key,
    required this.type,
    this.filter = '',
    this.length = 0,
  });

  static const emptyText = {
    'all': '当前没有可管理的条目哦',
    'anime': '当前没有在追的番组哦',
    'book': '当前没有在读的书籍哦',
    'real': '当前没有在追的电视剧哦',
    'game': '当前没有在玩的游戏哦',
  };

  static String searchTypeOf(String type) => switch (type) {
    'book' => '书籍',
    'real' => '三次元',
    'game' => '游戏',
    'all' => '条目',
    _ => '动画',
  };

  @override
  Widget build(BuildContext context) {
    final hasItems = length > 0;
    final speech = SettingsStore.instance.speech;
    final text = hasItems
        ? (speech ? randomMesumeSpeech() : '- 到底了 -')
        : (emptyText[type] ?? '当前没有可管理的条目哦');
    final searchType = searchTypeOf(type);
    return Padding(
      padding: EdgeInsets.only(
        top: hasItems ? 24 : 48,
        left: 24,
        right: 24,
        bottom: 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Mesume(size: 80),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              text,
              style: context.ds.caption.copyWith(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          if (filter.isNotEmpty && length <= 3) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: 120,
              child: BgmButton(
                '前往搜索',
                expand: true,
                type: BgmButtonType.ghost,
                onPressed: () => context.push(
                  '/search?q=${Uri.encodeQueryComponent(filter)}&type=${Uri.encodeQueryComponent(searchType)}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
