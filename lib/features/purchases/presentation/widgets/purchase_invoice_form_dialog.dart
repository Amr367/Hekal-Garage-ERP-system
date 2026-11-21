import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/repositories/purchases_repository.dart';
import '../../../../core/money/money.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/qty_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../inventory/domain/item_with_stock.dart';
import '../../../inventory/presentation/inventory_controller.dart';
import '../../domain/purchase_invoice_with_details.dart';
import '../purchases_controller.dart';
import 'supplier_form_dialog.dart';

class _LocalPurchaseLine {
  _LocalPurchaseLine({
    required this.item,
    required this.quantity,
    required this.unitCostPiasters,
  });

  final ItemWithStock item;
  double quantity;
  int unitCostPiasters;

  int get lineTotal => (quantity * unitCostPiasters).round();
}

/// Modal dialog for recording a new purchase invoice.
class PurchaseInvoiceFormDialog extends ConsumerStatefulWidget {
  const PurchaseInvoiceFormDialog({super.key});

  static Future<PurchaseInvoiceWithDetails?> show(BuildContext context) {
    return showDialog<PurchaseInvoiceWithDetails?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => const PurchaseInvoiceFormDialog(),
    );
  }

  @override
  ConsumerState<PurchaseInvoiceFormDialog> createState() =>
      _PurchaseInvoiceFormDialogState();
}

class _PurchaseInvoiceFormDialogState
    extends ConsumerState<PurchaseInvoiceFormDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedSupplierId;
  final TextEditingController _supplierInvoiceNumberController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime _invoiceDate = DateTime.now();

  final List<_LocalPurchaseLine> _lines = [];

  // Line creation state
  ItemWithStock? _selectedItemForLine;
  double _lineQty = 1.0;
  int _lineCostPiasters = 0;

  // Paid amount
  int _paidAmountPiasters = 0;
  bool _userExplicitlyModifiedPaid = false;
  bool _isSaving = false;

  int get _grandTotalPiasters {
    int total = 0;
    for (final l in _lines) {
      total += l.lineTotal;
    }
    return total;
  }

  int get _remainingPiasters => _grandTotalPiasters - _paidAmountPiasters;

  @override
  void dispose() {
    _supplierInvoiceNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addLine() {
    if (_selectedItemForLine == null) {
      AppSnackbar.showError(context, 'يرجى اختيار الصنف أولاً');
      return;
    }
    if (_lineQty <= 0) {
      AppSnackbar.showError(context, 'الكمية يجب أن تكون أكبر من صفر');
      return;
    }
    if (_lineCostPiasters < 0) {
      AppSnackbar.showError(context, 'سعر التكلفة لا يمكن أن يكون سالباً');
      return;
    }

    setState(() {
      _lines.add(
        _LocalPurchaseLine(
          item: _selectedItemForLine!,
          quantity: _lineQty,
          unitCostPiasters: _lineCostPiasters,
        ),
      );

      // Auto-update paid amount to full total unless user explicitly edited it
      if (!_userExplicitlyModifiedPaid) {
        _paidAmountPiasters = _grandTotalPiasters;
      }

      // Reset line fields
      _selectedItemForLine = null;
      _lineQty = 1.0;
      _lineCostPiasters = 0;
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
      if (!_userExplicitlyModifiedPaid) {
        _paidAmountPiasters = _grandTotalPiasters;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSupplierId == null) {
      AppSnackbar.showError(context, AppStrings.supplierRequired);
      return;
    }

    if (_lines.isEmpty) {
      AppSnackbar.showError(context, AppStrings.noPurchaseLines);
      return;
    }

    setState(() => _isSaving = true);
    final actions = ref.read(purchasesActionsControllerProvider);

    try {
      final created = await actions.createPurchaseInvoice(
        supplierId: _selectedSupplierId!,
        supplierInvoiceNumber: _supplierInvoiceNumberController.text.trim().isEmpty
            ? null
            : _supplierInvoiceNumberController.text.trim(),
        invoiceDate: _invoiceDate,
        paidAmountPiasters: _paidAmountPiasters,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        lines: _lines
            .map((l) => PurchaseLineInput(
                  itemId: l.item.id,
                  quantity: l.quantity,
                  unitCostPiasters: l.unitCostPiasters,
                ))
            .toList(),
      );

      if (mounted) {
        AppSnackbar.showSuccess(context, AppStrings.purchaseSavedSuccess);
        Navigator.of(context).pop(created);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersListProvider);
    final itemsAsync = ref.watch(inventoryListProvider);

    return AppFormDialog(
      title: AppStrings.purchaseInvoiceTitle,
      maxWidth: 850,
      onSave: _isSaving ? null : _submit,
      isLoading: _isSaving,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Supplier Selection & Invoice Date ───────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Supplier Dropdown
                Expanded(
                  flex: 3,
                  child: suppliersAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('خطأ في تحميل الموردين: $e'),
                    data: (suppliers) {
                      final activeSuppliers = suppliers.where((s) => s.isActive).toList();

                      return Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              initialValue: _selectedSupplierId,
                              decoration: const InputDecoration(
                                labelText: '${AppStrings.selectSupplierPrompt} *',
                                prefixIcon: Icon(Icons.store),
                              ),
                              items: activeSuppliers.map((s) {
                                return DropdownMenuItem<int>(
                                  value: s.id,
                                  child: Text('${s.name} ${s.phone != null ? "(${s.phone})" : ""}'),
                                );
                              }).toList(),
                              onChanged: (id) => setState(() => _selectedSupplierId = id),
                              validator: (v) => v == null ? AppStrings.fieldRequired : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: () async {
                              final newId = await SupplierFormDialog.show(context);
                              if (newId != null) {
                                ref.invalidate(suppliersListProvider);
                                setState(() => _selectedSupplierId = newId);
                              }
                            },
                            icon: const Icon(Icons.add),
                            tooltip: AppStrings.newSupplierButton,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Supplier Invoice Number
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _supplierInvoiceNumberController,
                    decoration: const InputDecoration(
                      labelText: AppStrings.supplierInvoiceNumberLabel,
                      hintText: AppStrings.supplierInvoiceNumberHint,
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Invoice Date Picker
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _invoiceDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setState(() => _invoiceDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: AppStrings.invoiceDateLabel,
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        '${_invoiceDate.year}/${_invoiceDate.month.toString().padLeft(2, '0')}/${_invoiceDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // ── Add Item to Invoice Row ──────────────────────────────────────
            const Text(
              AppStrings.purchaseLinesTitle,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // Item Picker
                  Expanded(
                    flex: 4,
                    child: itemsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text(e.toString()),
                      data: (items) {
                        final activeItems = items.where((i) => i.isActive).toList();
                        return DropdownButtonFormField<ItemWithStock>(
                          isExpanded: true,
                          initialValue: _selectedItemForLine,
                          decoration: const InputDecoration(
                            labelText: AppStrings.selectItemFromList,
                            prefixIcon: Icon(Icons.inventory_2),
                          ),
                          items: activeItems.map((item) {
                            return DropdownMenuItem<ItemWithStock>(
                              value: item,
                              child: Text(
                                '${item.name} (${item.categoryName}) - رصيد: ${item.formattedStock}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (item) {
                            setState(() {
                              _selectedItemForLine = item;
                              if (item != null) {
                                _lineCostPiasters = item.costPrice;
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Quantity
                  Expanded(
                    flex: 2,
                    child: QtyField(
                      label: AppStrings.lineQty,
                      initialQty: _lineQty,
                      onChangedQty: (q) => setState(() => _lineQty = q ?? 1.0),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Unit Cost
                  Expanded(
                    flex: 2,
                    child: MoneyField(
                      label: AppStrings.lineUnitCost,
                      initialPiasters: _lineCostPiasters,
                      onChangedPiasters: (p) => setState(() => _lineCostPiasters = p ?? 0),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Add Button
                  ElevatedButton.icon(
                    onPressed: _addLine,
                    icon: const Icon(Icons.add),
                    label: const Text(AppStrings.addPurchaseLine),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Lines Table ─────────────────────────────────────────────────
            if (_lines.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                child: const Text(
                  AppStrings.noLinesAdded,
                  style: TextStyle(color: AppColors.onSurfaceVariant),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _lines.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final line = _lines[index];
                    return ListTile(
                      title: Text(
                        line.item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'الكمية: ${Formatters.formatQty(line.quantity)} ${line.item.unit} × ${MoneyUtils.format(line.unitCostPiasters, withCurrency: true)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            MoneyUtils.format(line.lineTotal, withCurrency: true),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _removeLine(index),
                            icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                            tooltip: AppStrings.delete,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // ── Financial Totals & Payment ──────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Notes
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات الفاتورة',
                      prefixIcon: Icon(Icons.notes),
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // Financial Cards
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Expanded(
                              child: Text(
                                AppStrings.invoiceTotalAmount,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              MoneyUtils.format(_grandTotalPiasters, withCurrency: true),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        MoneyField(
                          label: AppStrings.invoicePaidAmount,
                          initialPiasters: _paidAmountPiasters,
                          onChangedPiasters: (p) {
                            setState(() {
                              _paidAmountPiasters = p ?? 0;
                              _userExplicitlyModifiedPaid = true;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            const Expanded(
                              child: Text(
                                AppStrings.invoiceRemainingAmount,
                                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                              ),
                            ),
                            Text(
                              MoneyUtils.format(_remainingPiasters, withCurrency: true),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _remainingPiasters > 0
                                    ? AppColors.danger
                                    : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
