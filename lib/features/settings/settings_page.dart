import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_scaffold.dart';
import 'presentation/widgets/database_settings_card.dart';
import 'presentation/widgets/network_settings_card.dart';
import 'presentation/widgets/printer_settings_card.dart';
import 'presentation/widgets/profile_settings_card.dart';
import 'presentation/widgets/security_settings_card.dart';
import 'presentation/widgets/services_settings_card.dart';

/// Complete Settings screen with tabs for Profile, Services, Printers, Security, and Database.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.settingsTitle,
      subtitle: AppStrings.settingsSubtitle,
      padding: EdgeInsets.zero,
      body: DefaultTabController(
        length: 6,
        child: Column(
          children: <Widget>[
            // ── Tabs Navigation Bar ─────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.divider, width: 1),
                ),
              ),
              child: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.onSurfaceVariant,
                labelStyle: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: <Widget>[
                  Tab(
                    icon: Icon(Icons.business_outlined, size: 20),
                    text: AppStrings.tabProfile,
                  ),
                  Tab(
                    icon: Icon(Icons.handyman_outlined, size: 20),
                    text: AppStrings.tabServices,
                  ),
                  Tab(
                    icon: Icon(Icons.print_outlined, size: 20),
                    text: AppStrings.tabPrinters,
                  ),
                  Tab(
                    icon: Icon(Icons.security_outlined, size: 20),
                    text: AppStrings.tabSecurity,
                  ),
                  Tab(
                    icon: Icon(Icons.storage_outlined, size: 20),
                    text: AppStrings.tabDatabase,
                  ),
                  Tab(
                    icon: Icon(Icons.lan_outlined, size: 20),
                    text: 'الربط والشبكة (LAN)',
                  ),
                ],
              ),
            ),

            // ── Tab Views ───────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  // Profile Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: const ProfileSettingsCard(),
                      ),
                    ),
                  ),

                  // Services & Labor Catalog Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: const ServicesSettingsCard(),
                      ),
                    ),
                  ),

                  // Printers Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: const PrinterSettingsCard(),
                      ),
                    ),
                  ),

                  // Security & PIN Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: const SecuritySettingsCard(),
                      ),
                    ),
                  ),

                  // Database Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: const DatabaseSettingsCard(),
                      ),
                    ),
                  ),

                  // Network & Multi-device Sync Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: const NetworkSettingsCard(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
