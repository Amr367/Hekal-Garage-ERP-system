import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../domain/stock_count_line_entry.dart';
import '../stock_count_controller.dart';

/// Dialog for entering or modifying the physically counted quantity of an item line.
class EditStockCountLineDialog extends ConsumerStatefulWidget {
  const EditStockCountLineDialog({
    super.key,
    required this.line,
  });

  final StockCountLineEntry line;

  /// Convenience runner to open the dialog.
  static Future<bool?> show(BuildContext context, StockCountLineEntry line) {
    return showDialog<bool?>(
      context: context,
      builder: (_) => EditStockCountLineDialog(line: line),
    );
  }

  @override
  ConsumerState<EditStockCountLineDialog> createState() =>
      _EditStockCountLineDialogState();
}

class _EditStockCountLineDialogState
    extends ConsumerState<EditStockCountLineDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _qtyController;
  late final TextEditingController _notesController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.line.countedQty != null
          ? Formatters.formatQty(widget.line.countedQty!)
          : '',
    );
    _notesController = TextEditingController(text: widget.line.notes ?? '');
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final double countedQty;
    try {
      countedQty = Formatters.parseQuantity(_qtyController.text);
      if (countedQty < 0) {
        throw const FormatException('الكمية لا يمكن أن تكون سالبة');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      return;
    }

    setState(() => _saving = true);
    final actions = ref.read(stockCountActionsProvider);
    final success = await actions.updateCountedQty(
      context,
      lineId: widget.line.id,
      countedQty: countedQty,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    setState(() => _saving = false);

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: '${AppStrings.editCountLineTitle} — ${widget.line.itemName}',
      isLoading: _saving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Info banner about system recorded quantity
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.inventory_2_outlined, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '${AppStrings.columnSystemQty}: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${widget.line.formattedSystemQty} ${widget.line.unit}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Counted quantity input
            TextFormField(
              controller: _qtyController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppStrings.actualCountLabel,
                suffixText: widget.line.unit,
                hintText: '0',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'يرجى إدخال الكمية الفعلية';
                }
                try {
                  final qty = Formatters.parseQuantity(v);
                  if (qty < 0) return 'الكمية يجب أن تكون أكبر من أو تساوي 0';
                } catch (e) {
                  return 'صيغة الكمية غير صحيحة';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Line notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: AppStrings.lineNotesLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
