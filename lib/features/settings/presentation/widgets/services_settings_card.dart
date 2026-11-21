import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../services/presentation/widgets/services_manager_dialog.dart';

/// Settings card tab for managing services and labor pricing.
class ServicesSettingsCard extends StatelessWidget {
  const ServicesSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 650,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: const ServicesManagerView(),
    );
  }
}
