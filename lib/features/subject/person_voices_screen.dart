import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/utils/display.dart';
import '../../design_system/design_system.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';
import 'subject_models.dart';
import 'subject_notes.dart';
import 'subject_providers.dart';

/// Extra 人物角色 HeaderV2: `{name}的角色 (N)` / 角色 + 浏览器查看
/// 路由: /mono/person/:id/voices
class PersonVoicesScreen extends ConsumerStatefulWidget {
  final int id;
  final String? name;

  const PersonVoicesScreen({super.key, required this.id, this.name});

  @override
  ConsumerState<PersonVoicesScreen> createState() => _PersonVoicesScreenState();
}

class _PersonVoicesScreenState extends ConsumerState<PersonVoicesScreen> {
  String _position = '';
  String _status = '全部';
  String _outerOrder = '';
  String _innerOrder = '';

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final page = ref.watch(personVoicesProvider((id: id, position: _position)));
    final name =
        widget.name ??
        ref
            .watch(monoDetailProvider((type: 'person', id: id)))
            .valueOrNull
            ?.displayName;
    final loggedIn = ref.watch(isLoggedInProvider);
    return Scaffold(
      appBar: BgmAppBar(
        title: voicesTitle(name, page.valueOrNull?.list.length),
        showBackButton: true,
        actions: [
          BgmHeaderMore.browser(
            () => openExternalUrl(htmlMonoVoices(id, position: _position)),
          ),
        ],
      ),
      body: page.when(
        loading: () => const Loading(text: '加载中...'),
        error: (e, _) => BgmRetry(
          onRetry: () => ref.invalidate(
            personVoicesProvider((id: id, position: _position)),
          ),
        ),
        data: (value) {
          final collected = <int>{};
          if (loggedIn) {
            for (final item in value.list) {
              for (final s in item.subjects) {
                if (ref.watch(collectionProvider(s.id)).valueOrNull != null) {
                  collected.add(s.id);
                }
              }
            }
          }
          final visible = filterMonoVoices(
            sortMonoVoices(
              value.list,
              outerOrder: _outerOrder,
              innerOrder: _innerOrder,
            ),
            loggedIn ? _status : '全部',
            collected,
          );
          return Column(
            children: [
              _VoicesToolBar(
                filters: value.filters,
                position: _position,
                status: _status,
                outerOrder: _outerOrder,
                innerOrder: _innerOrder,
                showStatus: loggedIn,
                onPosition: (v) => setState(() => _position = v),
                onStatus: (v) => setState(() => _status = v),
                onOuter: (v) => setState(() => _outerOrder = v),
                onInner: (v) => setState(() => _innerOrder = v),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const Empty(text: '暂无角色')
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: visible.length,
                        itemBuilder: (context, index) =>
                            _VoiceRow(item: visible[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VoicesToolBar extends StatelessWidget {
  final List<MonoVoiceFilter> filters;
  final String position;
  final String status;
  final String outerOrder;
  final String innerOrder;
  final bool showStatus;
  final ValueChanged<String> onPosition;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onOuter;
  final ValueChanged<String> onInner;

  const _VoicesToolBar({
    required this.filters,
    required this.position,
    required this.status,
    required this.outerOrder,
    required this.innerOrder,
    required this.showStatus,
    required this.onPosition,
    required this.onStatus,
    required this.onOuter,
    required this.onInner,
  });

  @override
  Widget build(BuildContext context) {
    String labelOf(
      List<(String, String)> items,
      String value,
      String fallback,
    ) {
      for (final item in items) {
        if (item.$1 == value) return item.$2;
      }
      return fallback;
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _VoicePill(
            label: labelOf(kVoicesOuterOrders, outerOrder, '外层排序') == '默认'
                ? '外层排序'
                : labelOf(kVoicesOuterOrders, outerOrder, '外层排序'),
            options: [for (final e in kVoicesOuterOrders) e.$2],
            selected: labelOf(kVoicesOuterOrders, outerOrder, '默认'),
            onSelected: (label) {
              for (final e in kVoicesOuterOrders) {
                if (e.$2 == label) onOuter(e.$1);
              }
            },
          ),
          const SizedBox(width: 8),
          _VoicePill(
            label: labelOf(kVoicesInnerOrders, innerOrder, '内层排序') == '默认'
                ? '内层排序'
                : labelOf(kVoicesInnerOrders, innerOrder, '内层排序'),
            options: [for (final e in kVoicesInnerOrders) e.$2],
            selected: labelOf(kVoicesInnerOrders, innerOrder, '默认'),
            onSelected: (label) {
              for (final e in kVoicesInnerOrders) {
                if (e.$2 == label) onInner(e.$1);
              }
            },
          ),
          for (final filter in filters) ...[
            const SizedBox(width: 8),
            _VoicePill(
              label: () {
                for (final o in filter.options) {
                  if (o.$1 == position) return o.$2;
                }
                return filter.title;
              }(),
              options: [for (final o in filter.options) o.$2],
              selected: () {
                for (final o in filter.options) {
                  if (o.$1 == position) return o.$2;
                }
                return '全部';
              }(),
              onSelected: (label) {
                for (final o in filter.options) {
                  if (o.$2 == label) onPosition(o.$1);
                }
              },
            ),
          ],
          if (showStatus) ...[
            const SizedBox(width: 8),
            _VoicePill(
              label: status == '全部' ? '状态' : status,
              options: kVoicesStatus,
              selected: status,
              onSelected: onStatus,
            ),
          ],
        ],
      ),
    );
  }
}

class _VoicePill extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _VoicePill({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return PopupMenuButton<String>(
      tooltip: label,
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final option in options)
          PopupMenuItem(
            value: option,
            child: Text(
              option,
              style: TextStyle(
                fontWeight: option == selected
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: ds.surfaceCard.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Center(
          child: Text(
            label,
            style: ds.caption.copyWith(
              color: ds.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceRow extends StatelessWidget {
  final MonoVoiceItem item;

  const _VoiceRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => context.push('/mono/character/${item.id}'),
            child: Cover(url: item.cover, width: 52, height: 52, radius: 26),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () => context.push('/mono/character/${item.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.name.isNotEmpty && item.name != item.displayName)
                    Text(item.name, style: context.ds.tiny),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                for (var i = 0; i < item.subjects.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _VoiceSubjectRow(subject: item.subjects[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceSubjectRow extends StatelessWidget {
  final MonoVoiceSubject subject;

  const _VoiceSubjectRow({required this.subject});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/subject/${subject.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subject.name.isNotEmpty &&
                    subject.name != subject.displayName)
                  Text(subject.name, style: context.ds.tiny),
                if (subject.staff.isNotEmpty || subject.tip.isNotEmpty)
                  Text(
                    [
                      subject.staff,
                      subject.tip,
                    ].where((e) => e.isNotEmpty).join(' · '),
                    style: context.ds.tiny,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Cover(url: subject.cover, width: 40, height: 56, radius: 4),
        ],
      ),
    );
  }
}
