import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../design_system/design_system.dart';

/// 主站 502 / 授权过期轻提示 (原项目 ErrorNotice + LoginNotice)
class SiteNoticeBanner extends ConsumerStatefulWidget {
  const SiteNoticeBanner({super.key});

  @override
  ConsumerState<SiteNoticeBanner> createState() => _SiteNoticeBannerState();
}

class _SiteNoticeBannerState extends ConsumerState<SiteNoticeBanner> {
  bool _hideWebsite = false;
  bool _hideLogin = false;

  @override
  Widget build(BuildContext context) {
    final websiteError = ref.watch(websiteErrorProvider);
    final outdate = ref.watch(authOutdateProvider);
    if (websiteError && !_hideWebsite) {
      return _NoticeBar(
        text: '检测到主站通信错误 (bgm.tv | 502: Bad gateway)',
        onClose: () => setState(() => _hideWebsite = true),
      );
    }
    if (outdate && !_hideLogin) {
      return _NoticeBar(
        text: '检测到授权信息过期，点击登录，或者下拉刷新试试',
        onTap: () => context.push('/login'),
        onClose: () => setState(() => _hideLogin = true),
      );
    }
    return const SizedBox.shrink();
  }
}

class _NoticeBar extends StatelessWidget {
  final String text;
  final VoidCallback onClose;
  final VoidCallback? onTap;

  const _NoticeBar({required this.text, required this.onClose, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.ds.accentSoft,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Text(text, style: context.ds.caption),
                ),
              ),
              IconButton(
                tooltip: '关闭',
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
