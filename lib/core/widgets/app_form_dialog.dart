import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../strings.dart';
import '../theme/app_colors.dart';

/// Reusable modal dialog wrapper for desktop forms.
class AppFormDialog extends StatelessWidget {
  const AppFormDialog({
    super.key,
    required this.title,
    required this.child,
    this.saveLabel = AppStrings.save,
    this.cancelLabel = AppStrings.cancel,
    this.onSave,
    this.isLoading = false,
    this.maxWidth = 560,
    this.showSaveButton = true,
  });

  final String title;
  final Widget child;
  final String saveLabel;
  final String cancelLabel;
  final VoidCallback? onSave;
  final bool isLoading;
  final double maxWidth;
  final bool showSaveButton;

  /// Convenience runner to open the dialog.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    String saveLabel = AppStrings.save,
    String cancelLabel = AppStrings.cancel,
    VoidCallback? onSave,
    double maxWidth = 560,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => AppFormDialog(
        title: title,
        saveLabel: saveLabel,
        cancelLabel: cancelLabel,
        onSave: onSave,
        maxWidth: maxWidth,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!isLoading) Navigator.of(context).pop();
        },
      },
      child: Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // ── Header ────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.divider),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: AppStrings.close,
                      onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // ── Body ──────────────────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: child,
                ),
              ),

              // ── Actions ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.divider),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                      child: Text(cancelLabel),
                    ),
                    if (showSaveButton) ...<Widget>[
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isLoading ? null : onSave,
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(saveLabel),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
