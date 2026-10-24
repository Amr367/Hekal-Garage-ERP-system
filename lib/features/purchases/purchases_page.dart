import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/search_field.dart';

/// Purchases and suppliers management page placeholder.
class PurchasesPage extends StatelessWidget {
  const PurchasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.purchasesTitle,
      subtitle: AppStrings.purchasesSubtitle,
      actions: <Widget>[
        const SearchField(),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text(AppStrings.newPurchaseButton),
        ),
      ],
      body: AppDataTable<Map<String, dynamic>>(
        columns: <AppTableColumn<Map<String, dynamic>>>[
          AppTableColumn<Map<String, dynamic>>(
            title: 'رقم الفاتورة',
            width: 140,
            cellBuilder: (_, item, index) => Text(item['invoiceNo']?.toString() ?? ''),
          ),
          AppTableColumn<Map<String, dynamic>>(
            title: 'المورد',
            flex: 2,
            cellBuilder: (_, item, index) => Text(item['supplier']?.toString() ?? ''),
          ),
          AppTableColumn<Map<String, dynamic>>(
            title: 'إجمالي الفاتورة',
            width: 150,
            cellBuilder: (_, item, index) => Text(item['total']?.toString() ?? ''),
          ),
          AppTableColumn<Map<String, dynamic>>(
            title: 'المدفوع',
            width: 140,
            cellBuilder: (_, item, index) => Text(item['paid']?.toString() ?? ''),
          ),
          AppTableColumn<Map<String, dynamic>>(
            title: 'المتبقي',
            width: 140,
            cellBuilder: (_, item, index) => Text(item['remaining']?.toString() ?? ''),
          ),
          AppTableColumn<Map<String, dynamic>>(
            title: 'التاريخ',
            width: 130,
            cellBuilder: (_, item, index) => Text(item['date']?.toString() ?? ''),
          ),
        ],
        items: const <Map<String, dynamic>>[],
      ),
    );
  }
}
