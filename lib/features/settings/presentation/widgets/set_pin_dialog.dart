import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/money/money.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../data/pin_auth_service.dart';

/// Modal dialog for setting or updating the 4-digit PIN.
class SetPinDialog extends StatefulWidget {
  const SetPinDialog({
    super.key,
    required this.hasExistingPin,
    required this.authService,
  });

  final bool hasExistingPin;
  final PinAuthService authService;

  static Future<String?> show({
    required BuildContext context,
    required bool hasExistingPin,
    required PinAuthService authService,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => SetPinDialog(
        hasExistingPin: hasExistingPin,
        authService: authService,
      ),
    );
  }

  @override
  State<SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<SetPinDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newPin = MoneyUtils.normalizeDigits(_newPinController.text.trim());
    final confirmPin = MoneyUtils.normalizeDigits(_confirmPinController.text.trim());

    if (newPin != confirmPin) {
      setState(() => _errorMessage = AppStrings.pinsDoNotMatch);
      return;
    }

    if (widget.hasExistingPin) {
      setState(() => _isLoading = true);
      final currentPin = MoneyUtils.normalizeDigits(_currentPinController.text.trim());
      final isValid = await widget.authService.verifyPin(currentPin);
      setState(() => _isLoading = false);

      if (!isValid) {
        setState(() => _errorMessage = AppStrings.pinInvalid);
        return;
      }
    }

    if (mounted) {
      Navigator.of(context).pop(newPin);
    }
  }

  Widget _buildPinField({
    required String label,
    required TextEditingController controller,
    bool autofocus = false,
  }) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      obscureText: true,
      obscuringCharacter: '●',
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.w700),
      maxLength: 4,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
      ),
      validator: (value) {
        final text = MoneyUtils.normalizeDigits(value?.trim() ?? '');
        if (text.length != 4 || int.tryParse(text) == null) {
          return AppStrings.pinMustBe4Digits;
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: widget.hasExistingPin ? AppStrings.changePinButton : AppStrings.setPinButton,
      saveLabel: AppStrings.confirm,
      isLoading: _isLoading,
      onSave: _submit,
      maxWidth: 420,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.hasExistingPin) ...<Widget>[
              _buildPinField(
                label: AppStrings.currentPinLabel,
                controller: _currentPinController,
                autofocus: true,
              ),
              const SizedBox(height: 16),
            ],
            _buildPinField(
              label: AppStrings.newPinLabel,
              controller: _newPinController,
              autofocus: !widget.hasExistingPin,
            ),
            const SizedBox(height: 16),
            _buildPinField(
              label: AppStrings.confirmNewPinLabel,
              controller: _confirmPinController,
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
