import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_scaffold.dart';

/// Stock count management page placeholder.
class StockCountPage extends StatelessWidget {
  const StockCountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.stockCountTitle,
      subtitle: AppStrings.stockCountSubtitle,
      actions: <Widget>[
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text(AppStrings.startStockCountButton),
        ),
      ],
      body: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: <Widget>[
                Icon(Icons.info_outline, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'يتيح نظام الجرد حصر الكميات الفعلية ومقارنتها بالرصيد المسجل في قاعدة البيانات مع تسجيل فروقات العجز أو الزيادة.',
                    style: TextStyle(fontSize: 14, color: AppColors.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AppDataTable<Map<String, dynamic>>(
              columns: <AppTableColumn<Map<String, dynamic>>>[
                AppTableColumn<Map<String, dynamic>>(
                  title: 'كود الجلسة',
                  width: 130,
                  cellBuilder: (_, item, index) => Text(item['sessionCode']?.toString() ?? ''),
                ),
                AppTableColumn<Map<String, dynamic>>(
                  title: 'تاريخ البدء',
                  width: 140,
                  cellBuilder: (_, item, index) => Text(item['startDate']?.toString() ?? ''),
                ),
                AppTableColumn<Map<String, dynamic>>(
                  title: 'الحالة',
                  width: 130,
                  cellBuilder: (_, item, index) => Text(item['status']?.toString() ?? ''),
                ),
                AppTableColumn<Map<String, dynamic>>(
                  title: 'إجمالي الأصناف',
                  width: 130,
                  cellBuilder: (_, item, index) => Text(item['itemsCount']?.toString() ?? ''),
                ),
                AppTableColumn<Map<String, dynamic>>(
                  title: 'قيمة الفروقات',
                  width: 150,
                  cellBuilder: (_, item, index) => Text(item['differenceValue']?.toString() ?? ''),
                ),
                AppTableColumn<Map<String, dynamic>>(
                  title: 'ملاحظات',
                  flex: 2,
                  cellBuilder: (_, item, index) => Text(item['notes']?.toString() ?? ''),
                ),
              ],
              items: const <Map<String, dynamic>>[],
            ),
          ),
        ],
      ),
    );
  }
}
