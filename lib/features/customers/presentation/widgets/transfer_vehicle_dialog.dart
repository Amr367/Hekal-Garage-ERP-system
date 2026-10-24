import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/providers.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../customers_controller.dart';

/// Dialog to transfer vehicle ownership from one customer to another (Rule R14).
class TransferVehicleDialog extends ConsumerStatefulWidget {
  const TransferVehicleDialog({
    super.key,
    required this.vehicle,
    required this.currentOwner,
  });

  final Vehicle vehicle;
  final Customer currentOwner;

  static Future<bool?> show(
    BuildContext context, {
    required Vehicle vehicle,
    required Customer currentOwner,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TransferVehicleDialog(
        vehicle: vehicle,
        currentOwner: currentOwner,
      ),
    );
  }

  @override
  ConsumerState<TransferVehicleDialog> createState() => _TransferVehicleDialogState();
}

class _TransferVehicleDialogState extends ConsumerState<TransferVehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  int? _selectedNewCustomerId;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedNewCustomerId == null) {
      setState(() => _errorMessage = 'يرجى اختيار العميل الجديد المنقولة إليه السيارة');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final controller = ref.read(vehiclesControllerProvider);
      await controller.transferVehicle(
        widget.vehicle.id,
        _selectedNewCustomerId!,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.transferSuccess),
            backgroundColor: AppColors.success,
          ),
        );
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
    final customersRepo = ref.watch(customersRepositoryProvider);

    return AppFormDialog(
      title: AppStrings.transferTitle,
      saveLabel: AppStrings.transferVehicleButton,
      isLoading: _isSaving,
      onSave: _isSaving ? null : _submit,
      maxWidth: 580,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Info Card of Vehicle & Current Owner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.vehicle.plateNumber,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${widget.vehicle.make ?? ''} ${widget.vehicle.model ?? ''} ${widget.vehicle.year ?? ''}'.trim(),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${AppStrings.previousOwnerLabel}: ${widget.currentOwner.name} (${widget.currentOwner.phone ?? 'بدون هاتف'})',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // R14 Advisory Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.info),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.info_outline, color: AppColors.info, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppStrings.transferWarning,
                        style: TextStyle(color: AppColors.info, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Customer Selector
              FutureBuilder<List<Customer>>(
                future: customersRepo.getAll(onlyActive: true),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final eligibleCustomers = (snapshot.data ?? <Customer>[])
                      .where((c) => c.id != widget.currentOwner.id)
                      .toList();

                  if (eligibleCustomers.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'لا يوجد عملاء آخرون مسجلون في النظام لنقل الملكية إليهم. يمكنك إضافة عميل جديد أولاً.',
                        style: TextStyle(color: AppColors.warning, fontSize: 13),
                      ),
                    );
                  }

                  return DropdownButtonFormField<int>(
                    initialValue: _selectedNewCustomerId,
                    decoration: const InputDecoration(
                      labelText: AppStrings.transferTargetCustomerLabel,
                      prefixIcon: Icon(Icons.person_pin_outlined),
                    ),
                    items: eligibleCustomers.map((c) {
                      return DropdownMenuItem<int>(
                        value: c.id,
                        child: Text('${c.name} (${c.phone ?? 'بدون هاتف'})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedNewCustomerId = val);
                    },
                    validator: (val) {
                      if (val == null) {
                        return 'يرجى اختيار العميل الجديد';
                      }
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // Transfer notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: AppStrings.transferNotesLabel,
                  hintText: 'سبب النقل، بيع السيارة، أو أي ملاحظات إضافية...',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
