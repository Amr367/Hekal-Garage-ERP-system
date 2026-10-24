import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../money/money.dart';
import '../strings.dart';
import '../theme/app_colors.dart';

/// Form field for quantity inputs (supports integers and decimals up to 3 places).
class QtyField extends StatefulWidget {
  const QtyField({
    super.key,
    this.label,
    this.hintText = '1',
    this.initialQty,
    this.onChangedQty,
    this.onSubmittedQty,
    this.controller,
    this.focusNode,
    this.validator,
    this.enabled = true,
    this.readOnly = false,
    this.unitSuffix,
    this.autofocus = false,
  });

  final String? label;
  final String hintText;
  final double? initialQty;
  final ValueChanged<double?>? onChangedQty;
  final ValueChanged<double?>? onSubmittedQty;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool readOnly;
  final String? unitSuffix;
  final bool autofocus;

  @override
  State<QtyField> createState() => _QtyFieldState();
}

class _QtyFieldState extends State<QtyField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    if (widget.initialQty != null) {
      _controller.text = _formatQty(widget.initialQty!);
    }
  }

  @override
  void didUpdateWidget(QtyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQty != oldWidget.initialQty &&
        widget.initialQty != null &&
        widget.controller == null) {
      final current = _parseCurrent();
      if (current != widget.initialQty) {
        _controller.text = _formatQty(widget.initialQty!);
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

  static String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    // Up to 3 decimal places without trailing zeroes
    return qty.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  double? _parseCurrent() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return null;
    final normalized = MoneyUtils.normalizeDigits(raw)
        .replaceAll('،', '.')
        .replaceAll('٫', '.')
        .replaceAll(',', '');

    final value = double.tryParse(normalized);
    if (value == null || value < 0) return null;

    // Check at most 3 decimal places
    final parts = normalized.split('.');
    if (parts.length > 1 && parts[1].length > 3) {
      return null;
    }
    return value;
  }

  void _onChanged(String val) {
    widget.onChangedQty?.call(_parseCurrent());
  }

  String? _defaultValidator(String? value) {
    if (widget.validator != null) {
      return widget.validator!(value);
    }
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;

    final normalized = MoneyUtils.normalizeDigits(raw)
        .replaceAll('،', '.')
        .replaceAll('٫', '.')
        .replaceAll(',', '');

    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed < 0) {
      return AppStrings.invalidQty;
    }

    final parts = normalized.split('.');
    if (parts.length > 1 && parts[1].length > 3) {
      return AppStrings.invalidQty;
    }

    return null;
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
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9\.,\u066B\u066C\u060C]')),
        ],
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          suffixIcon: widget.unitSuffix != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      widget.unitSuffix!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              : null,
        ),
        validator: _defaultValidator,
        onChanged: _onChanged,
        onFieldSubmitted: (String val) {
          widget.onSubmittedQty?.call(_parseCurrent());
        },
      ),
    );
  }
}
