import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_erp/core/db/connection/connection.dart';
import 'package:garage_erp/core/db/database.dart';
import 'package:garage_erp/core/db/repositories/categories_repository.dart';
import 'package:garage_erp/core/db/repositories/customers_repository.dart';
import 'package:garage_erp/core/db/repositories/items_repository.dart';
import 'package:garage_erp/core/db/repositories/services_repository.dart';
import 'package:garage_erp/core/db/repositories/settings_repository.dart';
import 'package:garage_erp/core/db/repositories/vehicles_repository.dart';
import 'package:garage_erp/core/db/seed_data.dart';
import 'package:garage_erp/core/db/services/numbering_service.dart';
import 'package:garage_erp/core/db/services/stock_service.dart';
import 'package:garage_erp/core/errors/app_exceptions.dart';
import 'package:garage_erp/core/money/money.dart';
import 'package:garage_erp/core/utils/formatters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MoneyUtils', () {
    test('parses basic values to piasters', () {
      expect(MoneyUtils.parseToPiasters('0'), 0);
      expect(MoneyUtils.parseToPiasters('1'), 100);
      expect(MoneyUtils.parseToPiasters('1.5'), 150);
      expect(MoneyUtils.parseToPiasters('1.55'), 155);
      expect(MoneyUtils.parseToPiasters('100.05'), 10005);
    });

    test('parses Arabic-Indic digits and Arabic decimal separator', () {
      expect(MoneyUtils.parseToPiasters('١٢٫٥'), 1250);
      expect(MoneyUtils.parseToPiasters('٢٥٠'), 25000);
      expect(MoneyUtils.parseToPiasters('١٬٢٥٠٫٥٠'), 125050);
    });

    test('parses thousands separators and currency labels', () {
      expect(MoneyUtils.parseToPiasters('1,250.50'), 125050);
      expect(MoneyUtils.parseToPiasters('1,250.50 ج.م'), 125050);
      expect(MoneyUtils.parseToPiasters('50,000 EGP'), 5000000);
    });

    test('parses negative values', () {
      expect(MoneyUtils.parseToPiasters('-50.25'), -5025);
      expect(MoneyUtils.parseToPiasters('−100'), -10000);
    });

    test('rejects more than 2 decimal places', () {
      expect(
        () => MoneyUtils.parseToPiasters('1.555'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects invalid or overflow input', () {
      expect(
        () => MoneyUtils.parseToPiasters(''),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => MoneyUtils.parseToPiasters('abc'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => MoneyUtils.parseToPiasters('999999999999999'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('format and parse round-trip accurately', () {
      const piasters = 125050;
      final formatted = MoneyUtils.format(piasters);
      expect(formatted, '1,250.50');
      expect(MoneyUtils.parseToPiasters(formatted), piasters);
    });
  });

  group('Formatters', () {
    test('normalizes plate numbers according to Rule R13', () {
      expect(
        Formatters.normalizePlateNumber('  أ   ب   ج   ١٢٣٤  '),
        'أ ب ج 1234',
      );
      expect(
        Formatters.normalizePlateNumber('س ص ع 5 6 7'),
        'س ص ع 5 6 7',
      );
      expect(
        Formatters.normalizePlateNumber('  ق ط ر   ٨٩٠  '),
        'ق ط ر 890',
      );
    });

    test('parses and formats quantities without trailing zeros', () {
      expect(Formatters.parseQuantity('1'), 1.0);
      expect(Formatters.parseQuantity('1.5'), 1.5);
      expect(Formatters.parseQuantity('١٫٢٥'), 1.25);
      expect(Formatters.parseQuantity('2.125'), 2.125);

      expect(Formatters.formatQuantity(1.0), '1');
      expect(Formatters.formatQuantity(1.50), '1.5');
      expect(Formatters.formatQuantity(1.234), '1.234');
      expect(Formatters.formatQuantity(0.0), '0');

      expect(
        () => Formatters.parseQuantity('1.2345'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('In-Memory Drift Database & Repositories', () {
    late AppDatabase db;
    late CustomersRepository customersRepo;
    late VehiclesRepository vehiclesRepo;
    late ServicesRepository servicesRepo;
    late CategoriesRepository categoriesRepo;
    late ItemsRepository itemsRepo;
    late SettingsRepository settingsRepo;
    late StockService stockService;
    late NumberingService numberingService;

    setUp(() {
      db = AppDatabase(DbConnection.openInMemory());
      customersRepo = DriftCustomersRepository(db);
      vehiclesRepo = DriftVehiclesRepository(db);
      servicesRepo = DriftServicesRepository(db);
      categoriesRepo = DriftCategoriesRepository(db);
      itemsRepo = DriftItemsRepository(db);
      settingsRepo = DriftSettingsRepository(db);
      stockService = StockService(db);
      numberingService = NumberingService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('SeedData loads 15 services and 10 categories exactly once', () async {
      final loadedFirst = await SeedData.loadIfFirstRun(db);
      expect(loadedFirst, isTrue);

      final services = await servicesRepo.getAll();
      expect(services.length, 15);

      final categories = await categoriesRepo.getAll();
      expect(categories.length, 10);

      // Second run must be ignored
      final loadedSecond = await SeedData.loadIfFirstRun(db);
      expect(loadedSecond, isFalse);

      final servicesAfter = await servicesRepo.getAll();
      expect(servicesAfter.length, 15);
    });

    test('Customers and Vehicles repositories CRUD and transfer', () async {
      final custId = await customersRepo.insertCustomer(
        const CustomersCompanion(
          name: drift.Value('محمود سمير'),
          phone: drift.Value('01011112222'),
        ),
      );
      expect(custId, greaterThan(0));

      final customer = await customersRepo.getById(custId);
      expect(customer.name, 'محمود سمير');

      // Add car with normalized plate
      final vehicleId = await vehiclesRepo.insertVehicle(
        VehiclesCompanion(
          customerId: drift.Value(custId),
          plateNumber: const drift.Value('  أ   ب   ج   ١٢٣٤  '),
          make: const drift.Value('نيسان'),
          model: const drift.Value('صني'),
        ),
      );

      final vehicle = await vehiclesRepo.getById(vehicleId);
      expect(vehicle.plateNumber, 'أ ب ج 1234'); // normalized!

      // Transfer ownership
      final custId2 = await customersRepo.insertCustomer(
        const CustomersCompanion(
          name: drift.Value('علي حسن'),
          phone: drift.Value('01099998888'),
        ),
      );

      await vehiclesRepo.transferOwnership(vehicleId, custId2);
      final transferredVehicle = await vehiclesRepo.getById(vehicleId);
      expect(transferredVehicle.customerId, custId2);
    });

    test('Categories merge and delete moves items to target category', () async {
      final cat1Id = await categoriesRepo.insertCategory('قسم مؤقت');
      final cat2Id = await categoriesRepo.insertCategory('قسم دائم');

      final itemId = await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(cat1Id),
          name: const drift.Value('صنف تجريبي'),
          salePrice: const drift.Value(10000),
        ),
      );

      // Merge cat1 into cat2
      await categoriesRepo.mergeAndDelete(cat1Id, cat2Id);

      // Item should now belong to cat2
      final item = await itemsRepo.getById(itemId);
      expect(item.categoryId, cat2Id);

      // cat1 should no longer exist
      expect(
        () => categoriesRepo.getById(cat1Id),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('Items repository rejects duplicate SKU', () async {
      final catId = await categoriesRepo.insertCategory('زيوت');
      await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('زيت موبيل'),
          sku: const drift.Value('OIL-001'),
        ),
      );

      expect(
        () => itemsRepo.insertItem(
          ItemsCompanion(
            categoryId: drift.Value(catId),
            name: const drift.Value('زيت كاسترول'),
            sku: const drift.Value('OIL-001'),
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Settings repository stores and watches typed settings', () async {
      await settingsRepo.set('shop_name', 'مركز الرواد');
      await settingsRepo.setInt('starting_invoice_number', 500);
      await settingsRepo.setBool('allow_negative_stock', false);

      expect(await settingsRepo.get('shop_name'), 'مركز الرواد');
      expect(await settingsRepo.getInt('starting_invoice_number', 1), 500);
      expect(await settingsRepo.getBool('allow_negative_stock', true), false);
    });

    test('StockService records movements and blocks negative stock', () async {
      final catId = await categoriesRepo.insertCategory('فلاتر');
      final itemId = await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('فلتر هواء'),
          costPrice: const drift.Value(5000),
          salePrice: const drift.Value(8000),
        ),
      );

      // Initial stock = 0
      expect(await stockService.onHand(itemId), 0.0);

      // 1. Purchase in: +10
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.purchaseIn),
          qty: const drift.Value(10.0),
          unitCost: const drift.Value(5000),
        ),
      );
      expect(await stockService.onHand(itemId), 10.0);

      // 2. Sale out: -3
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.saleOut),
          qty: const drift.Value(-3.0),
        ),
      );
      expect(await stockService.onHand(itemId), 7.0);

      // 3. Excess sale out: -10 (should be blocked by default)
      expect(
        () => stockService.addMovement(
          StockMovementsCompanion(
            itemId: drift.Value(itemId),
            movementType: const drift.Value(StockMovementType.saleOut),
            qty: const drift.Value(-10.0),
          ),
        ),
        throwsA(isA<InsufficientStockException>()),
      );

      // 4. Excess sale out with allowNegative = true succeeds
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.saleOut),
          qty: const drift.Value(-10.0),
        ),
        allowNegative: true,
      );
      expect(await stockService.onHand(itemId), -3.0);

      // 5. Item with movements cannot be deleted
      expect(
        () => itemsRepo.deleteItem(itemId),
        throwsA(isA<BusinessRuleException>()),
      );
    });

    test('NumberingService generates sequential numbers without gaps', () async {
      // First invoice number
      final n1 = await numberingService.getNextInvoiceNumber();
      expect(n1, 1);

      // Insert invoice #1
      await db.into(db.invoices).insert(
            const InvoicesCompanion(
              invoiceNumber: drift.Value(1),
              subtotal: drift.Value(10000),
              totalAmount: drift.Value(10000),
            ),
          );

      // Next invoice number must be 2
      final n2 = await numberingService.getNextInvoiceNumber();
      expect(n2, 2);

      // Insert invoice #2
      await db.into(db.invoices).insert(
            const InvoicesCompanion(
              invoiceNumber: drift.Value(2),
              subtotal: drift.Value(15000),
              totalAmount: drift.Value(15000),
            ),
          );

      // Next is 3
      final n3 = await numberingService.getNextInvoiceNumber();
      expect(n3, 3);
    });
  });
}
