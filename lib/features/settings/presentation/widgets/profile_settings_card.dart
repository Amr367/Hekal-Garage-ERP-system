import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/garage_profile.dart';
import '../settings_controller.dart';

/// Settings card for managing the service center profile and branding.
class ProfileSettingsCard extends ConsumerStatefulWidget {
  const ProfileSettingsCard({super.key});

  @override
  ConsumerState<ProfileSettingsCard> createState() => _ProfileSettingsCardState();
}

class _ProfileSettingsCardState extends ConsumerState<ProfileSettingsCard> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _phoneController;
  late final TextEditingController _phone2Controller;
  late final TextEditingController _addressController;
  late final TextEditingController _taxNumberController;
  late final TextEditingController _commercialRegController;
  late final TextEditingController _footerController;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _subtitleController = TextEditingController();
    _phoneController = TextEditingController();
    _phone2Controller = TextEditingController();
    _addressController = TextEditingController();
    _taxNumberController = TextEditingController();
    _commercialRegController = TextEditingController();
    _footerController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subtitleController.dispose();
    _phoneController.dispose();
    _phone2Controller.dispose();
    _addressController.dispose();
    _taxNumberController.dispose();
    _commercialRegController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  void _syncControllers(GarageProfile profile) {
    if (!_initialized) {
      _nameController.text = profile.name;
      _subtitleController.text = profile.subtitle;
      _phoneController.text = profile.phone;
      _phone2Controller.text = profile.phone2;
      _addressController.text = profile.address;
      _taxNumberController.text = profile.taxNumber;
      _commercialRegController.text = profile.commercialReg;
      _footerController.text = profile.invoiceFooterNote;
      _initialized = true;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final current = ref.read(garageProfileProvider).value ?? const GarageProfile();
    final updated = current.copyWith(
      name: _nameController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      phone: _phoneController.text.trim(),
      phone2: _phone2Controller.text.trim(),
      address: _addressController.text.trim(),
      taxNumber: _taxNumberController.text.trim(),
      commercialReg: _commercialRegController.text.trim(),
      invoiceFooterNote: _footerController.text.trim(),
    );

    await ref.read(garageProfileProvider.notifier).saveProfile(updated);
    if (mounted) {
      AppSnackbar.showSuccess(context, AppStrings.profileSavedSuccess);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(garageProfileProvider);

    return profileAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
      error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.refresh(garageProfileProvider)),
      data: (profile) {
        _syncControllers(profile);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // ── Header ───────────────────────────────────────────────
                  Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.business, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AppStrings.garageProfileTitle,
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 2),
                            Text(
                              AppStrings.garageProfileSubtitle,
                              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text(AppStrings.save),
                      ),
                    ],
                  ),
                  const Divider(height: 36),

                  // ── Logo Section ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: profile.hasLogo
                              ? Image.file(
                                  File(profile.logoPath!),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.broken_image,
                                    size: 32,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                )
                              : const Icon(
                                  Icons.image_outlined,
                                  size: 36,
                                  color: AppColors.onSurfaceVariant,
                                ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                profile.hasLogo ? AppStrings.garageLogo : AppStrings.noLogoSelected,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                AppStrings.logoHint,
                                style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: <Widget>[
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final path = await ref
                                          .read(garageProfileProvider.notifier)
                                          .pickAndSaveLogo();
                                      if (path != null && context.mounted) {
                                        AppSnackbar.showSuccess(context, 'تم تحديث الشعار بنجاح');
                                      }
                                    },
                                    icon: const Icon(Icons.upload_file, size: 18),
                                    label: const Text(AppStrings.selectLogo),
                                  ),
                                  if (profile.hasLogo)
                                    TextButton.icon(
                                      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                                      onPressed: () async {
                                        await ref
                                            .read(garageProfileProvider.notifier)
                                            .removeLogo();
                                        if (context.mounted) {
                                          AppSnackbar.showSuccess(context, 'تم حذف الشعار');
                                        }
                                      },
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      label: const Text(AppStrings.removeLogo),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Form Inputs ───────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: AppStrings.fieldGarageName),
                          validator: (v) =>
                              (v?.trim().isEmpty ?? true) ? AppStrings.fieldRequired : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _subtitleController,
                          decoration:
                              const InputDecoration(labelText: AppStrings.fieldGarageSubtitle),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: AppStrings.fieldPhone),
                          validator: (v) =>
                              (v?.trim().isEmpty ?? true) ? AppStrings.fieldRequired : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _phone2Controller,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: AppStrings.fieldPhone2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: AppStrings.fieldAddress),
                    validator: (v) =>
                        (v?.trim().isEmpty ?? true) ? AppStrings.fieldRequired : null,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _taxNumberController,
                          decoration: const InputDecoration(labelText: AppStrings.fieldTaxNumber),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _commercialRegController,
                          decoration:
                              const InputDecoration(labelText: AppStrings.fieldCommercialReg),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _footerController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: AppStrings.fieldInvoiceFooter),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
