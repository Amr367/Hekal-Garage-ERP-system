import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../reports_controller.dart';

/// Tab displaying profitability, margins, and cost-of-goods-sold analysis.
class ProfitReportTab extends ConsumerWidget {
  const ProfitReportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesReportProvider);

    return salesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(
        title: 'خطأ في تحميل تقرير الأرباح',
        message: e.toString(),
        onRetry: () => ref.invalidate(salesReportProvider),
      ),
      data: (data) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── KPI Summary Cards ─────────────────────────────────────────────
          Row(
            children: <Widget>[
              _KpiCard(
                label: 'إجمالي الأرباح (Gross Profit)',
                value: data.formattedGrossProfit,
                icon: Icons.trending_up,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              _KpiCard(
                label: 'المصروفات والرواتب',
                value: data.formattedTotalExpensesAndSalaries,
                icon: Icons.account_balance_outlined,
                color: AppColors.warning,
              ),
              const SizedBox(width: 12),
              _KpiCard(
                label: 'صافي الربح الفعلي (Net Profit)',
                value: data.formattedNetOperatingProfit,
                icon: data.netOperatingProfitPiasters >= 0
                    ? Icons.monetization_on_outlined
                    : Icons.trending_down,
                color: data.netOperatingProfitPiasters >= 0
                    ? AppColors.success
                    : AppColors.danger,
              ),
              const SizedBox(width: 12),
              _KpiCard(
                label: 'هامش صافي الربح %',
                value: data.formattedNetProfitMargin,
                icon: Icons.percent,
                color: AppColors.secondary,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Detailed Income & Profit Analysis Card ────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(Icons.analytics_outlined,
                        color: AppColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'تحليل وتفصيل الإيرادات والمصروفات وصافي الأرباح',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                _AnalysisRow(
                  title: 'إيرادات مبيعات قطع الغيار',
                  amount: data.formattedPartsRevenue,
                  subtitle: 'إجمالي مبيعات القطع والأصناف بالفواتير المعتمدة',
                  icon: Icons.build_circle_outlined,
                ),
                const SizedBox(height: 16),

                _AnalysisRow(
                  title: 'تكلفة قطع الغيار المباعة (سعر الشراء وقت الصرف)',
                  amount: '- ${data.formattedPartsCost}',
                  subtitle: 'محسوبة بدقة وفقاً لتكلفة الصنف المسجلة بقاعدة البيانات',
                  icon: Icons.remove_circle_outline,
                  amountColor: AppColors.danger,
                ),
                const SizedBox(height: 16),

                _AnalysisRow(
                  title: 'إيرادات المصنعيات والخدمات (أجور الصيانة)',
                  amount: '+ ${data.formattedServicesRevenue}',
                  subtitle: 'أتعاب اليد العاملة والخدمات الميكانيكية والكهربائية',
                  icon: Icons.engineering_outlined,
                  amountColor: AppColors.success,
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      'إجمالي ربح التشغيل (Gross Profit):',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      data.formattedGrossProfit,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                _AnalysisRow(
                  title: 'مصروفات المركز العامة والتشغيلية',
                  amount: '- ${data.formattedOperatingExpenses}',
                  subtitle: 'إيجار، فواتير كهرباء ومياه، بوفيه، عدد ومهمات، ونثريات',
                  icon: Icons.receipt_long_outlined,
                  amountColor: AppColors.danger,
                ),
                const SizedBox(height: 16),

                _AnalysisRow(
                  title: 'الرواتب والأجور المنصرفة للموظفين',
                  amount: '- ${data.formattedSalariesPaid}',
                  subtitle: 'إجمالي ما تم صرفه كرواتب ومستحقات للعاملين خلال الفترة',
                  icon: Icons.payments_outlined,
                  amountColor: AppColors.danger,
                ),
                const SizedBox(height: 16),

                _AnalysisRow(
                  title: 'مرتجع مبيعات العملاء (خصم من الإيرادات)',
                  amount: '- ${data.formattedSalesReturns}',
                  subtitle: 'إجمالي ${data.salesReturnsCount} إذن مرتجع مبيعات خلال الفترة',
                  icon: Icons.undo_outlined,
                  amountColor: AppColors.danger,
                ),
                if (data.purchaseReturnsPiasters > 0) ...[
                  const SizedBox(height: 16),
                  _AnalysisRow(
                    title: 'مرتجع مشتريات الموردين (خصم من تكلفة المشتريات)',
                    amount: '+ ${data.formattedPurchaseReturns}',
                    subtitle: 'إجمالي ${data.purchaseReturnsCount} إذن مرتجع مشتريات خلال الفترة',
                    icon: Icons.replay_outlined,
                    amountColor: AppColors.success,
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: (data.netOperatingProfitPiasters >= 0
                            ? AppColors.success
                            : AppColors.danger)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (data.netOperatingProfitPiasters >= 0
                              ? AppColors.success
                              : AppColors.danger)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'صافي الربح التشغيلي الفعلي (Net Operating Profit):',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.netOperatingProfitPiasters >= 0
                                ? 'الأرباح الحقيقية الصافية لمركز الصيانة بعد خصم كافة التكاليف والمصروفات والأجور'
                                : 'تنبيه: عجز مالي / مصروفات المركز والرواتب تتجاوز أرباح التشغيل خلال الفترة',
                            style: TextStyle(
                              fontSize: 12,
                              color: data.netOperatingProfitPiasters >= 0
                                  ? AppColors.success
                                  : AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        data.formattedNetOperatingProfit,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: data.netOperatingProfitPiasters >= 0
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _AnalysisRow extends StatelessWidget {
  const _AnalysisRow({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
    this.amountColor,
  });

  final String title;
  final String amount;
  final String subtitle;
  final IconData icon;
  final Color? amountColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 24, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: amountColor ?? AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
