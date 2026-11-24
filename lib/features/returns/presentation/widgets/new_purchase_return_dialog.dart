import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/providers.dart';
import '../../../../core/db/repositories/returns_repository.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../inventory/domain/item_with_stock.dart';
import '../../../purchases/domain/purchase_invoice_with_details.dart';
import '../../../purchases/domain/supplier_with_balance.dart';
import '../returns_controller.dart';
import 'return_preview_dialog.dart';

class _EditablePurchaseReturnLine {
  _EditablePurchaseReturnLine({
    this.itemId,
    required this.description,
    required this.unitPricePiasters,
    this.maxQuantity,
    this.quantity = 1,
    this.isSelected = true,
  });

  int? itemId;
  String description;
  int unitPricePiasters;
  double? maxQuantity;
  double quantity;
  bool isSelected;

  int get totalPricePiasters => (quantity * unitPricePiasters).round();
}

/// Dialog for creating a new Supplier Purchase Return (مرتجع مشتريات للمورد).
class NewPurchaseReturnDialog extends ConsumerStatefulWidget {
  const NewPurchaseReturnDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NewPurchaseReturnDialog(),
    );
  }

  @override
  ConsumerState<NewPurchaseReturnDialog> createState() =>
      _NewPurchaseReturnDialogState();
}

class _NewPurchaseReturnDialogState
    extends ConsumerState<NewPurchaseReturnDialog> {
  final _formKey = GlobalKey<FormState>();
  final _supplierNameController = TextEditingController();
  final _reasonController = TextEditingController();

  List<SupplierWithBalance> _suppliers = [];
  SupplierWithBalance? _selectedSupplier;

  List<PurchaseInvoiceWithDetails> _supplierInvoices = [];
  PurchaseInvoiceWithDetails? _selectedPurchaseInvoice;

  List<ItemWithStock> _inventoryItems = [];

  bool _isLoading = true;
  bool _isSaving = false;

  PaymentMethod _refundMethod = PaymentMethod.cash;
  final List<_EditablePurchaseReturnLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _supplierNameController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final suppliersRepo = ref.read(suppliersRepositoryProvider);
      final itemsRepo = ref.read(itemsRepositoryProvider);

      final results = await Future.wait([
        suppliersRepo.getSuppliersWithBalances(),
        itemsRepo.getItemsWithStock(onlyActive: true),
      ]);

      if (mounted) {
        setState(() {
          _suppliers = results[0] as List<SupplierWithBalance>;
          _inventoryItems = results[1] as List<ItemWithStock>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackbar.showError(context, 'فشل تحميل البيانات: $e');
      }
    }
  }

  Future<void> _onSupplierSelected(SupplierWithBalance? supplier) async {
    setState(() {
      _selectedSupplier = supplier;
      _selectedPurchaseInvoice = null;
      _supplierInvoices = [];
      _lines.clear();

      if (supplier != null) {
        _supplierNameController.text = supplier.name;
      }
    });

    if (supplier != null) {
      try {
        final purchasesRepo = ref.read(purchasesRepositoryProvider);
        final invoices =
            await purchasesRepo.getPurchaseInvoices(supplierId: supplier.id);
        if (mounted) {
          setState(() {
            _supplierInvoices = invoices;
          });
        }
      } catch (_) {}
    }
  }

  void _onInvoiceSelected(PurchaseInvoiceWithDetails? invoice) {
    setState(() {
      _selectedPurchaseInvoice = invoice;
      _lines.clear();

      if (invoice != null) {
        for (final l in invoice.lines) {
          _lines.add(
            _EditablePurchaseReturnLine(
              itemId: l.itemId,
              description: l.itemName,
              unitPricePiasters: l.unitCostPiasters,
              maxQuantity: l.quantity,
              quantity: l.quantity,
              isSelected: true,
            ),
          );
        }
      }
    });
  }

  void _addManualLine() {
    setState(() {
      _lines.add(
        _EditablePurchaseReturnLine(
          description: '',
          unitPricePiasters: 0,
          quantity: 1,
          isSelected: true,
        ),
      );
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
    });
  }

  int get _selectedLinesTotal {
    return _lines
        .where((l) => l.isSelected && l.quantity > 0)
        .fold(0, (sum, l) => sum + l.totalPricePiasters);
  }

  Future<void> _submit({bool openPrint = false}) async {
    if (!_formKey.currentState!.validate()) return;

    final selectedLines =
        _lines.where((l) => l.isSelected && l.quantity > 0).toList();
    if (selectedLines.isEmpty) {
      AppSnackbar.showWarning(context, 'يرجى تحديد بند واحد على الأقل للإرجاع');
      return;
    }

    for (final line in selectedLines) {
      if (line.description.trim().isEmpty) {
        AppSnackbar.showWarning(context, 'يرجى كتابة وصف لجميع البنود المحددة');
        return;
      }
      if (line.maxQuantity != null && line.quantity > line.maxQuantity!) {
        AppSnackbar.showError(
          context,
          'الكمية المرتجعة للبند (${line.description}) تتجاوز كمية الفاتورة الأصلية (${line.maxQuantity})',
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final lineEntries = selectedLines
          .map((l) => ReturnLineEntry(
                itemId: l.itemId,
                description: l.description.trim(),
                quantity: l.quantity,
                unitPrice: l.unitPricePiasters,
              ))
          .toList();

      final created = await ref
          .read(returnsActionsControllerProvider)
          .createPurchaseReturn(
            purchaseInvoiceId: _selectedPurchaseInvoice?.id,
            supplierId: _selectedSupplier?.id,
            supplierName: _supplierNameController.text.trim().isNotEmpty
                ? _supplierNameController.text.trim()
                : (_selectedSupplier?.name ?? 'مورد'),
            refundMethod: _refundMethod,
            reason: _reasonController.text.trim().isNotEmpty
                ? _reasonController.text.trim()
                : null,
            lines: lineEntries,
          );

      if (mounted) {
        Navigator.of(context).pop();
        AppSnackbar.showSuccess(context, AppStrings.returnCreatedSuccess);

        if (openPrint) {
          ReturnPreviewDialog.show(context, returnData: created);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppSnackbar.showError(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 820),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header ───────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border:
                            Border(bottom: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.replay_outlined,
                                color: AppColors.secondary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تسجيل إذن مرتجع مشتريات (إلى مورد)',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'إرجاع بضاعة لمورد مع خصمها من المخزن واسترداد القيمة أو تخفيض المديونية',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'إغلاق',
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    // ── Form Body ─────────────────────────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Row 1: Select Supplier & Invoice ──────────────
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Supplier dropdown
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<
                                      SupplierWithBalance?>(
                                    initialValue: _selectedSupplier,
                                    decoration: const InputDecoration(
                                      labelText: 'المورد *',
                                      prefixIcon: Icon(Icons.store_outlined),
                                    ),
                                    items: [
                                      const DropdownMenuItem<
                                          SupplierWithBalance?>(
                                        value: null,
                                        child: Text('اختر المورد...'),
                                      ),
                                      ..._suppliers.map((s) {
                                        return DropdownMenuItem<
                                            SupplierWithBalance?>(
                                          value: s,
                                          child: Text(
                                            '${s.name} (مديونية: ${(s.balanceDuePiasters / 100).toStringAsFixed(0)} ج.م)',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: _onSupplierSelected,
                                    validator: (s) =>
                                        s == null &&
                                                _supplierNameController.text
                                                    .trim()
                                                    .isEmpty
                                            ? 'يرجى اختيار المورد'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Purchase invoice selector
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<
                                      PurchaseInvoiceWithDetails?>(
                                    initialValue: _selectedPurchaseInvoice,
                                    decoration: InputDecoration(
                                      labelText: 'فاتورة الشراء المرجعية',
                                      prefixIcon: const Icon(
                                          Icons.receipt_long_outlined),
                                      suffixIcon: _selectedPurchaseInvoice !=
                                              null
                                          ? IconButton(
                                              icon: const Icon(Icons.clear,
                                                  size: 18),
                                              onPressed: () =>
                                                  _onInvoiceSelected(null),
                                            )
                                          : null,
                                    ),
                                    items: [
                                      const DropdownMenuItem<
                                          PurchaseInvoiceWithDetails?>(
                                        value: null,
                                        child: Text('بدون ربط بفاتورة شراء'),
                                      ),
                                      ..._supplierInvoices.map((inv) {
                                        return DropdownMenuItem<
                                            PurchaseInvoiceWithDetails?>(
                                          value: inv,
                                          child: Text(
                                            '#${inv.id}${inv.supplierInvoiceNumber != null ? " (${inv.supplierInvoiceNumber})" : ""}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: _onInvoiceSelected,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // ── Row 2: Refund Method & Reason ─────────────────
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<PaymentMethod>(
                                    initialValue: _refundMethod,
                                    decoration: const InputDecoration(
                                      labelText: AppStrings.refundMethodLabel,
                                      prefixIcon: Icon(Icons.payments_outlined),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: PaymentMethod.cash,
                                        child: Text(
                                            'نقداً (استرداد نقدي لخزينة المركز)'),
                                      ),
                                      DropdownMenuItem(
                                        value: PaymentMethod.transfer,
                                        child: Text(
                                            'إضافة لحساب المورد / تخفيض مديونية'),
                                      ),
                                      DropdownMenuItem(
                                        value: PaymentMethod.wallet,
                                        child:
                                            Text('تحويل بنكي / محفظة إلكترونية'),
                                      ),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _refundMethod = v);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _reasonController,
                                    decoration: const InputDecoration(
                                      labelText: AppStrings.returnReasonLabel,
                                      hintText: AppStrings.returnReasonHint,
                                      prefixIcon: Icon(Icons.comment_outlined),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Quick chips for reasons
                            Wrap(
                              spacing: 8,
                              children: [
                                'بضاعة تالفة / عيوب صناعة',
                                'عدم مطابقة للمواصفات',
                                'خطأ في التوريد',
                                'زيادة عن حاجة العمل',
                              ].map((reason) {
                                return ActionChip(
                                  label: Text(reason,
                                      style: const TextStyle(fontSize: 11)),
                                  onPressed: () {
                                    final current =
                                        _reasonController.text.trim();
                                    _reasonController.text = current.isEmpty
                                        ? reason
                                        : '$current - $reason';
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),

                            // ── Row 3: Returned Items Section ─────────────────
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'الأصناف وقطع الغيار المرتجعة للمورد:',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _addManualLine,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('إضافة بند مرتجع يدوي'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            if (_lines.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: const Center(
                                  child: Text(
                                    'لا توجد بنود بعد. اختر فاتورة شراء أو اضغط على "إضافة بند مرتجع يدوي"',
                                    style: TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.divider),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    Container(
                                      color: AppColors.surface,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      child: const Row(
                                        children: [
                                          SizedBox(
                                              width: 40,
                                              child: Text('تحديد',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12))),
                                          Expanded(
                                              flex: 3,
                                              child: Text('بيان الصنف',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12))),
                                          Expanded(
                                              flex: 2,
                                              child: Text('الكمية المرتجعة',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12))),
                                          Expanded(
                                              flex: 2,
                                              child: Text(
                                                  'سعر الشراء (ج.م)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12))),
                                          Expanded(
                                              flex: 2,
                                              child: Text('الإجمالي (ج.م)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12))),
                                          SizedBox(width: 40),
                                        ],
                                      ),
                                    ),
                                    const Divider(
                                        height: 1, color: AppColors.divider),
                                    ..._lines.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final line = entry.value;

                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: line.isSelected
                                              ? null
                                              : Colors.grey.withValues(alpha: 0.05),
                                          border: const Border(
                                            bottom: BorderSide(
                                                color: AppColors.divider,
                                                width: 0.5),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // Checkbox
                                            SizedBox(
                                              width: 40,
                                              child: Checkbox(
                                                value: line.isSelected,
                                                onChanged: (val) {
                                                  setState(() {
                                                    line.isSelected =
                                                        val ?? false;
                                                  });
                                                },
                                              ),
                                            ),

                                            // Description / Autocomplete
                                            Expanded(
                                              flex: 3,
                                              child: line.itemId != null
                                                  ? Text(
                                                      line.description,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: line.isSelected
                                                            ? AppColors
                                                                .textPrimary
                                                            : AppColors
                                                                .textSecondary,
                                                      ),
                                                    )
                                                  : Autocomplete<ItemWithStock>(
                                                      displayStringForOption:
                                                          (item) => item.name,
                                                      optionsBuilder:
                                                          (textEditingValue) {
                                                        if (textEditingValue
                                                            .text.isEmpty) {
                                                          return _inventoryItems
                                                              .take(10);
                                                        }
                                                        return _inventoryItems
                                                            .where((item) => item
                                                                .name
                                                                .toLowerCase()
                                                                .contains(
                                                                    textEditingValue
                                                                        .text
                                                                        .toLowerCase()));
                                                      },
                                                      onSelected: (item) {
                                                        setState(() {
                                                          line.itemId = item.id;
                                                          line.description =
                                                              item.name;
                                                          line.unitPricePiasters =
                                                              item.costPrice;
                                                        });
                                                      },
                                                      fieldViewBuilder: (ctx,
                                                          ctrl, focus, onSub) {
                                                        if (ctrl.text.isEmpty &&
                                                            line.description
                                                                .isNotEmpty) {
                                                          ctrl.text =
                                                              line.description;
                                                        }
                                                        return TextFormField(
                                                          controller: ctrl,
                                                          focusNode: focus,
                                                          decoration:
                                                              const InputDecoration(
                                                            hintText:
                                                                'اسم الصنف من المخزن',
                                                            isDense: true,
                                                          ),
                                                          onChanged: (v) =>
                                                              line.description =
                                                                  v,
                                                        );
                                                      },
                                                    ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Quantity
                                            Expanded(
                                              flex: 2,
                                              child: TextFormField(
                                                initialValue: line.quantity %
                                                            1 ==
                                                        0
                                                    ? line.quantity
                                                        .toInt()
                                                        .toString()
                                                    : line.quantity.toString(),
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true),
                                                decoration: InputDecoration(
                                                  isDense: true,
                                                  helperText: line
                                                              .maxQuantity !=
                                                          null
                                                      ? 'الأصل: ${line.maxQuantity}'
                                                      : null,
                                                ),
                                                onChanged: (v) {
                                                  final parsed =
                                                      double.tryParse(v) ?? 0;
                                                  setState(() {
                                                    line.quantity = parsed;
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Unit price
                                            Expanded(
                                              flex: 2,
                                              child: TextFormField(
                                                initialValue:
                                                    (line.unitPricePiasters /
                                                            100)
                                                        .toStringAsFixed(2),
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true),
                                                decoration:
                                                    const InputDecoration(
                                                        isDense: true),
                                                onChanged: (v) {
                                                  final parsed =
                                                      double.tryParse(v) ?? 0;
                                                  setState(() {
                                                    line.unitPricePiasters =
                                                        (parsed * 100).round();
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Total
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                '${(line.totalPricePiasters / 100).toStringAsFixed(2)} ج.م',
                                                textAlign: TextAlign.end,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),

                                            // Delete line
                                            SizedBox(
                                              width: 40,
                                              child: IconButton(
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 18,
                                                    color: AppColors.danger),
                                                onPressed: () =>
                                                    _removeLine(index),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // ── Footer ────────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border:
                            Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('إجمالي قيمة المرتجع للمورد:',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                              Text(
                                '${(_selectedLinesTotal / 100).toStringAsFixed(2)} ج.م',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('إلغاء'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => _submit(openPrint: true),
                            icon: const Icon(Icons.print_outlined, size: 18),
                            label: const Text('حفظ وطباعة الإذن'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => _submit(openPrint: false),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check, size: 18),
                            label: const Text('حفظ إذن المرتجع'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
