import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/cache.dart';
import '../../../core/utils/display.dart';
import '../../../design_system/design_system.dart';

/// 回复目标 (对齐原项目 showFixedTextarea)
class ReplyTarget {
  final String userName;
  final String messageHtml;
  final String replySub;

  const ReplyTarget({
    this.userName = '',
    this.messageHtml = '',
    this.replySub = '',
  });

  bool get isSub => replySub.isNotEmpty;
}

/// BBCode 插入 (对齐原项目 insertBBCode)
({String value, int cursor}) insertBbcode(
  String text,
  TextSelection selection,
  String template,
) {
  final start = selection.start.clamp(0, text.length);
  final end = selection.end.clamp(0, text.length);
  final left = text.substring(0, start);
  final selected = start < end ? text.substring(start, end) : '';
  final right = text.substring(end);
  final pos = template.indexOf(r'$TEXT$');
  final replaced = template.replaceFirst(r'$TEXT$', selected);
  final value = '$left$replaced$right';
  final cursor = pos < 0
      ? left.length + replaced.length
      : left.length + pos + selected.length;
  return (value: value, cursor: cursor);
}

const kBbcodeTemplates = <String, String>{
  'b': r'[b]$TEXT$[/b]',
  'i': r'[i]$TEXT$[/i]',
  'u': r'[u]$TEXT$[/u]',
  's': r'[s]$TEXT$[/s]',
  'mask': r'[mask]$TEXT$[/mask]',
  'url': r'[url=]$TEXT$[/url]',
  'img': r'[img]$TEXT$[/img]',
  'quote': r'[quote]$TEXT$[/quote]',
};

const kReplyMarks = ['+1', 'mark', '(bgm38)'];

/// 常用 TV 颜文字 (bgm.tv 接受 (bgmN))
const kBgmTvTokens = [
  '(bgm24)',
  '(bgm25)',
  '(bgm26)',
  '(bgm27)',
  '(bgm28)',
  '(bgm29)',
  '(bgm30)',
  '(bgm31)',
  '(bgm32)',
  '(bgm33)',
  '(bgm34)',
  '(bgm35)',
  '(bgm36)',
  '(bgm37)',
  '(bgm38)',
  '(bgm39)',
  '(bgm40)',
  '(bgm41)',
  '(bgm42)',
  '(bgm43)',
];

const kImageUploadHost = 'https://lsky.ry.mk';

/// 带 BBCode / 表情 / 历史的回复框 (原项目 FixedTextarea)
class FixedTextarea extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final bool sending;
  final bool loggedIn;
  final String hint;
  final ReplyTarget? target;
  final List<Widget> leading;
  final String historyKey;
  final VoidCallback onSend;
  final VoidCallback onLogin;
  final VoidCallback? onClearTarget;

  const FixedTextarea({
    super.key,
    required this.controller,
    required this.sending,
    required this.loggedIn,
    required this.onSend,
    required this.onLogin,
    this.hint = '回复楼主...',
    this.target,
    this.leading = const [],
    this.historyKey = 'reply_history',
    this.onClearTarget,
  });

  @override
  ConsumerState<FixedTextarea> createState() => _FixedTextareaState();
}

class _FixedTextareaState extends ConsumerState<FixedTextarea> {
  bool _expanded = false;
  bool _showBgm = false;
  bool _showHistory = false;
  List<String> _history = const [];

  @override
  void initState() {
    super.initState();
    _history = _readHistory();
    widget.controller.addListener(_onDraft);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onDraft);
    _saveDraft(widget.controller.text);
    super.dispose();
  }

  List<String> _readHistory() {
    final raw = Cache.instance.get('rakuen', widget.historyKey);
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  Future<void> _pushHistory(String text) async {
    final next = [text, ..._history.where((e) => e != text)].take(20).toList();
    _history = next;
    await Cache.instance.put('rakuen', widget.historyKey, next);
  }

  void _onDraft() {
    // 不每键落盘, 离开时再存
  }

  Future<void> _saveDraft(String text) async {
    final t = text.trim();
    if (t.isEmpty) {
      await Cache.instance.remove('rakuen', '${widget.historyKey}_draft');
      return;
    }
    await Cache.instance.put('rakuen', '${widget.historyKey}_draft', t);
  }

  void _insert(String template) {
    final sel = widget.controller.selection;
    final result = insertBbcode(widget.controller.text, sel, template);
    widget.controller.value = TextEditingValue(
      text: result.value,
      selection: TextSelection.collapsed(offset: result.cursor),
    );
    setState(() {});
  }

  void _insertPlain(String token) {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final next = text.replaceRange(start, end, token);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  Future<void> _handleSend() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    await _pushHistory(text);
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!widget.loggedIn) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              ...widget.leading,
              Expanded(
                child: Text(
                  '登录后回复',
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
                ),
              ),
              TextButton(onPressed: widget.onLogin, child: const Text('去登录')),
            ],
          ),
        ),
      );
    }

    final target = widget.target;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (target != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        target.isSub
                            ? '回复 ${target.userName} 的楼层'
                            : '回复 ${target.userName}',
                        style: context.ds.caption.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.onClearTarget != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: '取消引用',
                        onPressed: widget.onClearTarget,
                        icon: const Icon(Icons.close, size: 16),
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                ...widget.leading,
                IconButton(
                  tooltip: '格式',
                  onPressed: () => setState(() {
                    _expanded = !_expanded;
                    if (!_expanded) {
                      _showBgm = false;
                      _showHistory = false;
                    }
                  }),
                  icon: Icon(
                    _expanded ? Icons.keyboard_hide : Icons.add_box_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    minLines: 1,
                    maxLines: _expanded ? 8 : 4,
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.newline,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: widget.sending ? null : _handleSend,
                  icon: widget.sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  tooltip: '发送',
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _ToolChip(label: 'BGM', onTap: () => setState(() {
                    _showBgm = !_showBgm;
                    _showHistory = false;
                  })),
                  _ToolChip(label: '加粗', onTap: () => _insert(kBbcodeTemplates['b']!)),
                  _ToolChip(label: '斜体', onTap: () => _insert(kBbcodeTemplates['i']!)),
                  _ToolChip(label: '下划', onTap: () => _insert(kBbcodeTemplates['u']!)),
                  _ToolChip(label: '删除', onTap: () => _insert(kBbcodeTemplates['s']!)),
                  _ToolChip(label: '剧透', onTap: () => _insert(kBbcodeTemplates['mask']!)),
                  _ToolChip(label: '链接', onTap: () => _insert(kBbcodeTemplates['url']!)),
                  _ToolChip(label: '图片', onTap: () => _insert(kBbcodeTemplates['img']!)),
                  _ToolChip(
                    label: '图床',
                    onTap: () => openExternalUrl(kImageUploadHost),
                  ),
                  _ToolChip(label: '历史', onTap: () => setState(() {
                    _showHistory = !_showHistory;
                    _showBgm = false;
                    _history = _readHistory();
                  })),
                  for (final mark in kReplyMarks)
                    _ToolChip(label: mark, onTap: () => _insertPlain(mark)),
                ],
              ),
              if (_showBgm)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final token in kBgmTvTokens)
                        ActionChip(
                          label: Text(token, style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _insertPlain(token),
                        ),
                    ],
                  ),
                ),
              if (_showHistory)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _history.isEmpty
                      ? Text('还没有历史回复', style: context.ds.caption)
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 160),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _history.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final item = _history[i];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  item,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _insertPlain(item),
                              );
                            },
                          ),
                        ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ToolChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }
}

String quoteReplyContent({
  required String userName,
  required String messageHtml,
  required String content,
}) {
  var stripped = stripQuoteHtml(messageHtml);
  stripped = stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (stripped.length > 120) {
    stripped = '${stripped.substring(0, 120)}…';
  }
  if (stripped.isEmpty) return content;
  return '[quote][b]$userName[/b] 说: $stripped[/quote]\n$content';
}

String stripQuoteHtml(String html) {
  return html
      .replaceAll(
        RegExp(r'<div class="quote">[\s\S]*?</div>', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .trim();
}

({
  String type,
  String topicId,
  String related,
  String subReplyUid,
  String postUid,
})? parseReplySub(String onclick) {
  final m = RegExp(
    r"subReply\(\s*'([^']*)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)",
  ).firstMatch(onclick);
  if (m == null) return null;
  return (
    type: m.group(1) ?? '',
    topicId: m.group(2) ?? '',
    related: m.group(3) ?? '',
    subReplyUid: m.group(5) ?? '',
    postUid: m.group(6) ?? '',
  );
}
