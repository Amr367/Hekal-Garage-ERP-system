import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garage_erp/core/db/database.dart';
import 'package:garage_erp/core/db/providers.dart';
import 'package:garage_erp/core/db/repositories/services_repository.dart';
import 'package:garage_erp/core/theme/app_theme.dart';
import 'package:garage_erp/features/services/presentation/widgets/service_form_dialog.dart';
import 'package:garage_erp/features/services/presentation/widgets/services_manager_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ServicesRepository servicesRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    servicesRepo = DriftServicesRepository(db);

    // Seed test services
    await db.into(db.services).insert(
      const ServicesCompanion(
        name: drift.Value('ضبط زوايا وترصيص'),
        defaultPrice: drift.Value(25000), // 250.00 EGP
        isActive: drift.Value(true),
      ),
    );
    await db.into(db.services).insert(
      const ServicesCompanion(
        name: drift.Value('تغيير زيت وفلتر'),
        defaultPrice: drift.Value(10000), // 100.00 EGP
        isActive: drift.Value(true),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp({required Widget child}) {
    return ProviderScope(
      overrides: [
        servicesRepositoryProvider.overrideWithValue(servicesRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('ServicesRepository Unit Tests', () {
    test('getAll returns active seeded services', () async {
      final list = await servicesRepo.getAll(onlyActive: true);
      expect(list.length, equals(2));
      expect(list.first.name, equals('ضبط زوايا وترصيص'));
      expect(list.first.defaultPrice, equals(25000));
    });

    test('insertService adds a new service with price in piasters', () async {
      final newId = await servicesRepo.insertService(
        const ServicesCompanion(
          name: drift.Value('فحص شاسيه وعفشة'),
          defaultPrice: drift.Value(15000),
          isActive: drift.Value(true),
        ),
      );

      final service = await servicesRepo.getById(newId);
      expect(service.name, equals('فحص شاسيه وعفشة'));
      expect(service.defaultPrice, equals(15000));
    });

    test('updatePrice modifies default price in piasters', () async {
      final all = await servicesRepo.getAll();
      final target = all.first;

      await servicesRepo.updatePrice(target.id, 35000); // 350.00 EGP

      final updated = await servicesRepo.getById(target.id);
      expect(updated.defaultPrice, equals(35000));
    });

    test('deactivate sets isActive to false', () async {
      final all = await servicesRepo.getAll();
      final target = all.first;

      await servicesRepo.deactivate(target.id);

      final updated = await servicesRepo.getById(target.id);
      expect(updated.isActive, isFalse);

      final onlyActive = await servicesRepo.getAll(onlyActive: true);
      expect(onlyActive.any((s) => s.id == target.id), isFalse);
    });
  });

  group('Services UI Widget Tests', () {
    testWidgets('ServicesManagerView renders service list and prices', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(child: const ServicesManagerView()));
      await tester.pumpAndSettle();

      expect(find.text('إضافة خدمة جديدة'), findsOneWidget);
      expect(find.text('ضبط زوايا وترصيص'), findsOneWidget);
      expect(find.text('تغيير زيت وفلتر'), findsOneWidget);
    });

    testWidgets('ServiceFormDialog opens and validates required name', (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(child: const ServiceFormDialog()));
      await tester.pumpAndSettle();

      expect(find.text('إضافة خدمة ومصنعية جديدة'), findsOneWidget);

      // Try save empty
      await tester.tap(find.text('إضافة الخدمة'));
      await tester.pumpAndSettle();

      expect(find.text('يرجى كتابة اسم الخدمة'), findsOneWidget);
    });
  });
}
