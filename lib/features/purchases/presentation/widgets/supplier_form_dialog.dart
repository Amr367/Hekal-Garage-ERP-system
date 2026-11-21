import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/strings.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/state_views.dart';
import '../purchases_controller.dart';

/// Modal dialog for creating or editing a supplier.
class SupplierFormDialog extends ConsumerStatefulWidget {
  const SupplierFormDialog({
    super.key,
    this.initialSupplier,
  });

  final Supplier? initialSupplier;

  static Future<int?> show(BuildContext context, {Supplier? initialSupplier}) {
    return showDialog<int?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => SupplierFormDialog(initialSupplier: initialSupplier),
    );
  }

  @override
  ConsumerState<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;
  bool _isSaving = false;

  bool get _isEdit => widget.initialSupplier != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialSupplier?.name ?? '');
    _phoneController = TextEditingController(text: widget.initialSupplier?.phone ?? '');
    _notesController = TextEditingController(text: widget.initialSupplier?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final actions = ref.read(purchasesActionsControllerProvider);

    try {
      if (_isEdit) {
        final updated = widget.initialSupplier!.copyWith(
          name: _nameController.text.trim(),
          phone: drift.Value(_phoneController.text.trim().isEmpty ? null : _phoneController.text.trim()),
          notes: drift.Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
        );
        await actions.updateSupplier(updated);
        if (mounted) {
          AppSnackbar.showSuccess(context, AppStrings.supplierSavedSuccess);
          Navigator.of(context).pop(updated.id);
        }
      } else {
        final id = await actions.createSupplier(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
        if (mounted) {
          AppSnackbar.showSuccess(context, AppStrings.supplierSavedSuccess);
          Navigator.of(context).pop(id);
        }
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
    return AppFormDialog(
      title: _isEdit ? AppStrings.editSupplierButton : AppStrings.newSupplierButton,
      maxWidth: 500,
      onSave: _isSaving ? null : _submit,
      isLoading: _isSaving,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '${AppStrings.supplierNameLabel} *',
                prefixIcon: Icon(Icons.store),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return AppStrings.fieldRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: AppStrings.supplierPhoneLabel,
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: AppStrings.supplierNotesLabel,
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
