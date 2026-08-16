import 'package:flutter/material.dart';
import '../../core/utils/display.dart';

import '../../design_system/design_system.dart';
import 'wiki_data.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/app_bar.dart';

/// 游戏指南 (移植自原项目 screens/tinygrail/wiki)
///
/// 纯本地文本渲染: 11 章硬编码内容 + Drawer 目录锚点跳转, 无网络请求。
/// 行格式约定见 wiki_data.dart 头部注释。
class TinygrailWikiScreen extends StatelessWidget {
  const TinygrailWikiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BgmAppBar(
        title: '小圣杯游戏指南',
        actions: [
          Builder(
            builder: (context) => BgmHeaderAction(
              icon: const Icon(Icons.menu),
              tooltip: '目录',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: const _WikiDrawer(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppGap.x7,
          AppGap.x6,
          AppGap.x7,
          AppGap.x10,
        ),
        children: [
          for (final chapter in kWikiData) _ChapterSection(chapter: chapter),
        ],
      ),
    );
  }
}

class _ChapterSection extends StatelessWidget {
  final WikiChapter chapter;

  const _ChapterSection({required this.chapter});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Anchor(
          id: chapter.title,
          child: Padding(
            padding: const EdgeInsets.only(top: AppGap.x5, bottom: AppGap.x3),
            child: Text(
              chapter.title,
              style: context.ds.title.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        for (final line in chapter.message)
          if (_isHeading(line))
            _Anchor(
              id: '${chapter.title}::$line',
              child: _WikiLine(line: line),
            )
          else
            _WikiLine(line: line),
        const BgmHairline(height: 24),
      ],
    );
  }

  static bool _isHeading(String line) => RegExp(r'^\d\.\d?').hasMatch(line);
}

/// 单行渲染: 大标题 / 小标题 / 外链 / 正文
class _WikiLine extends StatelessWidget {
  final String line;

  const _WikiLine({required this.line});

  static final _h1 = RegExp(r'^\d\.(?!\d)');
  static final _h2 = RegExp(r'^\d\.\d');
  static final _url = RegExp(r'^url=(.+?),(https?://.+)$');

  @override
  Widget build(BuildContext context) {
    if (line.isEmpty) return const SizedBox(height: 4);

    final urlMatch = _url.firstMatch(line);
    if (urlMatch != null) {
      final name = urlMatch.group(1)!;
      final url = urlMatch.group(2)!;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: InkWell(
          onTap: () => openExternalUrl(url),

          child: Text(
            name,
            style: context.ds.body.copyWith(
              color: context.ds.accent,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );
    }

    final isH1 = _h1.hasMatch(line);
    final isH2 = _h2.hasMatch(line);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        line,
        style: isH1
            ? context.ds.bodyStrong.copyWith(fontSize: 16)
            : isH2
            ? context.ds.bodyStrong
            : context.ds.body,
      ),
    );
  }
}

/// 目录 Drawer: 章节 + 章内大/小标题, 点击平滑滚动
class _WikiDrawer extends StatelessWidget {
  const _WikiDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppGap.x7,
                AppGap.x6,
                AppGap.x7,
                AppGap.x3,
              ),
              child: Text('目录', style: context.ds.section),
            ),
            for (final chapter in kWikiData) ...[
              BgmActionRow(
                title: chapter.title,
                onTap: () => _scrollTo(context, chapter.title),
              ),
              for (final line in chapter.message)
                if (_ChapterSection._isHeading(line))
                  BgmActionRow(
                    title: line,
                    onTap: () =>
                        _scrollTo(context, _anchorId(chapter.title, line)),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  static String _anchorId(String chapter, String line) => '$chapter::$line';

  static void _scrollTo(BuildContext context, String id) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _Anchor.registry[id];
      if (target?.currentContext == null) return;
      Scrollable.ensureVisible(
        target!.currentContext!,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }
}

/// 锚点注册表: id -> GlobalKey, 供目录跳转
class _Anchor extends StatelessWidget {
  static final Map<String, GlobalKey> registry = {};

  final String id;
  final Widget child;

  const _Anchor({required this.id, required this.child});

  @override
  Widget build(BuildContext context) {
    final key = registry.putIfAbsent(id, GlobalKey.new);
    return KeyedSubtree(key: key, child: child);
  }
}
