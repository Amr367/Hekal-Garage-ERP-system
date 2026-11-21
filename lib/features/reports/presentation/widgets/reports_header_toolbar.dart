import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/report_date_range.dart';
import '../reports_controller.dart';

/// Top toolbar for selecting report periods and exporting to Excel.
class ReportsHeaderToolbar extends ConsumerWidget {
  const ReportsHeaderToolbar({super.key});

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final current = ref.read(reportDateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: current.start, end: current.end),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'اختر الفترة الزمنية للتقرير',
      saveText: 'تطبيق',
    );

    if (picked != null) {
      ref
          .read(reportDateRangeProvider.notifier)
          .setCustomRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRange = ref.watch(reportDateRangeProvider);
    final activeTab = ref.watch(reportsSelectedTabProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              const Icon(Icons.date_range, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                'الفترة الزمنية:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(width: 8),

              // Segmented preset picker
              SegmentedButton<DateRangePreset>(
                segments: const <ButtonSegment<DateRangePreset>>[
                  ButtonSegment(
                    value: DateRangePreset.today,
                    label: Text('اليوم'),
                  ),
                  ButtonSegment(
                    value: DateRangePreset.thisWeek,
                    label: Text('هذا الأسبوع'),
                  ),
                  ButtonSegment(
                    value: DateRangePreset.thisMonth,
                    label: Text('هذا الشهر'),
                  ),
                  ButtonSegment(
                    value: DateRangePreset.lastMonth,
                    label: Text('الشهر السابق'),
                  ),
                  ButtonSegment(
                    value: DateRangePreset.thisYear,
                    label: Text('السنة الحالية'),
                  ),
                ],
                selected: {
                  if (activeRange.preset != DateRangePreset.custom)
                    activeRange.preset
                },
                emptySelectionAllowed: true,
                onSelectionChanged: (val) {
                  if (val.isNotEmpty) {
                    ref
                        .read(reportDateRangeProvider.notifier)
                        .setPreset(val.first);
                  }
                },
              ),

              const SizedBox(width: 8),

              // Custom range picker button
              OutlinedButton.icon(
                onPressed: () => _pickCustomRange(context, ref),
                icon: const Icon(Icons.calendar_month, size: 16),
                label: Text(
                  activeRange.preset == DateRangePreset.custom
                      ? activeRange.label
                      : 'فترة مخصصة...',
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: activeRange.preset == DateRangePreset.custom
                      ? AppColors.primaryContainer
                      : null,
                ),
              ),

              const SizedBox(width: 16),

              // Export Comprehensive Financial Report Button (كافة الحسابات في ملف واحد)
              ElevatedButton.icon(
                onPressed: () {
                  ref
                      .read(reportsActionsProvider)
                      .exportComprehensiveFinancialReport(context);
                },
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text(AppStrings.exportComprehensiveFinancialReport),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),

              const SizedBox(width: 8),

              // Export Current Tab Excel Button
              OutlinedButton.icon(
                onPressed: () {
                  final actions = ref.read(reportsActionsProvider);
                  switch (activeTab) {
                    case 0:
                      actions.exportSalesReport(context);
                      break;
                    case 1:
                      actions.exportProfitReport(context);
                      break;
                    case 2:
                      actions.exportInventoryReport(context);
                      break;
                    case 3:
                      actions.exportDebtsReport(context);
                      break;
                  }
                },
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text(AppStrings.exportExcel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
