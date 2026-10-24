import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/db/connection/connection.dart';
import '../../../../core/db/providers.dart';
import '../../../../core/db/seed_data.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../settings_controller.dart';

/// Settings card for database info, maintenance, and explorer shortcuts.
class DatabaseSettingsCard extends ConsumerWidget {
  const DatabaseSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(databaseInfoProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Header ─────────────────────────────────────────────────────
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
                  onPressed: () => ref.invalidate(databaseInfoProvider),
                ),
              ],
            ),
            const Divider(height: 36),

            // ── Database Info ───────────────────────────────────────────────
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

            // ── Maintenance Actions ─────────────────────────────────────────
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
                if (kDebugMode)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                    onPressed: () => context.go('/dev/print-test'),
                    icon: const Icon(Icons.print),
                    label: const Text(AppStrings.printTestButton),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
