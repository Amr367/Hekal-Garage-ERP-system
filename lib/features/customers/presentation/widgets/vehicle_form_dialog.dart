import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../customers_controller.dart';

/// Dialog for creating or editing a vehicle linked to a customer.
class VehicleFormDialog extends ConsumerStatefulWidget {
  const VehicleFormDialog({
    super.key,
    required this.customerId,
    this.vehicle,
  });

  final int customerId;
  final Vehicle? vehicle;

  static Future<int?> show(
    BuildContext context, {
    required int customerId,
    Vehicle? vehicle,
  }) {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VehicleFormDialog(
        customerId: customerId,
        vehicle: vehicle,
      ),
    );
  }

  @override
  ConsumerState<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends ConsumerState<VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plateController;
  late final TextEditingController _makeController;
  late final TextEditingController _modelController;
  late final TextEditingController _yearController;
  late final TextEditingController _colorController;
  late final TextEditingController _chassisController;
  late final TextEditingController _odometerController;

  String _normalizedPlate = '';
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _plateController = TextEditingController(text: widget.vehicle?.plateNumber ?? '');
    _makeController = TextEditingController(text: widget.vehicle?.make ?? '');
    _modelController = TextEditingController(text: widget.vehicle?.model ?? '');
    _yearController = TextEditingController(
      text: widget.vehicle?.year != null ? widget.vehicle!.year.toString() : '',
    );
    _colorController = TextEditingController(text: widget.vehicle?.color ?? '');
    _chassisController = TextEditingController(text: widget.vehicle?.chassisNumber ?? '');
    _odometerController = TextEditingController(
      text: widget.vehicle?.lastOdometer != null ? widget.vehicle!.lastOdometer.toString() : '',
    );

    _updateNormalizedPlate(_plateController.text);
    _plateController.addListener(() {
      _updateNormalizedPlate(_plateController.text);
    });
  }

  void _updateNormalizedPlate(String val) {
    setState(() {
      _normalizedPlate = Formatters.normalizePlateNumber(val);
    });
  }

  @override
  void dispose() {
    _plateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _chassisController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final norm = Formatters.normalizePlateNumber(_plateController.text);
    if (norm.isEmpty) {
      setState(() => _errorMessage = AppStrings.plateRequired);
      return;
    }

    int? year;
    if (_yearController.text.trim().isNotEmpty) {
      year = int.tryParse(_yearController.text.trim());
      if (year == null || year < 1950 || year > DateTime.now().year + 1) {
        setState(() => _errorMessage = AppStrings.invalidYear);
        return;
      }
    }

    int? odometer;
    if (_odometerController.text.trim().isNotEmpty) {
      odometer = int.tryParse(_odometerController.text.trim());
      if (odometer == null || odometer < 0) {
        setState(() => _errorMessage = AppStrings.invalidOdometer);
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final controller = ref.read(vehiclesControllerProvider);
      if (widget.vehicle == null) {
        // Create vehicle
        final id = await controller.addVehicle(
          VehiclesCompanion(
            customerId: drift.Value(widget.customerId),
            plateNumber: drift.Value(norm),
            make: drift.Value(_makeController.text.trim().isEmpty ? null : _makeController.text.trim()),
            model: drift.Value(_modelController.text.trim().isEmpty ? null : _modelController.text.trim()),
            year: drift.Value(year),
            color: drift.Value(_colorController.text.trim().isEmpty ? null : _colorController.text.trim()),
            chassisNumber: drift.Value(
              _chassisController.text.trim().isEmpty ? null : _chassisController.text.trim().toUpperCase(),
            ),
            lastOdometer: drift.Value(odometer),
            isActive: const drift.Value(true),
          ),
        );
        if (mounted) {
          Navigator.of(context).pop(id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.vehicleSavedSuccess),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        // Update vehicle
        final updated = widget.vehicle!.copyWith(
          plateNumber: norm,
          make: drift.Value(_makeController.text.trim().isEmpty ? null : _makeController.text.trim()),
          model: drift.Value(_modelController.text.trim().isEmpty ? null : _modelController.text.trim()),
          year: drift.Value(year),
          color: drift.Value(_colorController.text.trim().isEmpty ? null : _colorController.text.trim()),
          chassisNumber: drift.Value(
            _chassisController.text.trim().isEmpty ? null : _chassisController.text.trim().toUpperCase(),
          ),
          lastOdometer: drift.Value(odometer),
        );
        await controller.updateVehicle(updated);
        if (mounted) {
          Navigator.of(context).pop(widget.vehicle!.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.vehicleSavedSuccess),
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
    final isEditing = widget.vehicle != null;
    final title = isEditing ? AppStrings.editVehicleButton : AppStrings.addVehicleButton;

    return AppFormDialog(
      title: title,
      isLoading: _isSaving,
      onSave: _isSaving ? null : _submit,
      maxWidth: 620,
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

              // Plate number input + normalized preview
              TextFormField(
                controller: _plateController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: AppStrings.vehiclePlateLabel,
                  hintText: AppStrings.vehiclePlateHint,
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return AppStrings.plateRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              if (_normalizedPlate.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        '${AppStrings.vehiclePlateNormalized}: ',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        _normalizedPlate,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Make & Model
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _makeController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.vehicleMakeLabel,
                        hintText: AppStrings.vehicleMakeHint,
                        prefixIcon: Icon(Icons.directions_car_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.vehicleModelLabel,
                        hintText: AppStrings.vehicleModelHint,
                        prefixIcon: Icon(Icons.car_rental_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Year & Color
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: AppStrings.vehicleYearLabel,
                        hintText: '2020',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _colorController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.vehicleColorLabel,
                        hintText: 'أبيض / أسود / رمادي...',
                        prefixIcon: Icon(Icons.palette_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Chassis (VIN) & Current Odometer
              Row(
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _chassisController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: AppStrings.vehicleChassisLabel,
                        hintText: '17 رمز أو رقم',
                        prefixIcon: Icon(Icons.fingerprint),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _odometerController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: AppStrings.vehicleOdometerLabel,
                        hintText: '85000',
                        suffixText: AppStrings.vehicleOdometerUnit,
                        prefixIcon: Icon(Icons.speed),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
