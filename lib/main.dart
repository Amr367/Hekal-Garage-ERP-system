import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/db/connection/connection.dart';
import 'core/db/providers.dart';
import 'core/db/seed_data.dart';
import 'core/printing/font_loader.dart';
import 'core/strings.dart';
import 'core/theme/app_theme.dart';
import 'features/dev/print_test_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const WindowOptions windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(1100, 700),
    center: true,
    title: AppStrings.appTitle,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Load Cairo fonts for PDF generation.
  await PdfFontLoader.init();

  runApp(const ProviderScope(child: GarageErpApp()));
}

class GarageErpApp extends StatelessWidget {
  const GarageErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const <Locale>[Locale('ar', 'EG')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (BuildContext context, Widget? child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const BootstrapPage(),
    );
  }
}

class BootstrapPage extends ConsumerStatefulWidget {
  const BootstrapPage({super.key});

  @override
  ConsumerState<BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends ConsumerState<BootstrapPage> {
  String _status = '';

  @override
  void initState() {
    super.initState();
    // Log database path at startup
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final db = ref.read(appDatabaseProvider);
      // Trigger lazy connection opening to establish path
      await db.customSelect('SELECT 1').get();
      final path = DbConnection.databasePath;
      debugPrint('Database initialized at: $path');
    });
  }

  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.appTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    AppStrings.bootstrapHeadline,
                    style: textTheme.headlineSmall?.copyWith(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.bootstrapBody,
                    style: textTheme.bodyLarge,
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppStrings.bootstrapPhaseLabel,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.currencyLabel,
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.rtlProofLabel,
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.right,
                  ),
                  if (_status.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      _status,
                      style: textTheme.bodySmall?.copyWith(color: colors.secondary),
                      textAlign: TextAlign.right,
                    ),
                  ],
                  // Debug actions
                  if (kDebugMode) ...<Widget>[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PrintTestPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.print),
                        label: const Text(AppStrings.printTestButton),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final db = ref.read(appDatabaseProvider);
                          final loaded = await SeedData.loadIfFirstRun(db);
                          _showSnack(
                            loaded
                                ? AppStrings.seedDataLoadedSuccess
                                : AppStrings.seedDataAlreadyLoaded,
                          );
                        },
                        icon: const Icon(Icons.playlist_add_check),
                        label: const Text(AppStrings.loadSeedData),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: TextButton.icon(
                        onPressed: () async {
                          await DbConnection.openDatabaseFolder();
                          setState(() {
                            _status = 'مسار القاعدة: ${DbConnection.databasePath ?? "جاري الفتح..."}';
                          });
                        },
                        icon: const Icon(Icons.folder_open),
                        label: const Text(AppStrings.openDatabaseFolder),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
