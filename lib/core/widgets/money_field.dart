import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../money/money.dart';
import '../strings.dart';
import '../theme/app_colors.dart';

/// Form field for Egyptian Pound monetary inputs.
/// Automatically handles Arabic-Indic digits, decimal separators,
/// and stores amounts strictly as integer piasters.
class MoneyField extends StatefulWidget {
  const MoneyField({
    super.key,
    this.label,
    this.hintText = '0.00',
    this.initialPiasters,
    this.onChangedPiasters,
    this.onSubmittedPiasters,
    this.controller,
    this.focusNode,
    this.validator,
    this.enabled = true,
    this.readOnly = false,
    this.allowNegative = false,
    this.autofocus = false,
  });

  final String? label;
  final String hintText;
  final int? initialPiasters;
  final ValueChanged<int?>? onChangedPiasters;
  final ValueChanged<int?>? onSubmittedPiasters;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool readOnly;
  final bool allowNegative;
  final bool autofocus;

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    if (widget.initialPiasters != null) {
      _controller.text = MoneyUtils.formatPoundsOnly(widget.initialPiasters!);
    }
  }

  @override
  void didUpdateWidget(MoneyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPiasters != oldWidget.initialPiasters &&
        widget.initialPiasters != null &&
        widget.controller == null) {
      final currentPiasters = _parseCurrent();
      if (currentPiasters != widget.initialPiasters) {
        _controller.text = MoneyUtils.formatPoundsOnly(widget.initialPiasters!);
      }
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  int? _parseCurrent() {
    final text = _controller.text.trim();
    if (text.isEmpty) return null;
    try {
      final piasters = MoneyUtils.parseToPiasters(text);
      if (!widget.allowNegative && piasters < 0) {
        return null;
      }
      return piasters;
    } catch (_) {
      return null;
    }
  }

  void _onChanged(String value) {
    widget.onChangedPiasters?.call(_parseCurrent());
  }

  String? _defaultValidator(String? value) {
    if (widget.validator != null) {
      return widget.validator!(value);
    }
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    try {
      final piasters = MoneyUtils.parseToPiasters(text);
      if (!widget.allowNegative && piasters < 0) {
        return AppStrings.negativeNotAllowed;
      }
      return null;
    } catch (_) {
      return AppStrings.invalidMoney;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: TextFormField(
        controller: _controller,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        readOnly: widget.readOnly,
        autofocus: widget.autofocus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
        textInputAction: TextInputAction.next,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr, // Numbers are formatted LTR
        inputFormatters: <TextInputFormatter>[
          // Allow western & arabic digits, decimals, thousands separators, and minus
          FilteringTextInputFormatter.allow(RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9\.,\u066B\u066C\u060C\-]')),
        ],
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          suffixIcon: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              widthFactor: 1,
              child: Text(
                AppStrings.currencySymbol,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        validator: _defaultValidator,
        onChanged: _onChanged,
        onFieldSubmitted: (String val) {
          widget.onSubmittedPiasters?.call(_parseCurrent());
        },
      ),
    );
  }
}
