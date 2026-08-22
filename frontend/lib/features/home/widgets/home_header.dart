// File: lib/features/home/widgets/home_header.dart
// Description: Header widget for the home screen showing selected beach title, region subtitle, and active clock pill.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/settings_providers.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/risk_theme.dart';
import '../../../models/beach.dart';

// Beach name, region and the current-time pill.
class HomeHeader extends ConsumerWidget {

  const HomeHeader({super.key, required this.beach, required this.time});

  final Beach beach;
  final DateTime time;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final risk = RiskTheme.of(context);
    final fmt = ref.watch(formatterProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                beach.name,
                style: AppText.beachTitle.copyWith(color: risk.headerForeground),
              ),
              const SizedBox(height: Insets.xs),
              Text(
                beach.region,
                style: AppText.beachRegion.copyWith(color: risk.onBackdropMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: Insets.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
          child: Text(
            fmt.clock(time),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: risk.headerForeground,
            ),
          ),
        ),
      ],
    );
  }
}
