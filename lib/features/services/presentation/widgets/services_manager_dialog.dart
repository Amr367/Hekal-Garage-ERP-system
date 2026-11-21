import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../services_controller.dart';
import 'service_form_dialog.dart';

/// Comprehensive modal dialog for managing the Garage Services & Labor pricing catalog.
class ServicesManagerDialog extends StatelessWidget {
  const ServicesManagerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ServicesManagerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 800),
        child: Column(
          children: [
            // ── Dialog Header ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.handyman_outlined, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'دليل الخدمات والمصنعيات',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        Text(
                          'عرض وتعديل أسعار الخدمات والمصنعيات وإضافة خدمات جديدة للمركز',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Body Content ────────────────────────────────────────────────
            const Expanded(
              child: ServicesManagerView(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable services management view (embedded in dialog and in Settings tab).
class ServicesManagerView extends ConsumerWidget {
  const ServicesManagerView({super.key});

  Future<void> _quickEditPrice(BuildContext context, WidgetRef ref, Service service) async {
    int updatedPiasters = service.defaultPrice;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل سعر: ${service.name}'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MoneyField(
                initialPiasters: service.defaultPrice,
                label: 'السعر الجديد (جنيه)',
                onChangedPiasters: (p) => updatedPiasters = p ?? 0,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حفظ السعر'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(servicesActionsProvider).updatePrice(
              id: service.id,
              newPricePiasters: updatedPiasters,
            );
        if (context.mounted) {
          AppSnackbar.showSuccess(context, 'تم تحديث سعر الخدمة بنجاح.');
        }
      } catch (e) {
        if (context.mounted) {
          AppSnackbar.showError(context, 'فشل تحديث السعر: $e');
        }
      }
    }
  }

  Future<void> _deleteService(BuildContext context, WidgetRef ref, Service service) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'تعطيل الخدمة',
      message: 'هل أنت متأكد من تعطيل خدمة "${service.name}"؟ لن تظهر في قوائم إضافة الخدمات الجديدة.',
      isDestructive: true,
      confirmLabel: 'تعطيل',
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(servicesActionsProvider).deactivate(service.id);
        if (context.mounted) {
          AppSnackbar.showSuccess(context, 'تم تعطيل الخدمة بنجاح.');
        }
      } catch (e) {
        if (context.mounted) {
          AppSnackbar.showError(context, 'فشل تعطيل الخدمة: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesListProvider);

    return Column(
      children: [
        // ── Controls Bar ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.surfaceVariant,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SearchField(
                  hintText: 'بحث في الخدمات والمصنعيات...',
                  onChanged: (q) => ref.read(servicesSearchQueryProvider.notifier).setQuery(q),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => ServiceFormDialog.show(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة خدمة جديدة'),
              ),
            ],
          ),
        ),

        // ── Services Table ──────────────────────────────────────────────────
        Expanded(
          child: servicesAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => ErrorState(
              message: 'فشل تحميل الخدمات: $err',
              onRetry: () => ref.invalidate(servicesListProvider),
            ),
            data: (services) {
              if (services.isEmpty) {
                return const EmptyState(
                  icon: Icons.handyman_outlined,
                  title: 'لا توجد خدمات مطابقة للبحث',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: services.length,
                separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                itemBuilder: (ctx, index) {
                  final service = services[index];

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: service.isActive ? AppColors.border : AppColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Service Icon & Active indicator
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: service.isActive
                                ? AppColors.primaryContainer.withValues(alpha: 0.5)
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.handyman_outlined,
                            size: 18,
                            color: service.isActive ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Service Name
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                service.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: service.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                                  decoration: service.isActive ? null : TextDecoration.lineThrough,
                                ),
                              ),
                              if (!service.isActive)
                                const Text(
                                  'خدمة غير نشطة (معطلة)',
                                  style: TextStyle(fontSize: 11, color: AppColors.danger),
                                ),
                            ],
                          ),
                        ),

                        // Price with quick edit badge
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _quickEditPrice(context, ref, service),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_note_outlined, size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  MoneyUtils.formatPounds(service.defaultPrice),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Actions Menu / Buttons
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'تعديل البيانات والسعر',
                          onPressed: () => ServiceFormDialog.show(context, service: service),
                        ),

                        if (service.isActive)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                            tooltip: 'تعطيل الخدمة',
                            onPressed: () => _deleteService(context, ref, service),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                            tooltip: 'تفعيل الخدمة',
                            onPressed: () => ref.read(servicesActionsProvider).toggleActive(id: service.id, isActive: true),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
