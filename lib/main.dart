import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/db/connection/connection.dart';
import 'core/db/providers.dart';
import 'core/navigation/app_router.dart';
import 'core/printing/font_loader.dart';
import 'core/strings.dart';
import 'core/theme/app_theme.dart';

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

/// Root widget configuring the Material 3 app with Arabic RTL,
/// Cairo font theme, and declarative router.
class GarageErpApp extends ConsumerStatefulWidget {
  const GarageErpApp({super.key});

  @override
  ConsumerState<GarageErpApp> createState() => _GarageErpAppState();
}

class _GarageErpAppState extends ConsumerState<GarageErpApp> {
  @override
  void initState() {
    super.initState();
    // Initialize SQLite database connection on startup
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final db = ref.read(appDatabaseProvider);
      await db.customSelect('SELECT 1').get();
      debugPrint('Database initialized at: ${DbConnection.databasePath}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: appRouter,
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
    );
  }
}
