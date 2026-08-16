import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../design_system/design_system.dart';

import '../../core/html/bgm_html_parser.dart';
import '../../core/utils/display.dart';
import '../../shared/widgets/app_bar.dart';
import '../../shared/widgets/bgm_button.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/loading.dart';

/// 个人设置 (原版 Header Check: 还原 + 保存)
class UserSettingScreen extends ConsumerStatefulWidget {
  const UserSettingScreen({super.key});

  @override
  ConsumerState<UserSettingScreen> createState() => _UserSettingScreenState();
}

class _UserSettingScreenState extends ConsumerState<UserSettingScreen> {
  final _nickname = TextEditingController();
  final _signInput = TextEditingController();
  final _avatar = TextEditingController();
  final _bg = TextEditingController();

  UserSettingForm _form = const UserSettingForm();
  bool _loaded = false;
  bool _busy = false;
  bool _expand = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _nickname.dispose();
    _signInput.dispose();
    _avatar.dispose();
    _bg.dispose();
    super.dispose();
  }

  Future<void> _reload({bool resume = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final html = await ref
          .read(apiClientProvider)
          .fetchHtml(htmlUserSetting());
      if (htmlRequiresLogin(html)) {
        if (!mounted) return;
        setState(() {
          _loaded = true;
          _busy = false;
          _error = '需要站点 Cookie 登录';
        });
        return;
      }
      final form = parseUserSetting(html);
      _nickname.text = form.nickname;
      _signInput.text = form.signInput;
      _avatar.text = extractSignTag(form.sign, avatar: true);
      _bg.text = extractSignTag(form.sign, avatar: false);
      if (!mounted) return;
      setState(() {
        _form = form;
        _loaded = true;
        _busy = false;
      });
      if (resume && mounted) showBgmToast(context, '已还原');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _busy = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  Future<void> _save() async {
    if (_form.formhash.isEmpty) {
      showBgmToast(context, '保存需要站点 Cookie 登录');
      return;
    }
    setState(() => _busy = true);
    try {
      final built = buildUserSettingSign(
        _form.sign,
        _avatar.text.trim(),
        _bg.text.trim(),
      );
      await ref.read(apiClientProvider).postSiteFields(htmlUserSetting(), {
        'formhash': _form.formhash,
        'nickname': _nickname.text.trim(),
        'sign_input': _signInput.text.trim(),
        'newbio': built.newbio,
        'timeoffsetnew': _form.timeoffsetnew,
        'show_nsfw_subject': _form.showNsfwSubject ? '1' : '0',
        'submit': '保存修改',
      });
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (!mounted) return;
      showBgmToast(context, '保存成功');
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showBgmToast(context, '保存失败: ${apiErrorMessage(e)}');
    }
  }

  Future<void> _showImageTip() async {
    final ok = await showBgmConfirm(
      context,
      title: '提示',
      message: '头像和背景仅在客户端时光机和用户空间中显示。需要输入图片网络地址，是否前往免费图床？',
    );
    if (ok) await openExternalUrl(kImageUploadHost);

  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final previewAvatar = _avatar.text.trim().isEmpty
        ? (me?.avatarUrl ?? '')
        : _avatar.text.trim();
    final previewBg = _bg.text.trim().isEmpty ? previewAvatar : _bg.text.trim();
    return Scaffold(
      appBar: BgmAppBar(
        title: '个人设置',
        actions: [
          BgmHeaderAction(
            tooltip: '还原',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: _busy ? null : () => _reload(resume: true),
          ),
          BgmHeaderAction(
            tooltip: '保存',
            icon: const Icon(Icons.check),
            onPressed: _busy ? null : _save,
          ),
        ],
      ),
      body: me == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('未登录'),
                  const SizedBox(height: 12),
                  BgmButton(
                    '登录',
                    expand: false,
                    onPressed: () => context.push('/login'),
                  ),
                ],
              ),
            )
          : !_loaded
          ? const Loading()
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _UserSettingPreview(
                  bg: previewBg,
                  avatar: previewAvatar,
                  name: me.displayName,
                  userId: me.username.isEmpty ? '${me.id}' : me.username,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(_error!, style: context.ds.caption),
                  ),
                if (_expand) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      children: [
                        BgmField(
                          controller: _nickname,
                          labelText: '昵称',
                          hintText: '请填入昵称',
                        ),
                        const SizedBox(height: 8),
                        BgmField(
                          controller: _signInput,
                          labelText: '签名',
                          hintText: '请填入签名',
                        ),
                        const SizedBox(height: 8),
                        BgmField(
                          controller: _avatar,
                          labelText: '头像',
                          hintText: '请填入网络地址',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.info_outline, size: 18),
                            onPressed: _showImageTip,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        BgmField(
                          controller: _bg,
                          labelText: '背景',
                          hintText: '请填入网络地址',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.info_outline, size: 18),
                            onPressed: _showImageTip,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
                TextButton(
                  onPressed: () => setState(() => _expand = !_expand),
                  child: Text(_expand ? '收起资料' : '展开资料'),
                ),
                if (!_expand)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '这是一个过时的功能，背景和头像仅在客户端中生效，建议到官方网页中设置。',
                      style: context.ds.caption,
                    ),
                  ),
                const SizedBox(height: 12),
                BgmSettingRow(
                  title: 'Bilibili 同步',
                  subtitle: '将收藏进度同步到 Bilibili',
                  arrow: true,
                  onTap: () => context.push('/sync/bilibili'),
                ),
                BgmSettingRow(
                  title: '豆瓣同步',
                  subtitle: '将收藏进度同步到豆瓣',
                  arrow: true,
                  onTap: () => context.push('/sync/douban'),
                ),
                BgmSettingRow(
                  title: '网页端设置',
                  subtitle: '在浏览器中修改昵称/签名/头像',
                  arrow: true,
                  onTap: () => context.push(
                    '/web/${Uri.encodeComponent(htmlUserSetting())}',
                  ),
                ),
              ],
            ),
    );
  }
}

class _UserSettingPreview extends StatelessWidget {
  final String bg;
  final String avatar;
  final String name;
  final String userId;

  const _UserSettingPreview({
    required this.bg,
    required this.avatar,
    required this.name,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bg.isNotEmpty)
            Positioned.fill(
              child: Cover(
                url: bg,
                width: MediaQuery.sizeOf(context).width,
                height: 168,
              ),
            )
          else
            ColoredBox(color: context.ds.surfaceCard),
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0x59000000)),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Avatar(url: avatar, size: 64, name: name),
              const SizedBox(height: 8),
              Text(
                '$name @$userId',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          Positioned(
            right: 12,
            bottom: 10,
            child: GestureDetector(
              onTap: () => context.push('/user/sukaretto'),
              child: const Text(
                '[示例]',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
