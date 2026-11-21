import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../../core/db/connection/connection.dart';
import '../../../../core/db/providers.dart';
import '../../../../core/db/seed_data.dart';
import '../../../../core/db/services/backup_service.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/state_views.dart';
import '../settings_controller.dart';

/// Settings card for database info, backup/restore, and explorer shortcuts.
class DatabaseSettingsCard extends ConsumerWidget {
  const DatabaseSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(databaseInfoProvider);
    final backupsAsync = ref.watch(recentBackupsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.storage_outlined, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppStrings.databaseTitle,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 2),
                      Text(
                        AppStrings.databaseSubtitle,
                        style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: AppStrings.refresh,
                  onPressed: () {
                    ref.invalidate(databaseInfoProvider);
                    ref.invalidate(recentBackupsProvider);
                  },
                ),
              ],
            ),
            const Divider(height: 36),
            infoAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (e, _) => Text('خطأ في جلب بيانات الملف: $e'),
              data: (info) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          AppStrings.databasePathLabel,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            info.path,
                            style: const TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        const Text(
                          AppStrings.databaseSizeLabel,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          info.sizeFormatted,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () async {
                    await DbConnection.openDatabaseFolder();
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text(AppStrings.openDatabaseFolder),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final db = ref.read(appDatabaseProvider);
                    final loaded = await SeedData.loadIfFirstRun(db);
                    if (context.mounted) {
                      if (loaded) {
                        AppSnackbar.showSuccess(context, AppStrings.seedDataLoadedSuccess);
                      } else {
                        AppSnackbar.showWarning(context, AppStrings.seedDataAlreadyLoaded);
                      }
                      ref.invalidate(databaseInfoProvider);
                    }
                  },
                  icon: const Icon(Icons.playlist_add_check),
                  label: const Text(AppStrings.loadSeedData),
                ),
                OutlinedButton.icon(
                  onPressed: () => _runIntegrityCheck(context, ref),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text(AppStrings.integrityCheckButton),
                ),
                if (kDebugMode)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                    onPressed: () => context.go('/dev/print-test'),
                    icon: const Icon(Icons.print),
                    label: const Text(AppStrings.printTestButton),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              AppStrings.backupSectionTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              AppStrings.backupSectionSubtitle,
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: <Widget>[
                ElevatedButton.icon(
                  onPressed: () => _backupNow(context, ref),
                  icon: const Icon(Icons.save_alt),
                  label: const Text(AppStrings.backupNowButton),
                ),
                OutlinedButton.icon(
                  onPressed: () => _restoreFromPicker(context, ref),
                  icon: const Icon(Icons.settings_backup_restore),
                  label: const Text(AppStrings.restoreBackupButton),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openBackupsFolder(ref),
                  icon: const Icon(Icons.folder_special_outlined),
                  label: const Text(AppStrings.openBackupsFolder),
                ),
              ],
            ),
            const SizedBox(height: 16),
            backupsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (files) {
                if (files.isEmpty) {
                  return const Text(
                    AppStrings.noRecentBackups,
                    style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      AppStrings.recentBackupsTitle,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    ...files.take(5).map((file) {
                      final name = p.basename(file.path);
                      final modified = file.existsSync()
                          ? DateFormat('dd/MM/yyyy HH:mm').format(file.lastModifiedSync())
                          : '';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.sd_storage_outlined, color: AppColors.primary),
                        title: Text(name, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(modified, style: const TextStyle(fontSize: 12)),
                        trailing: TextButton(
                          onPressed: () => _restoreFromPath(context, ref, file.path),
                          child: const Text(AppStrings.restoreThisBackup),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
            const Divider(height: 40),
            const _StartingNumbersSection(),
          ],
        ),
      ),
    );
  }

  Future<void> _backupNow(BuildContext context, WidgetRef ref) async {
    try {
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: AppStrings.backupSaveDialogTitle,
        fileName: 'garage_backup_$stamp.sqlite',
        type: FileType.custom,
        allowedExtensions: const <String>['sqlite', 'db'],
      );
      if (savePath == null) {
        return;
      }
      final dest = (savePath.endsWith('.sqlite') || savePath.endsWith('.db'))
          ? savePath
          : '$savePath.sqlite';
      final db = ref.read(appDatabaseProvider);
      await BackupService(db).backupToFile(dest);
      await BackupService(db).createAutoBackup();
      ref.invalidate(recentBackupsProvider);
      ref.invalidate(databaseInfoProvider);
      if (context.mounted) {
        AppSnackbar.showSuccess(context, AppStrings.backupSuccess);
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, '${AppStrings.backupFailed}: $e');
      }
    }
  }

  Future<void> _openBackupsFolder(WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    final dir = await BackupService(db).backupsDirectory();
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [dir.path]);
    }
  }

  Future<void> _runIntegrityCheck(BuildContext context, WidgetRef ref) async {
    try {
      final db = ref.read(appDatabaseProvider);
      final result = await db.integrityCheck();
      if (!context.mounted) {
        return;
      }
      if (result.trim() == 'ok') {
        AppSnackbar.showSuccess(context, AppStrings.integrityOk);
      } else {
        AppSnackbar.showError(context, '${AppStrings.integrityFailed}: $result');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, '${AppStrings.integrityFailed}: $e');
      }
    }
  }

  Future<void> _restoreFromPicker(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: AppStrings.restoreOpenDialogTitle,
      type: FileType.custom,
      allowedExtensions: const <String>['sqlite', 'db'],
    );
    final path = picked?.files.single.path;
    if (path == null || !context.mounted) {
      return;
    }
    await _restoreFromPath(context, ref, path);
  }

  Future<void> _restoreFromPath(BuildContext context, WidgetRef ref, String sourcePath) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: AppStrings.restoreConfirmTitle,
      message: AppStrings.restoreConfirmMessage,
      confirmLabel: AppStrings.restoreConfirmButton,
      cancelLabel: AppStrings.cancel,
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    final allowed = await ref.read(pinAuthServiceProvider).checkPermission(context);
    if (!allowed || !context.mounted) {
      return;
    }

    final livePath = DbConnection.databasePath;
    if (livePath == null) {
      AppSnackbar.showError(context, AppStrings.backupLivePathMissing);
      return;
    }

    try {
      final db = ref.read(appDatabaseProvider);
      final backup = BackupService(db);
      try {
        await backup.createAutoBackup();
      } catch (_) {
        // Continue restore even if the safety snapshot fails.
      }

      await db.close();
      await backup.restoreDatabaseFile(
        sourcePath: sourcePath,
        destinationPath: livePath,
      );

      if (context.mounted) {
        AppSnackbar.showSuccess(context, AppStrings.restoreSuccessRestart);
      }

      await Future<void>.delayed(const Duration(milliseconds: 600));
      exit(0);
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, '${AppStrings.restoreFailed}: $e');
      }
    }
  }
}

class _StartingNumbersSection extends ConsumerStatefulWidget {
  const _StartingNumbersSection();

  @override
  ConsumerState<_StartingNumbersSection> createState() => _StartingNumbersSectionState();
}

class _StartingNumbersSectionState extends ConsumerState<_StartingNumbersSection> {
  final TextEditingController _invoiceCtrl = TextEditingController(text: '1');
  final TextEditingController _workOrderCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _invoiceCtrl.dispose();
    _workOrderCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    final invoice = await repo.getWithDefault('starting_invoice_number', '1');
    final workOrder = await repo.getWithDefault('starting_work_order_number', '1');
    if (!mounted) {
      return;
    }
    setState(() {
      _invoiceCtrl.text = invoice;
      _workOrderCtrl.text = workOrder;
    });
  }

  Future<void> _save() async {
    final invoice = int.tryParse(_invoiceCtrl.text.trim());
    final workOrder = int.tryParse(_workOrderCtrl.text.trim());
    if (invoice == null || invoice < 1 || workOrder == null || workOrder < 1) {
      AppSnackbar.showError(context, AppStrings.invalidStartingNumber);
      return;
    }
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setInt('starting_invoice_number', invoice);
    await repo.setInt('starting_work_order_number', workOrder);
    if (mounted) {
      AppSnackbar.showSuccess(context, AppStrings.startingNumbersSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          AppStrings.startingNumbersTitle,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          AppStrings.startingNumbersSubtitle,
          style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _invoiceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: AppStrings.startingInvoiceNumberLabel,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _workOrderCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: AppStrings.startingWorkOrderNumberLabel,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _save,
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      ],
    );
  }
}
