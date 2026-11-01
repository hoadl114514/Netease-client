import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_theme.dart';

/// 用户头像。没有头像图时显示昵称首字。
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
      child: Text(
        MockData.userName.characters.first,
        style: TextStyle(
          fontSize: size * 0.48,
          fontWeight: FontWeight.w800,
          color: AppColors.onAccent,
          height: 1,
        ),
      ),
    );
  }
}
