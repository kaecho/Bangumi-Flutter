import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/utils/display.dart';
import '../../../design_system/design_system.dart';

/// 年度评选横幅 (移植自原项目 discovery/index component/award)
class AwardBanner extends StatefulWidget {
  const AwardBanner({super.key});

  @override
  State<AwardBanner> createState() => _AwardBannerState();
}

class _AwardBannerState extends State<AwardBanner> {
  bool _scrolled = false;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (!_scrolled &&
            n is ScrollUpdateNotification &&
            n.metrics.pixels >= 20) {
          setState(() => _scrolled = true);
        }
        return false;
      },
      child: SizedBox(
        height: _kAwardHeight + 20,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 12, 0, 8),
          children: [
            const _Award2025Card(),
            const _Award2024Card(),
            const _Award2023Card(),
            if (_scrolled) const _AwardMoreCard(),
          ],
        ),
      ),
    );
  }
}

const _kAwardHeight = 128.0;
const _kAwardWide = 272.0;
const _kAward2025Messages = [
  'open /award/2025',
  'cat /var/log/award_2025.log',
  'ls channels',
  'whoami',
  'rank anime',
  'stats user',
  'rm -rf /',
];

class _Award2025Card extends ConsumerStatefulWidget {
  const _Award2025Card();

  @override
  ConsumerState<_Award2025Card> createState() => _Award2025CardState();
}

class _Award2025CardState extends ConsumerState<_Award2025Card>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursor;
  Timer? _tick;
  var _index = 0;
  var _hold = 0;
  var _cursorAt = 0;
  var _text = '';
  late String _target;

  @override
  void initState() {
    super.initState();
    _target = _kAward2025Messages.first;
    _cursor = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..repeat(reverse: true);
    _schedule(220);
  }

  void _schedule(int ms) {
    _tick?.cancel();
    _tick = Timer(Duration(milliseconds: ms), _onTick);
  }

  void _nextText() {
    var next = _kAward2025Messages[_index];
    if (_kAward2025Messages.length > 1 && next == _target) {
      _index = (_index + 1) % _kAward2025Messages.length;
      next = _kAward2025Messages[_index];
    }
    _target = next;
    _index = (_index + 1) % _kAward2025Messages.length;
    _cursorAt = 0;
    _hold = 0;
  }

  void _onTick() {
    if (!mounted) return;
    if (_cursorAt < _target.length) {
      _cursorAt += 1;
      setState(() => _text = _target.substring(0, _cursorAt));
      _schedule(90);
      return;
    }
    _hold += 1;
    if (_hold < 25) {
      _schedule(200);
      return;
    }
    setState(() => _text = '');
    _nextText();
    _schedule(220);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _cursor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final prompt = user == null
        ? 'guest'
        : (user.username.isEmpty ? '${user.id}' : user.username);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: _kAwardWide,
        height: _kAwardHeight,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => context.push('/award/2025'),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF743C45), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF14131A),
                            Color(0xFF0F1318),
                            Color(0xFF0B1115),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 35,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xEB542431), Color(0xBF3D1B24)],
                            ),
                            border: Border(
                              bottom: BorderSide(color: Color(0xFF743C45)),
                            ),
                          ),
                          child: const Text(
                            r'^_ // Bangumi 2025',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Color(0xFFFFE5EC),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0x4D08120D),
                                      Color(0x6B050C09),
                                    ],
                                  ),
                                ),
                              ),
                              const CustomPaint(
                                painter: _AwardDotPainter(),
                                size: Size.infinite,
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  8,
                                  16,
                                  8,
                                ),
                                child: DefaultTextStyle(
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    height: 1.45,
                                    letterSpacing: -0.1,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        r'$ boot award_2025 --mode console',
                                        style: TextStyle(
                                          color: Color(0xFFD99AA8),
                                        ),
                                      ),
                                      const Text(
                                        'SYSTEM READY.',
                                        style: TextStyle(
                                          color: Color(0xFFFFB5C7),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              '$prompt@bgm2025:~\$',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFFFF9FB6),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _text,
                                            style: const TextStyle(
                                              color: Color(0xFFFFEEF3),
                                            ),
                                          ),
                                          FadeTransition(
                                            opacity: _cursor,
                                            child: Container(
                                              width: 7,
                                              height: 12,
                                              margin: const EdgeInsets.only(
                                                left: 2,
                                              ),
                                              color: const Color(0xFFF09199),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => openExternalUrl('$kHost/award/2025/winner'),
                child: const _AwardTba(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AwardDotPainter extends CustomPainter {
  const _AwardDotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x33F09199);
    for (var y = 6.0; y < size.height; y += 16) {
      for (var x = 6.0; x < size.width; x += 16) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Award2024Card extends StatelessWidget {
  const _Award2024Card();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: _kAwardWide,
        height: _kAwardHeight,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => context.push('/award/2024'),
              child: ColoredBox(
                color: Colors.black,
                child: Image.asset(
                  'assets/images/static/2024.png',
                  width: _kAwardWide,
                  height: _kAwardHeight,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => openExternalUrl('$kHost/award/2024/winner'),
                child: const _AwardTba(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Award2023Card extends StatelessWidget {
  const _Award2023Card();

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final border = ds.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => context.push('/award/2023'),
        child: Container(
          width: _kAwardWide,
          height: _kAwardHeight,
          decoration: BoxDecoration(
            color: ds.surfaceCard,
            border: Border(
              top: BorderSide(color: border, width: 2),
              right: BorderSide(color: border, width: 4),
              bottom: BorderSide(color: border, width: 4),
              left: BorderSide(color: border, width: 2),
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 30,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        for (var i = 0; i < 5; i++)
                          Container(
                            height: 2,
                            margin: const EdgeInsets.only(
                              top: 2,
                              left: 6,
                              right: 6,
                            ),
                            color: border,
                          ),
                      ],
                    ),
                    Positioned(
                      left: 18,
                      top: 3,
                      child: Container(
                        width: 22,
                        height: 22,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: border,
                          border: Border.all(color: ds.surfaceCard, width: 2),
                        ),
                        child: ColoredBox(color: ds.surfaceCard),
                      ),
                    ),
                    Align(
                      child: ColoredBox(
                        color: ds.surfaceCard,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'BGM.TV',
                            style: ds.caption.copyWith(
                              color: ds.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'bOS 23',
                      style: ds.title.copyWith(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'YEAR IN REVIEW 2023',
                      style: ds.caption.copyWith(
                        color: ds.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AwardMoreCard extends StatelessWidget {
  const _AwardMoreCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => context.push('/yearbook'),
        child: Container(
          width: _kAwardHeight,
          height: _kAwardHeight,
          color: const Color(0xFF2A2A2A),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '更多',
                style: context.ds.bodyStrong.copyWith(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              Text(
                '年鉴',
                style: context.ds.bodyStrong.copyWith(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AwardTba extends StatelessWidget {
  const _AwardTba();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'TBA',
        style: TextStyle(
          color: Color(0x66FFFFFF),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
