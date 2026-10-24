import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../settings/data/pin_auth_service.dart';
import '../../../settings/presentation/settings_controller.dart';
import '../../domain/inventory_summary.dart';
import '../inventory_controller.dart';

/// Row of 4 KPI cards displayed at the top of the inventory page.
class InventoryKpiCards extends ConsumerWidget {
  const InventoryKpiCards({
    super.key,
    required this.summary,
  });

  final InventorySummary summary;

  Future<void> _handleRevealCost(BuildContext context, WidgetRef ref) async {
    final authService = ref.read(pinAuthServiceProvider);
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final requirePin = await settingsRepo.getBool(PinAuthService.keyRequireCostPrice, true);

    if (requirePin) {
      if (!context.mounted) return;
      final authorized = await authService.checkPermission(
        context,
        prompt: 'أدخل رمز PIN لكشف أسعار التكلفة وقيم المخزون',
      );
      if (authorized) {
        ref.read(inventoryCostPriceRevealedProvider.notifier).reveal();
      }
    } else {
      ref.read(inventoryCostPriceRevealedProvider.notifier).toggle();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final costRevealed = ref.watch(inventoryCostPriceRevealedProvider);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cardWidth = (constraints.maxWidth - (3 * 16)) / 4;
        final bool wrapCards = cardWidth < 220;

        final List<Widget> cards = <Widget>[
          _KpiCard(
            title: AppStrings.totalItemsCountLabel,
            value: '${summary.totalItemsCount} صنف',
            icon: Icons.inventory_2_outlined,
            color: AppColors.primary,
            containerColor: AppColors.primaryContainer,
          ),
          _KpiCard(
            title: AppStrings.lowStockWarning,
            value: summary.lowStockCount > 0 || summary.outOfStockCount > 0
                ? '${summary.lowStockCount} ناقص / ${summary.outOfStockCount} نافد'
                : 'الرصيد كافٍ لكافة الأصناف',
            icon: Icons.warning_amber_rounded,
            color: summary.lowStockCount > 0 || summary.outOfStockCount > 0
                ? AppColors.warning
                : AppColors.success,
            containerColor: summary.lowStockCount > 0 || summary.outOfStockCount > 0
                ? AppColors.warningContainer
                : AppColors.successContainer,
          ),
          _KpiCard(
            title: AppStrings.stockValueCostLabel,
            value: costRevealed ? summary.formattedTotalCostValue : AppStrings.costPriceHidden,
            icon: Icons.monetization_on_outlined,
            color: AppColors.info,
            containerColor: AppColors.info.withValues(alpha: 0.12),
            trailing: IconButton(
              icon: Icon(
                costRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              tooltip: costRevealed ? 'إخفاء سعر التكلفة' : AppStrings.revealCostPriceTooltip,
              onPressed: () {
                if (costRevealed) {
                  ref.read(inventoryCostPriceRevealedProvider.notifier).hide();
                } else {
                  _handleRevealCost(context, ref);
                }
              },
            ),
          ),
          _KpiCard(
            title: AppStrings.stockValueSaleLabel,
            value: summary.formattedTotalSaleValue,
            subtitle: costRevealed ? 'ربح متوقع: ${summary.formattedPotentialProfit}' : null,
            icon: Icons.trending_up_rounded,
            color: AppColors.success,
            containerColor: AppColors.successContainer,
          ),
        ];

        if (wrapCards) {
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: cards
                .map((Widget c) => SizedBox(width: (constraints.maxWidth - 16) / 2, child: c))
                .toList(),
          );
        }

        return Row(
          children: cards
              .map((Widget c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: c,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.containerColor,
    this.trailing,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Color containerColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
