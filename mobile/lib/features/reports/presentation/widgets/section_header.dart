import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_components.dart';
import '../../../../shared/widgets/premium_ui.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return PremiumSectionHeading(
      title: title,
      trailing: subtitle == null
          ? null
          : AppStatusPill(
              label: subtitle!,
              variant: AppPillVariant.brand,
              dense: true,
            ),
    );
  }
}
