import 'package:flutter/material.dart';

import 'tinygrail_widgets.dart';

/// 新股申购 (ICO): 最多资金/最高人气/即将结束/最近活跃
class TinygrailIcoScreen extends StatelessWidget {
  const TinygrailIcoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TinygrailCharaListScreen(
      title: '新股申购',
      tabs: [
        ('最多资金', 'mvi'),
        ('最高人气', 'mpi'),
        ('即将结束', 'mri'),
        ('最近活跃', 'rai'),
      ],
      itemBuilder: null,
    );
  }
}
