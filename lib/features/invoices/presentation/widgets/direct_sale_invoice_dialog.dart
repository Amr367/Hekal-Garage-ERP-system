import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/qty_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../inventory/domain/item_with_stock.dart';
import '../../domain/invoice_line_entry.dart';
import '../invoices_controller.dart';

/// Modal dialog for issuing a direct sales invoice (counter sales / quick services).
class DirectSaleInvoiceDialog extends ConsumerStatefulWidget {
  const DirectSaleInvoiceDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DirectSaleInvoiceDialog(),
    );
  }

  @override
  ConsumerState<DirectSaleInvoiceDialog> createState() => _DirectSaleInvoiceDialogState();
}

class _DirectSaleInvoiceDialogState extends ConsumerState<DirectSaleInvoiceDialog> {
  int? _selectedCustomerId;
  final List<InvoiceLineEntry> _lines = <InvoiceLineEntry>[];

  int _discountPiasters = 0;
  int _paidAmountPiasters = 0;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  final _refController = TextEditingController();
  final _notesController = TextEditingController();

  List<Customer> _customers = <Customer>[];
  List<ItemWithStock> _inventoryItems = <ItemWithStock>[];
  List<Service> _services = <Service>[];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPrerequisites();
  }

  @override
  void dispose() {
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPrerequisites() async {
    final customersRepo = ref.read(customersRepositoryProvider);
    final itemsRepo = ref.read(itemsRepositoryProvider);
    final servicesRepo = ref.read(servicesRepositoryProvider);

    final custs = await customersRepo.getAll(onlyActive: true);
    final items = await itemsRepo.getItemsWithStock();
    final servs = await servicesRepo.getAll(onlyActive: true);

    if (mounted) {
      setState(() {
        _customers = custs;
        _inventoryItems = items;
        _services = servs;
      });
    }
  }

  int get _computedSubtotal {
    int sum = 0;
    for (final l in _lines) {
      sum += l.totalPricePiasters;
    }
    return sum;
  }

  int get _computedTotal {
    final total = (_computedSubtotal - _discountPiasters).clamp(0, double.maxFinite.toInt());
    return total;
  }

  void _addLine(InvoiceLineEntry line) {
    setState(() {
      _lines.add(line);
      _paidAmountPiasters = _computedTotal;
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
      _paidAmountPiasters = _computedTotal;
    });
  }

  void _showAddPartDialog() {
    ItemWithStock? selectedItem;
    double qty = 1.0;
    int unitPrice = 0;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('إضافة قطعة غيار من المخزن', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'اختر الصنف من المخزن'),
                    isExpanded: true,
                    items: _inventoryItems.map((item) {
                      final onHand = Formatters.formatQty(item.stockOnHand);
                      return DropdownMenuItem<int>(
                        value: item.id,
                        child: Text(
                          '${item.name} (رصيد: $onHand ${item.unit})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (id) {
                      if (id != null) {
                        final found = _inventoryItems.firstWhere((i) => i.id == id);
                        setDialogState(() {
                          selectedItem = found;
                          unitPrice = found.salePrice;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  QtyField(
                    initialQty: qty,
                    label: 'الكمية المطلوبة',
                    unitSuffix: selectedItem?.unit ?? 'قطعة',
                    onChangedQty: (q) => setDialogState(() => qty = q ?? 1.0),
                  ),
                  const SizedBox(height: 12),
                  MoneyField(
                    initialPiasters: unitPrice,
                    label: 'سعر البيع للوحدة',
                    onChangedPiasters: (p) => setDialogState(() => unitPrice = p ?? 0),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () {
                  if (selectedItem == null) return;
                  if (qty <= 0) return;
                  final total = (unitPrice * qty).round();
                  _addLine(
                    InvoiceLineEntry(
                      lineType: LineType.part,
                      itemId: selectedItem!.id,
                      description: selectedItem!.name,
                      quantity: qty,
                      unitPricePiasters: unitPrice,
                      unitCostPiasters: selectedItem!.costPrice,
                      totalPricePiasters: total,
                    ),
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('إضافة للفاتورة'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddServiceDialog() {
    Service? selectedService;
    String customDesc = '';
    int price = 0;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('إضافة مصنعية / خدمة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'اختر خدمة معرفة أو أكتب بياناً'),
                    isExpanded: true,
                    items: [
                      ..._services.map((s) => DropdownMenuItem<int>(
                            value: s.id,
                            child: Text('${s.name} (${MoneyUtils.format(s.defaultPrice, withCurrency: true)})'),
                          )),
                    ],
                    onChanged: (id) {
                      if (id != null) {
                        final found = _services.firstWhere((s) => s.id == id);
                        setDialogState(() {
                          selectedService = found;
                          customDesc = found.name;
                          price = found.defaultPrice;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: customDesc,
                    decoration: const InputDecoration(labelText: 'البيان / تفاصيل الخدمة'),
                    onChanged: (v) => setDialogState(() => customDesc = v),
                  ),
                  const SizedBox(height: 12),
                  MoneyField(
                    initialPiasters: price,
                    label: 'قيمة المصنعية',
                    onChangedPiasters: (p) => setDialogState(() => price = p ?? 0),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () {
                  final desc = customDesc.trim().isNotEmpty ? customDesc.trim() : (selectedService?.name ?? '');
                  if (desc.isEmpty) return;
                  _addLine(
                    InvoiceLineEntry(
                      lineType: LineType.service,
                      serviceId: selectedService?.id,
                      description: desc,
                      quantity: 1.0,
                      unitPricePiasters: price,
                      totalPricePiasters: price,
                    ),
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('إضافة للفاتورة'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (_lines.isEmpty) {
      AppSnackbar.showError(context, 'يرجى إضافة بند واحد على الأقل في الفاتورة');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final invoice = await ref.read(invoicesActionsProvider).createDirectSale(
            customerId: _selectedCustomerId,
            lines: _lines,
            discountAmountPiasters: _discountPiasters,
            paidAmountPiasters: _paidAmountPiasters,
            paymentMethod: _selectedPaymentMethod,
            paymentNotes: _refController.text.trim().isNotEmpty ? _refController.text.trim() : null,
            notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
        AppSnackbar.showSuccess(context, 'تم إصدار الفاتورة #${invoice.invoiceNumber} بنجاح');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: 'إصدار فاتورة بيع مباشر / كاونتر',
      maxWidth: 720,
      isLoading: _isLoading,
      onSave: _submit,
      saveLabel: 'إصدار الفاتورة وتأكيد البيع',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Customer picker
          DropdownButtonFormField<int?>(
            initialValue: _selectedCustomerId,
            decoration: const InputDecoration(
              labelText: 'العميل (اختياري - افتراضياً عميل نقدي مباشر)',
              prefixIcon: Icon(Icons.person_outline),
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('عميل نقدي مباشر (كاونتر)'),
              ),
              ..._customers.map((c) => DropdownMenuItem<int?>(
                    value: c.id,
                    child: Text('${c.name} ${c.phone != null ? "(${c.phone})" : ""}'),
                  )),
            ],
            onChanged: (id) => setState(() => _selectedCustomerId = id),
          ),

          const SizedBox(height: 16),

          // Line items box
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with add buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const Text(
                        'بنود الفاتورة (قطع غيار ومصنعيات)',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _showAddPartDialog,
                            icon: const Icon(Icons.add_shopping_cart, size: 16),
                            label: const Text('إضافة قطعة'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _showAddServiceDialog,
                            icon: const Icon(Icons.build_outlined, size: 16),
                            label: const Text('إضافة مصنعية'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Lines list
                if (_lines.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'لا توجد بنود مضافة بعد. اضغط على الأزرار أعلاه لإضافة قطع أو خدمات.',
                        style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _lines.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final line = _lines[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: line.isService ? AppColors.secondaryContainer : AppColors.primaryContainer,
                          child: Icon(
                            line.isService ? Icons.build : Icons.inventory_2,
                            size: 14,
                            color: line.isService ? AppColors.secondary : AppColors.primary,
                          ),
                        ),
                        title: Text(line.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text(
                          '${line.formattedQuantity} × ${line.formattedUnitPrice}',
                          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              line.formattedTotalPrice,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                              onPressed: () => _removeLine(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Financial breakdown
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المجموع الفرعي:', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(MoneyUtils.format(_computedSubtotal, withCurrency: true), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      flex: 3,
                      child: Text('الخصم الممنوح:'),
                    ),
                    Expanded(
                      flex: 2,
                      child: MoneyField(
                        initialPiasters: _discountPiasters,
                        label: 'الخصم',
                        onChangedPiasters: (p) {
                          setState(() {
                            _discountPiasters = p ?? 0;
                            _paidAmountPiasters = _computedTotal;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('صافي الفاتورة الإجمالي:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(
                      MoneyUtils.format(_computedTotal, withCurrency: true),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      flex: 3,
                      child: Text('المبلغ المحصل والمدفوع الآن:'),
                    ),
                    Expanded(
                      flex: 2,
                      child: MoneyField(
                        initialPiasters: _paidAmountPiasters,
                        label: 'المدفوع',
                        onChangedPiasters: (p) => setState(() => _paidAmountPiasters = p ?? 0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Payment method chips
          const Text('طريقة التحصيل والدفع:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MethodChip(
                label: 'خزنة الفرع (كاش)',
                icon: Icons.payments_outlined,
                isSelected: _selectedPaymentMethod == PaymentMethod.cash,
                onSelected: () => setState(() => _selectedPaymentMethod = PaymentMethod.cash),
              ),
              _MethodChip(
                label: 'انستاباي (InstaPay)',
                icon: Icons.bolt,
                isSelected: _selectedPaymentMethod == PaymentMethod.instapay,
                onSelected: () => setState(() => _selectedPaymentMethod = PaymentMethod.instapay),
              ),
              _MethodChip(
                label: 'فودافون كاش ومحافظ',
                icon: Icons.phone_android,
                isSelected: _selectedPaymentMethod == PaymentMethod.wallet,
                onSelected: () => setState(() => _selectedPaymentMethod = PaymentMethod.wallet),
              ),
              _MethodChip(
                label: 'فيزا / كارت',
                icon: Icons.credit_card,
                isSelected: _selectedPaymentMethod == PaymentMethod.card,
                onSelected: () => setState(() => _selectedPaymentMethod = PaymentMethod.card),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Notes
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'ملاحظات الفاتورة (اختياري)',
              hintText: 'تعليمات أو ملاحظات إضافية...',
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => onSelected(),
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.onSurfaceVariant),
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.onSurface),
    );
  }
}
