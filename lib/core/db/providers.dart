import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection/connection.dart';
import 'database.dart';
import 'repositories/categories_repository.dart';
import 'repositories/customers_repository.dart';
import 'repositories/items_repository.dart';
import 'repositories/services_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/suppliers_repository.dart';
import 'repositories/vehicles_repository.dart';
import 'services/numbering_service.dart';
import 'services/stock_service.dart';

/// Database provider. Automatically closes the database when disposed.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(DbConnection.openConnection());
  ref.onDispose(() => db.close());
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

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return DriftSettingsRepository(ref.watch(appDatabaseProvider));
});

/// Domain services providers.
final stockServiceProvider = Provider<StockService>((ref) {
  return StockService(ref.watch(appDatabaseProvider));
});

final numberingServiceProvider = Provider<NumberingService>((ref) {
  return NumberingService(ref.watch(appDatabaseProvider));
});
