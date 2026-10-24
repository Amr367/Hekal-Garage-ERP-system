import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/search_field.dart';

/// Invoices management page placeholder.
class InvoicesPage extends StatelessWidget {
  const InvoicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.invoicesTitle,
      subtitle: AppStrings.invoicesSubtitle,
      actions: <Widget>[
        const SearchField(),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text(AppStrings.newInvoiceButton),
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
            title: 'العميل',
            flex: 2,
            cellBuilder: (_, item, index) => Text(item['customer']?.toString() ?? ''),
          ),
          AppTableColumn<Map<String, dynamic>>(
            title: 'النوع',
            width: 120,
            cellBuilder: (_, item, index) => Text(item['type']?.toString() ?? ''),
          ),
          AppTableColumn<Map<String, dynamic>>(
            title: 'الإجمالي الصافي',
            width: 150,
            cellBuilder: (_, item, index) => Text(item['net']?.toString() ?? ''),
          ),
          AppTableColumn<Map<String, dynamic>>(
            title: 'حالة السداد',
            width: 130,
            cellBuilder: (_, item, index) => Text(item['paymentStatus']?.toString() ?? ''),
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
