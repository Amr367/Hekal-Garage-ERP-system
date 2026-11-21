import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection/connection.dart';
import 'database.dart';
import 'repositories/categories_repository.dart';
import 'repositories/customers_repository.dart';
import 'repositories/employees_repository.dart';
import 'repositories/expenses_repository.dart';
import 'repositories/invoices_repository.dart';
import 'repositories/items_repository.dart';
import 'repositories/purchases_repository.dart';
import 'repositories/reports_repository.dart';
import 'repositories/services_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/stock_count_repository.dart';
import 'repositories/suppliers_repository.dart';
import 'repositories/vehicles_repository.dart';
import 'repositories/work_orders_repository.dart';
import 'services/numbering_service.dart';
import 'services/network_db_service.dart';
import 'services/stock_service.dart';

/// Database provider. Automatically closes the database when disposed.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(DbConnection.openConnection());

  // Launch embedded LAN server if running as main server/standalone
  NetworkDbService.instance.loadConfig().then((config) {
    if (config.isServer) {
      NetworkDbService.instance.startServer(db, port: config.port);
    }
  });

  ref.onDispose(() {
    NetworkDbService.instance.stopServer();
    db.close();
  });

  return db;
});

/// Repositories providers.
final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return DriftCustomersRepository(ref.watch(appDatabaseProvider));
});

final vehiclesRepositoryProvider = Provider<VehiclesRepository>((ref) {
  return DriftVehiclesRepository(ref.watch(appDatabaseProvider));
});

final servicesRepositoryProvider = Provider<ServicesRepository>((ref) {
  return DriftServicesRepository(ref.watch(appDatabaseProvider));
});

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return DriftCategoriesRepository(ref.watch(appDatabaseProvider));
});

final itemsRepositoryProvider = Provider<ItemsRepository>((ref) {
  return DriftItemsRepository(ref.watch(appDatabaseProvider));
});

final suppliersRepositoryProvider = Provider<SuppliersRepository>((ref) {
  return DriftSuppliersRepository(ref.watch(appDatabaseProvider));
});

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return DriftPurchasesRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(stockServiceProvider),
  );
});

final stockCountRepositoryProvider = Provider<StockCountRepository>((ref) {
  return DriftStockCountRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(stockServiceProvider),
  );
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return DriftReportsRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(stockServiceProvider),
  );
});


final invoicesRepositoryProvider = Provider<InvoicesRepository>((ref) {
  return DriftInvoicesRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(stockServiceProvider),
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return DriftSettingsRepository(ref.watch(appDatabaseProvider));
});

final workOrdersRepositoryProvider = Provider<WorkOrdersRepository>((ref) {
  return DriftWorkOrdersRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(stockServiceProvider),
  );
});

final employeesRepositoryProvider = Provider<EmployeesRepository>((ref) {
  return DriftEmployeesRepository(ref.watch(appDatabaseProvider));
});

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return DriftExpensesRepository(ref.watch(appDatabaseProvider));
});

/// Domain services providers.
final stockServiceProvider = Provider<StockService>((ref) {
  return StockService(ref.watch(appDatabaseProvider));
});

final numberingServiceProvider = Provider<NumberingService>((ref) {
  return NumberingService(ref.watch(appDatabaseProvider));
});
