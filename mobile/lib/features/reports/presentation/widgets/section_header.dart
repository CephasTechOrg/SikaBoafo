import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../../shared/widgets/mockup_ui.dart';
import '../../../../shared/widgets/premium_ui.dart';
import '../../../dashboard/data/dashboard_api.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../../debts/data/debts_repository.dart';
import '../../../debts/providers/debts_providers.dart';
import '../../../expenses/data/expenses_repository.dart';
import '../../../expenses/providers/expenses_providers.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.subtitle});
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
