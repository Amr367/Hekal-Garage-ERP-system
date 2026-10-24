import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../strings.dart';
import '../theme/app_colors.dart';

/// Desktop confirmation dialog with keyboard shortcuts (Enter to confirm, Esc to cancel).
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = AppStrings.confirm,
    this.cancelLabel = AppStrings.cancel,
    this.isDestructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  /// Shows the confirmation dialog and returns true if confirmed.
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = AppStrings.confirm,
    String cancelLabel = AppStrings.cancel,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  /// Convenience helper for destructive delete operations.
  static Future<bool> destructive({
    required BuildContext context,
    String title = AppStrings.confirmDelete,
    String message = AppStrings.confirmDeleteWarning,
    String confirmLabel = AppStrings.delete,
    String cancelLabel = AppStrings.cancel,
  }) {
    return show(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): () => Navigator.of(context).pop(true),
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(false),
      },
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          title: Row(
            children: <Widget>[
              Icon(
                isDestructive ? Icons.warning_rounded : Icons.help_outline_rounded,
                color: isDestructive ? AppColors.danger : AppColors.primary,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              message,
              style: const TextStyle(height: 1.5, fontSize: 15),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actions: <Widget>[
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: isDestructive
                  ? ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: AppColors.onDanger,
                    )
                  : null,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
  }
}
