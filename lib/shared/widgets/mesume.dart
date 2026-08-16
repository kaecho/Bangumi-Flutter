import 'dart:math';

import 'package:flutter/material.dart';

import 'mesume_speech.dart';

/// 原版 Mesume 看板娘图 1-7
const kMesumeAssets = [
  'assets/images/musume/musume1.png',
  'assets/images/musume/musume2.png',
  'assets/images/musume/musume3.png',
  'assets/images/musume/musume4.png',
  'assets/images/musume/musume5.png',
  'assets/images/musume/musume6.png',
  'assets/images/musume/musume7.png',
];

String randomMesumeSpeech([Random? random]) {
  final rng = random ?? Random();
  return kMesumeSpeeches[rng.nextInt(kMesumeSpeeches.length)];
}

/// 原版 Mesume: 随机 musume1-7, contain
class Mesume extends StatelessWidget {
  final double size;
  final int? index;

  const Mesume({super.key, this.size = 80, this.index});

  @override
  Widget build(BuildContext context) {
    final pick = ((index ?? Random().nextInt(7)) % 7).abs();
    return Image.asset(
      kMesumeAssets[pick],
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
