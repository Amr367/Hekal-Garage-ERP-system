import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../settings_controller.dart';
import 'set_pin_dialog.dart';

/// Settings card for managing 4-digit PIN security and protected actions.
class SecuritySettingsCard extends ConsumerWidget {
  const SecuritySettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securityAsync = ref.watch(securitySettingsProvider);
    final authService = ref.watch(pinAuthServiceProvider);

    return securityAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
      error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.refresh(securitySettingsProvider)),
      data: (settings) {
        final bool isProtected = settings.hasPin && settings.isPinEnabled;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // ── Header ─────────────────────────────────────────────────
                Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.security, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            AppStrings.securityTitle,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 2),
                          Text(
                            AppStrings.securitySubtitle,
                            style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 36),

                // ── PIN Status Banner ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isProtected ? AppColors.successContainer : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isProtected ? AppColors.success.withValues(alpha: 0.4) : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        isProtected ? Icons.lock_outline : Icons.lock_open_outlined,
                        color: isProtected ? AppColors.success : AppColors.onSurfaceVariant,
                        size: 26,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              AppStrings.pinStatusLabel,
                              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isProtected ? AppStrings.pinEnabled : AppStrings.pinDisabled,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isProtected ? AppColors.success : AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          if (!settings.hasPin)
                            ElevatedButton.icon(
                              onPressed: () async {
                                final pin = await SetPinDialog.show(
                                  context: context,
                                  hasExistingPin: false,
                                  authService: authService,
                                );
                                if (pin != null) {
                                  await ref.read(securitySettingsProvider.notifier).setPin(pin);
                                  if (context.mounted) {
                                    AppSnackbar.showSuccess(context, AppStrings.pinSetSuccess);
                                  }
                                }
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text(AppStrings.setPinButton),
                            )
                          else ...<Widget>[
                            OutlinedButton.icon(
                              onPressed: () async {
                                final pin = await SetPinDialog.show(
                                  context: context,
                                  hasExistingPin: true,
                                  authService: authService,
                                );
                                if (pin != null) {
                                  await ref.read(securitySettingsProvider.notifier).setPin(pin);
                                  if (context.mounted) {
                                    AppSnackbar.showSuccess(context, AppStrings.pinSetSuccess);
                                  }
                                }
                              },
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text(AppStrings.changePinButton),
                            ),
                            if (settings.isPinEnabled)
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                                onPressed: () async {
                                  final verified = await authService.checkPermission(
                                    context,
                                    prompt: 'أدخل رمز PIN الحالي لإلغاء تفعيل الحماية',
                                  );
                                  if (verified) {
                                    await ref
                                        .read(securitySettingsProvider.notifier)
                                        .togglePinEnabled(false);
                                    if (context.mounted) {
                                      AppSnackbar.showSuccess(context, AppStrings.pinDisabledSuccess);
                                    }
                                  }
                                },
                                icon: const Icon(Icons.lock_open, size: 18),
                                label: const Text(AppStrings.disablePinButton),
                              )
                            else
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await ref
                                      .read(securitySettingsProvider.notifier)
                                      .togglePinEnabled(true);
                                  if (context.mounted) {
                                    AppSnackbar.showSuccess(context, 'تم تفعيل حماية PIN');
                                  }
                                },
                                icon: const Icon(Icons.lock, size: 18),
                                label: const Text('تفعيل الـ PIN'),
                              ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final valid = await authService.checkPermission(context);
                                if (valid && context.mounted) {
                                  AppSnackbar.showSuccess(context, AppStrings.pinVerifiedSuccess);
                                }
                              },
                              icon: const Icon(Icons.verified_user_outlined, size: 18),
                              label: const Text(AppStrings.testPinButton),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Protected Actions List ─────────────────────────────────
                const Text(
                  AppStrings.protectedOperationsTitle,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 12),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    AppStrings.requirePinDiscountLabel,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  value: settings.requirePinDiscount,
                  onChanged: settings.isPinEnabled
                      ? (val) {
                          ref.read(securitySettingsProvider.notifier).saveFlags(
                                requireDiscount: val,
                                requireCostPrice: settings.requirePinCostPrice,
                                requireStockAdjust: settings.requirePinStockAdjust,
                                requireVoidInvoice: settings.requirePinVoidInvoice,
                              );
                        }
                      : null,
                ),
                const Divider(),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    AppStrings.requirePinCostPriceLabel,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  value: settings.requirePinCostPrice,
                  onChanged: settings.isPinEnabled
                      ? (val) {
                          ref.read(securitySettingsProvider.notifier).saveFlags(
                                requireDiscount: settings.requirePinDiscount,
                                requireCostPrice: val,
                                requireStockAdjust: settings.requirePinStockAdjust,
                                requireVoidInvoice: settings.requirePinVoidInvoice,
                              );
                        }
                      : null,
                ),
                const Divider(),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    AppStrings.requirePinStockAdjustLabel,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  value: settings.requirePinStockAdjust,
                  onChanged: settings.isPinEnabled
                      ? (val) {
                          ref.read(securitySettingsProvider.notifier).saveFlags(
                                requireDiscount: settings.requirePinDiscount,
                                requireCostPrice: settings.requirePinCostPrice,
                                requireStockAdjust: val,
                                requireVoidInvoice: settings.requirePinVoidInvoice,
                              );
                        }
                      : null,
                ),
                const Divider(),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    AppStrings.requirePinVoidInvoiceLabel,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  value: settings.requirePinVoidInvoice,
                  onChanged: settings.isPinEnabled
                      ? (val) {
                          ref.read(securitySettingsProvider.notifier).saveFlags(
                                requireDiscount: settings.requirePinDiscount,
                                requireCostPrice: settings.requirePinCostPrice,
                                requireStockAdjust: settings.requirePinStockAdjust,
                                requireVoidInvoice: val,
                              );
                        }
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
