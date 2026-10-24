import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_erp/core/db/connection/connection.dart';
import 'package:garage_erp/core/db/database.dart';
import 'package:garage_erp/core/db/providers.dart';
import 'package:garage_erp/core/strings.dart';
import 'package:garage_erp/main.dart';

void main() {
  testWidgets('app shell boots into RTL Dashboard with 9 navigation destinations', (
    WidgetTester tester,
  ) async {
    // Provide in-memory test database
    final testDb = AppDatabase(DbConnection.openInMemory());

    // Set desktop window test size (1280x800)
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      testDb.close();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
        ],
        child: const GarageErpApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Check Dashboard title & metrics
    expect(find.text(AppStrings.dashboardTitle), findsOneWidget);
    expect(find.text(AppStrings.metricTodaySales), findsOneWidget);
    expect(find.text(AppStrings.metricOpenWorkOrders), findsOneWidget);
    expect(find.text(AppStrings.metricLowStock), findsOneWidget);
    expect(find.text(AppStrings.metricReceivables), findsOneWidget);

    // Check Navigation sidebar items
    expect(find.text(AppStrings.navDashboard), findsOneWidget);
    expect(find.text(AppStrings.navWorkOrders), findsOneWidget);
    expect(find.text(AppStrings.navInvoices), findsOneWidget);
    expect(find.text(AppStrings.navCustomers), findsOneWidget);
    expect(find.text(AppStrings.navInventory), findsOneWidget);
    expect(find.text(AppStrings.navPurchases), findsOneWidget);
    expect(find.text(AppStrings.navStockCount), findsOneWidget);
    expect(find.text(AppStrings.navReports), findsOneWidget);
    expect(find.text(AppStrings.navSettings), findsOneWidget);
  });

  testWidgets('app layout renders without overflow at 1100x700 minimum window size', (
    WidgetTester tester,
  ) async {
    final testDb = AppDatabase(DbConnection.openInMemory());
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      testDb.close();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
        ],
        child: const GarageErpApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify zero rendering exceptions
    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.dashboardTitle), findsOneWidget);
  });
}
