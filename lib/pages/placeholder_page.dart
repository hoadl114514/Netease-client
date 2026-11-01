import 'package:flutter/material.dart';

import '../shell/destinations.dart';
import '../theme/app_theme.dart';

/// 还没做的页面。
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(destination.icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(destination.label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text('待开发', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
