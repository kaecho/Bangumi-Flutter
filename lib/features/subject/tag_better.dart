import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../discovery/typerank_data.dart';

class TypeRankBetterText extends StatelessWidget {
  final String type;
  final String tag;
  final int rank;

  const TypeRankBetterText({
    super.key,
    required this.type,
    required this.tag,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: loadTypeRankBetterPercent(type, tag, rank),
      builder: (context, snap) {
        final percent = snap.data;
        final label = typeRankBetterLabel(percent);
        final hot = percent != null && percent >= 90;
        return Text(
          label,
          style: context.ds.caption.copyWith(
            color: hot ? context.ds.accent : context.ds.textHint,
            fontWeight: FontWeight.w700,
          ),
        );
      },
    );
  }
}
