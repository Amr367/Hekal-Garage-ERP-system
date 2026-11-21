import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../services_controller.dart';

/// Modal dialog for adding or editing a service in the garage catalog.
class ServiceFormDialog extends ConsumerStatefulWidget {
  const ServiceFormDialog({
    super.key,
    this.service,
  });

  final Service? service;

  static Future<int?> show(BuildContext context, {Service? service}) {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ServiceFormDialog(service: service),
    );
  }

  @override
  ConsumerState<ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends ConsumerState<ServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late int _pricePiasters;
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.service?.name ?? '');
    _pricePiasters = widget.service?.defaultPrice ?? 0;
    _isActive = widget.service?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackbar.showError(context, 'يرجى إدخال اسم الخدمة.');
      return;
    }
    if (_pricePiasters < 0) {
      AppSnackbar.showError(context, 'سعر الخدمة لا يمكن أن يكون سالباً.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final actions = ref.read(servicesActionsProvider);
      int resultId;
      if (widget.service == null) {
        resultId = await actions.addService(
          name: name,
          defaultPricePiasters: _pricePiasters,
        );
        if (mounted) {
          AppSnackbar.showSuccess(context, 'تمت إضافة الخدمة بنجاح.');
        }
      } else {
        resultId = widget.service!.id;
        await actions.updateService(
          id: resultId,
          name: name,
          defaultPricePiasters: _pricePiasters,
          isActive: _isActive,
        );
        if (mounted) {
          AppSnackbar.showSuccess(context, 'تم تحديث بيانات الخدمة وسعرها بنجاح.');
        }
      }

      if (mounted) {
        Navigator.of(context).pop(resultId);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'فشل حفظ الخدمة: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.service != null;

    return AppFormDialog(
      title: isEditing ? 'تعديل بيانات وسعر الخدمة' : 'إضافة خدمة ومصنعية جديدة',
      maxWidth: 480,
      isLoading: _isLoading,
      onSave: _submit,
      saveLabel: isEditing ? 'حفظ التعديلات' : 'إضافة الخدمة',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم الخدمة / بيان المصنعية *',
                hintText: 'مثال: فحص دورة تبريد، مصنعية تغيير تيل فرامل...',
              ),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'يرجى كتابة اسم الخدمة' : null,
            ),
            const SizedBox(height: 16),
            MoneyField(
              initialPiasters: _pricePiasters,
              label: 'السعر الافتراضي للمصنعية / الخدمة (جنيه)',
              onChangedPiasters: (p) => _pricePiasters = p ?? 0,
            ),
            if (isEditing) ...[
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('الخدمة مفعّلة ونشطة', style: TextStyle(fontSize: 13)),
                subtitle: const Text('الخدمات غير النشطة لا تظهر في قوائم الاختيار السريع', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                value: _isActive,
                activeTrackColor: AppColors.primary,
                onChanged: (val) => setState(() => _isActive = val),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
