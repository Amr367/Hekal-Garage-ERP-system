import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/supplier_with_balance.dart';
import '../purchases_controller.dart';
import 'supplier_form_dialog.dart';
import 'supplier_payment_dialog.dart';

/// Modal dialog for managing suppliers, viewing debts, and recording payments.
class SuppliersDialog extends ConsumerStatefulWidget {
  const SuppliersDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) => const SuppliersDialog(),
    );
  }

  @override
  ConsumerState<SuppliersDialog> createState() => _SuppliersDialogState();
}

class _SuppliersDialogState extends ConsumerState<SuppliersDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersListProvider);

    return AppFormDialog(
      title: AppStrings.suppliersTitle,
      maxWidth: 900,
      showSaveButton: false,
      cancelLabel: AppStrings.close,
      child: SizedBox(
        height: 520,
        child: Column(
          children: <Widget>[
            // ── Toolbar ─────────────────────────────────────────────────────
            Row(
              children: <Widget>[
                Expanded(
                  child: SearchField(
                    hintText: AppStrings.searchSuppliersHint,
                    onChanged: (q) => setState(() => _searchQuery = q),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final createdId = await SupplierFormDialog.show(context);
                    if (createdId != null) {
                      ref.invalidate(suppliersListProvider);
                    }
                  },
                  icon: const Icon(Icons.add_business),
                  label: const Text(AppStrings.newSupplierButton),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Table ───────────────────────────────────────────────────────
            Expanded(
              child: suppliersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorState(title: 'خطأ', message: e.toString()),
                data: (suppliers) {
                  final filtered = suppliers.where((s) {
                    if (_searchQuery.trim().isEmpty) return true;
                    final q = _searchQuery.trim().toLowerCase();
                    final nameMatch = s.name.toLowerCase().contains(q);
                    final phoneMatch = s.phone?.contains(q) ?? false;
                    return nameMatch || phoneMatch;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const EmptyState(
                      title: 'لا يوجد موردين مسجلين',
                      subtitle: 'يمكنك إضافة مورد جديد لتسجيل فواتير الشراء وتوريد الأصناف.',
                      icon: Icons.store_outlined,
                    );
                  }

                  return AppDataTable<SupplierWithBalance>(
                    columns: <AppTableColumn<SupplierWithBalance>>[
                      AppTableColumn<SupplierWithBalance>(
                        title: AppStrings.supplierNameLabel,
                        flex: 2,
                        cellBuilder: (_, s, _) => Text(
                          s.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      AppTableColumn<SupplierWithBalance>(
                        title: AppStrings.supplierPhoneLabel,
                        width: 140,
                        cellBuilder: (_, s, _) => Text(s.phone ?? '-'),
                      ),
                      AppTableColumn<SupplierWithBalance>(
                        title: AppStrings.supplierInvoicesCount,
                        width: 110,
                        cellBuilder: (_, s, _) => Text('${s.invoicesCount} فاتورة'),
                      ),
                      AppTableColumn<SupplierWithBalance>(
                        title: AppStrings.supplierBalanceLabel,
                        width: 160,
                        cellBuilder: (_, s, _) => Text(
                          s.formattedBalanceDue,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: s.hasDebt ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      ),
                      AppTableColumn<SupplierWithBalance>(
                        title: AppStrings.tableActions,
                        width: 170,
                        cellBuilder: (ctx, s, _) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (s.hasDebt)
                              IconButton(
                                onPressed: () async {
                                  final ok = await SupplierPaymentDialog.show(context, supplier: s);
                                  if (ok == true) {
                                    ref.invalidate(suppliersListProvider);
                                  }
                                },
                                icon: const Icon(Icons.payment, color: AppColors.success),
                                tooltip: AppStrings.recordSupplierPaymentButton,
                              ),
                            IconButton(
                              onPressed: () async {
                                await SupplierFormDialog.show(context, initialSupplier: s.supplier);
                                ref.invalidate(suppliersListProvider);
                              },
                              icon: const Icon(Icons.edit, color: AppColors.primary),
                              tooltip: AppStrings.editSupplierButton,
                            ),
                          ],
                        ),
                      ),
                    ],
                    items: filtered,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
