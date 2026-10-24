import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_erp/core/db/connection/connection.dart';
import 'package:garage_erp/core/db/database.dart';
import 'package:garage_erp/core/db/providers.dart';
import 'package:garage_erp/core/db/repositories/settings_repository.dart';
import 'package:garage_erp/core/strings.dart';
import 'package:garage_erp/core/theme/app_theme.dart';
import 'package:garage_erp/features/settings/data/pin_auth_service.dart';
import 'package:garage_erp/features/settings/domain/garage_profile.dart';
import 'package:garage_erp/features/settings/settings_page.dart';

Widget _wrapWithApp(Widget child, AppDatabase db) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      settingsRepositoryProvider.overrideWithValue(DriftSettingsRepository(db)),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const <Locale>[Locale('ar', 'EG')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PinAuthService Unit Tests (Rule R12)', () {
    late AppDatabase db;
    late SettingsRepository settingsRepo;
    late PinAuthService authService;

    setUp(() {
      db = AppDatabase(DbConnection.openInMemory());
      settingsRepo = DriftSettingsRepository(db);
      authService = PinAuthService(settingsRepo);
    });

    tearDown(() async {
      await db.close();
    });

    test('generateSalt produces non-empty unique hex strings', () {
      final salt1 = PinAuthService.generateSalt();
      final salt2 = PinAuthService.generateSalt();

      expect(salt1.length, equals(32));
      expect(salt2.length, equals(32));
      expect(salt1, isNot(equals(salt2)));
    });

    test('hashPin produces deterministic SHA-256 and normalizes Arabic-Indic digits', () {
      const salt = 'abcdef1234567890abcdef1234567890';
      final hashWestern = PinAuthService.hashPin('1234', salt);
      final hashArabic = PinAuthService.hashPin('١٢٣٤', salt);

      expect(hashWestern, equals(hashArabic));
      expect(hashWestern.length, equals(64));
    });

    test('setPin saves salted hash and rejects invalid pins', () async {
      expect(await authService.hasPin(), isFalse);
      expect(await authService.isPinEnabled(), isFalse);

      // Rejects non-4 digits
      expect(() => authService.setPin('12'), throwsArgumentError);
      expect(() => authService.setPin('12345'), throwsArgumentError);
      expect(() => authService.setPin('abcd'), throwsArgumentError);

      // Successfully sets 4 digits
      await authService.setPin('1234');
      expect(await authService.hasPin(), isTrue);
      expect(await authService.isPinEnabled(), isTrue);

      // Never stores plain text PIN in settings
      final allSettings = await settingsRepo.getAll();
      expect(allSettings.values, isNot(contains('1234')));
      expect(allSettings.containsKey(PinAuthService.keyPinHash), isTrue);
      expect(allSettings.containsKey(PinAuthService.keyPinSalt), isTrue);
    });

    test('verifyPin accepts correct PIN and Arabic digits, rejects wrong PIN', () async {
      await authService.setPin('5678');

      expect(await authService.verifyPin('5678'), isTrue);
      expect(await authService.verifyPin('٥٦٧٨'), isTrue); // Arabic-Indic digits
      expect(await authService.verifyPin('1234'), isFalse);
      expect(await authService.verifyPin('0000'), isFalse);
    });

    test('disablePin and enablePin toggle isPinEnabled while retaining PIN hash', () async {
      await authService.setPin('9876');
      expect(await authService.isPinEnabled(), isTrue);

      await authService.disablePin();
      expect(await authService.isPinEnabled(), isFalse);
      expect(await authService.hasPin(), isTrue);

      await authService.enablePin();
      expect(await authService.isPinEnabled(), isTrue);
      expect(await authService.verifyPin('9876'), isTrue);
    });
  });

  group('GarageProfile Domain and Persistence Tests', () {
    late AppDatabase db;
    late SettingsRepository settingsRepo;

    setUp(() {
      db = AppDatabase(DbConnection.openInMemory());
      settingsRepo = DriftSettingsRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('default GarageProfile values match AppStrings', () {
      const profile = GarageProfile();
      expect(profile.name, equals(AppStrings.garageNameDefault));
      expect(profile.subtitle, equals(AppStrings.garageSubtitleDefault));
      expect(profile.invoiceFooterNote, equals(AppStrings.invoiceFooterNoteDefault));
      expect(profile.hasLogo, isFalse);
    });

    test('stores and loads profile values from SettingsRepository', () async {
      await settingsRepo.set('garage_name', 'ورشة النصر للصيانة');
      await settingsRepo.set('garage_phone', '01234567890');

      final name = await settingsRepo.getWithDefault('garage_name', '');
      final phone = await settingsRepo.getWithDefault('garage_phone', '');

      expect(name, equals('ورشة النصر للصيانة'));
      expect(phone, equals('01234567890'));
    });

    test('copyWith updates values properly and supports clearLogo', () {
      const profile = GarageProfile(logoPath: '/tmp/logo.png');
      expect(profile.hasLogo, isTrue);

      final updated = profile.copyWith(name: 'المركز الحديث', clearLogo: true);
      expect(updated.name, equals('المركز الحديث'));
      expect(updated.hasLogo, isFalse);
      expect(updated.logoPath, isNull);
    });
  });

  group('SettingsPage Widget Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(DbConnection.openInMemory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('renders all 4 tabs and displays Profile card by default', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithApp(const SettingsPage(), db));
      await tester.pumpAndSettle();

      // Check Tabs
      expect(find.text(AppStrings.tabProfile), findsOneWidget);
      expect(find.text(AppStrings.tabPrinters), findsOneWidget);
      expect(find.text(AppStrings.tabSecurity), findsOneWidget);
      expect(find.text(AppStrings.tabDatabase), findsOneWidget);

      // Check Profile card elements
      expect(find.text(AppStrings.garageProfileTitle), findsOneWidget);
      expect(find.text(AppStrings.fieldGarageName), findsOneWidget);
      expect(find.text(AppStrings.fieldPhone), findsOneWidget);
      expect(find.text(AppStrings.fieldAddress), findsOneWidget);
    });

    testWidgets('switching to Security tab renders PIN status and protected actions', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithApp(const SettingsPage(), db));
      await tester.pumpAndSettle();

      // Switch to Security Tab
      await tester.tap(find.text(AppStrings.tabSecurity));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.securityTitle), findsNWidgets(2)); // Tab + Card Header
      expect(find.text(AppStrings.pinStatusLabel), findsOneWidget);
      expect(find.text(AppStrings.protectedOperationsTitle), findsOneWidget);
      expect(find.text(AppStrings.requirePinDiscountLabel), findsOneWidget);
      expect(find.text(AppStrings.requirePinCostPriceLabel), findsOneWidget);
      expect(find.text(AppStrings.requirePinStockAdjustLabel), findsOneWidget);
      expect(find.text(AppStrings.requirePinVoidInvoiceLabel), findsOneWidget);
    });

    testWidgets('switching to Database tab renders database path and action buttons', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithApp(const SettingsPage(), db));
      await tester.pumpAndSettle();

      // Switch to Database Tab
      await tester.tap(find.text(AppStrings.tabDatabase));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.databaseTitle), findsNWidgets(2)); // Tab + Card Header
      expect(find.text(AppStrings.databasePathLabel), findsOneWidget);
      expect(find.text(AppStrings.openDatabaseFolder), findsOneWidget);
      expect(find.text(AppStrings.loadSeedData), findsOneWidget);
    });
  });
}
