import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../money/money.dart';
import '../strings.dart';
import '../theme/app_colors.dart';

/// 4-digit PIN dialog stub for protected actions.
/// Converts Arabic-Indic digits to Western digits and validates length = 4.
class PinDialog extends StatefulWidget {
  const PinDialog({
    super.key,
    this.title = AppStrings.enterPinTitle,
    this.prompt = AppStrings.enterPinPrompt,
  });

  final String title;
  final String prompt;

  /// Shows the PIN dialog and returns the 4-digit normalized PIN string,
  /// or null if dismissed/cancelled.
  static Future<String?> show({
    required BuildContext context,
    String title = AppStrings.enterPinTitle,
    String prompt = AppStrings.enterPinPrompt,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) => PinDialog(title: title, prompt: prompt),
    );
  }

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_errorText != null) {
      setState(() {
        _errorText = null;
      });
    }
    final text = MoneyUtils.normalizeDigits(_controller.text.trim());
    if (text.length == 4) {
      _submit(text);
    }
  }

  void _submit([String? pin]) {
    final text = pin ?? MoneyUtils.normalizeDigits(_controller.text.trim());
    if (text.length != 4 || int.tryParse(text) == null) {
      setState(() {
        _errorText = AppStrings.pinInvalid;
      });
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): _submit,
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(null),
      },
      child: AlertDialog(
        title: Row(
          children: <Widget>[
            const Icon(Icons.lock_outline, color: AppColors.primary, size: 24),
            const SizedBox(width: 12),
            Text(widget.title),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.prompt,
                style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                obscureText: true,
                obscuringCharacter: '●',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 12,
                  fontWeight: FontWeight.w700,
                ),
                maxLength: 4,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9]')),
                ],
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  errorText: _errorText,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        actions: <Widget>[
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text(AppStrings.cancel),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _submit,
            child: const Text(AppStrings.confirm),
          ),
        ],
      ),
    );
  }
}
