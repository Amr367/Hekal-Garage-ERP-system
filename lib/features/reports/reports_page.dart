import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_scaffold.dart';

/// Financial and operational reports page placeholder.
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.reportsTitle,
      subtitle: AppStrings.reportsSubtitle,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── Filter Controls Card ──────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.date_range, color: AppColors.primary),
                  const SizedBox(width: 12),
                  const Text(
                    'الفترة الزمنية: الشهر الحالي',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.filter_list),
                    label: const Text(AppStrings.filter),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text(AppStrings.exportExcel),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Report Sections Grid ──────────────────────────────────────────
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double cardWidth = (constraints.maxWidth - 24) / 2;
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: <Widget>[
                  SizedBox(
                    width: cardWidth < 340 ? constraints.maxWidth : cardWidth,
                    child: _ReportCard(
                      title: 'تقرير المبيعات والإيرادات',
                      subtitle: 'مبيعات قطع الغيار والمصنعيات وصافي الدخل اليومي والشهري',
                      icon: Icons.payments_outlined,
                      color: AppColors.success,
                      onTap: () {},
                    ),
                  ),
                  SizedBox(
                    width: cardWidth < 340 ? constraints.maxWidth : cardWidth,
                    child: _ReportCard(
                      title: 'تقرير حركة المخزن والركود',
                      subtitle: 'الأصناف الأكثر حركة، الأصناف الراكدة، وقيمة المخزون الحالي',
                      icon: Icons.inventory_outlined,
                      color: AppColors.primary,
                      onTap: () {},
                    ),
                  ),
                  SizedBox(
                    width: cardWidth < 340 ? constraints.maxWidth : cardWidth,
                    child: _ReportCard(
                      title: 'تقرير حسابات العملاء والديون',
                      subtitle: 'أرصدة العملاء والديون المتأخرة والتحصيلات النقدية والبنكية',
                      icon: Icons.people_outline,
                      color: AppColors.danger,
                      onTap: () {},
                    ),
                  ),
                  SizedBox(
                    width: cardWidth < 340 ? constraints.maxWidth : cardWidth,
                    child: _ReportCard(
                      title: 'تقرير أرباح العمليات وصافي الربح',
                      subtitle: 'تحليل هامش الربح لقطع الغيار ونسب أرباح الصيانة والتكاليف',
                      icon: Icons.account_balance_outlined,
                      color: AppColors.secondary,
                      onTap: () {},
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.border),
            ],
          ),
        ),
      ),
    );
  }
}
