import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../customers_controller.dart';

/// Dialog for creating or editing a customer.
class CustomerFormDialog extends ConsumerStatefulWidget {
  const CustomerFormDialog({
    super.key,
    this.customer,
  });

  final Customer? customer;

  static Future<int?> show(BuildContext context, {Customer? customer}) {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomerFormDialog(customer: customer),
    );
  }

  @override
  ConsumerState<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;
  late bool _isActive;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(text: widget.customer?.phone ?? '');
    _notesController = TextEditingController(text: widget.customer?.notes ?? '');
    _isActive = widget.customer?.isActive ?? true;
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

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(customersListProvider.notifier);
      if (widget.customer == null) {
        // Create new customer
        final id = await notifier.addCustomer(
          CustomersCompanion(
            name: drift.Value(_nameController.text.trim()),
            phone: drift.Value(
              _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            ),
            notes: drift.Value(
              _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            ),
            isActive: drift.Value(_isActive),
          ),
        );
        if (mounted) {
          Navigator.of(context).pop(id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.customerSavedSuccess),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        // Update existing customer
        final updated = widget.customer!.copyWith(
          name: _nameController.text.trim(),
          phone: drift.Value(
            _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          ),
          notes: drift.Value(
            _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          ),
          isActive: _isActive,
        );
        await notifier.updateCustomer(updated);
        if (mounted) {
          Navigator.of(context).pop(widget.customer!.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.customerSavedSuccess),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customer != null;
    final title = isEditing ? AppStrings.editCustomerButton : AppStrings.newCustomerButton;

    return AppFormDialog(
      title: title,
      isLoading: _isSaving,
      onSave: _isSaving ? null : _submit,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_errorMessage != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: AppStrings.customerNameLabel,
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return AppStrings.fieldRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: AppStrings.customerPhoneLabel,
                  hintText: '01xxxxxxxxx',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: AppStrings.customerNotesLabel,
                  hintText: 'ملاحظات خاصة، الرقم القومي، أو عنوان...',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              if (isEditing) ...<Widget>[
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(AppStrings.customerStatusLabel),
                  subtitle: Text(
                    _isActive ? AppStrings.customerStatusActive : AppStrings.customerStatusInactive,
                    style: TextStyle(
                      color: _isActive ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
