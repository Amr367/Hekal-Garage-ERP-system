import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../inventory/presentation/inventory_controller.dart';
import '../stock_count_controller.dart';

/// Dialog for creating a new stock count session with scope selection.
class StockCountFormDialog extends ConsumerStatefulWidget {
  const StockCountFormDialog({super.key});

  /// Shows the dialog and returns the created session ID, or null if cancelled.
  static Future<int?> show(BuildContext context) {
    return showDialog<int?>(
      context: context,
      builder: (_) => const StockCountFormDialog(),
    );
  }

  @override
  ConsumerState<StockCountFormDialog> createState() =>
      _StockCountFormDialogState();
}

class _StockCountFormDialogState extends ConsumerState<StockCountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String _scope = 'all';
  int? _categoryId;
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scope == 'category' && _categoryId == null) return;

    setState(() => _saving = true);
    final actions = ref.read(stockCountActionsProvider);
    final id = await actions.createStockCount(
      context,
      scope: _scope,
      categoryId: _categoryId,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    setState(() => _saving = false);
    if (id != null && mounted) {
      Navigator.of(context).pop(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);
    final categories = categoriesAsync.value ?? [];

    return AppFormDialog(
      title: AppStrings.newStockCountTitle,
      isLoading: _saving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Scope selection
            DropdownButtonFormField<String>(
              initialValue: _scope,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: AppStrings.stockCountScopeLabel,
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'all', child: Text(AppStrings.scopeAll)),
                DropdownMenuItem(
                    value: 'category', child: Text(AppStrings.scopeCategory)),
                DropdownMenuItem(
                    value: 'recent', child: Text(AppStrings.scopeRecent)),
              ],
              onChanged: (v) {
                setState(() {
                  _scope = v ?? 'all';
                  if (_scope != 'category') _categoryId = null;
                });
              },
              validator: (v) =>
                  v == null ? AppStrings.stockCountScopeRequired : null,
            ),

            // Category picker (only if scope == 'category')
            if (_scope == 'category') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: AppStrings.stockCountCategoryFilterLabel,
                ),
                items: categories
                    .map((c) =>
                        DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
                validator: (v) =>
                    v == null ? AppStrings.stockCountScopeRequired : null,
              ),
            ],

            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: AppStrings.stockCountNotesLabel,
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
