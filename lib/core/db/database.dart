import 'package:drift/drift.dart';

part 'database.g.dart';

// ── Enums (stored as integers) ─────────────────────────────────────────

enum StockMovementType {
  opening, // 0
  purchaseIn, // 1
  saleOut, // 2
  saleReturn, // 3
  countDiff, // 4
  adjustment, // 5
}

enum WorkOrderStatus {
  open, // 0 - مفتوح
  inProgress, // 1 - تحت الشغل
  ready, // 2 - جاهز
  delivered, // 3 - اتسلّم
  cancelled, // 4 - ملغي
}

enum LineType {
  service, // 0 - مصنعية / خدمة
  part, // 1 - قطعة غيار / صنف
}

enum InvoiceStatus {
  issued, // 0 - صادرة
  cancelled, // 1 - ملغاة
}

enum PaymentMethod {
  cash, // 0 - كاش
  wallet, // 1 - محفظة إلكترونية
  instapay, // 2 - انستاباي
  card, // 3 - فيزا / كارت
  transfer, // 4 - تحويل بنكي
}

enum StockCountStatus {
  draft, // 0 - مسودة
  finalized, // 1 - معتمد
}

// ── Tables ─────────────────────────────────────────────────────────────

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Vehicles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  TextColumn get plateNumber => text().unique()();
  TextColumn get make => text().nullable()();
  TextColumn get model => text().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get chassisNumber => text().nullable()();
  IntColumn get lastOdometer => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Services extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get defaultPrice => integer()(); // in piasters
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class ItemCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Items extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(ItemCategories, #id)();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable().unique()();
  TextColumn get barcode => text().nullable()();
  TextColumn get unit => text().withDefault(const Constant('قطعة'))();
  IntColumn get costPrice => integer().withDefault(const Constant(0))(); // piasters
  IntColumn get salePrice => integer().withDefault(const Constant(0))(); // piasters
  RealColumn get minQuantity => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer().references(Items, #id)();
  IntColumn get movementType => intEnum<StockMovementType>()();
  RealColumn get qty => real()(); // Positive for in, negative for out
  IntColumn get unitCost => integer().nullable()(); // piasters snapshot
  TextColumn get refType => text().nullable()(); // 'invoice', 'purchase', 'adjustment', 'count'
  IntColumn get refId => integer().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PurchaseInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  TextColumn get supplierInvoiceNumber => text().nullable()();
  DateTimeColumn get invoiceDate => dateTime()();
  IntColumn get totalAmount => integer()(); // piasters
  IntColumn get paidAmount => integer().withDefault(const Constant(0))(); // piasters
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PurchaseInvoiceLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseInvoiceId => integer().references(PurchaseInvoices, #id)();
  IntColumn get itemId => integer().references(Items, #id)();
  RealColumn get quantity => real()();
  IntColumn get unitCost => integer()(); // piasters
  IntColumn get totalAmount => integer()(); // piasters
}

class WorkOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderNumber => integer().unique()();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get vehicleId => integer().references(Vehicles, #id)();
  IntColumn get status => intEnum<WorkOrderStatus>().withDefault(const Constant(0))();
  IntColumn get odometer => integer().nullable()();
  TextColumn get complaint => text().nullable()();
  TextColumn get mechanicName => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get cancellationReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get closedAt => dateTime().nullable()();
}

class WorkOrderLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workOrderId => integer().references(WorkOrders, #id)();
  IntColumn get lineType => intEnum<LineType>()();
  IntColumn get serviceId => integer().nullable().references(Services, #id)();
  IntColumn get itemId => integer().nullable().references(Items, #id)();
  TextColumn get description => text()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  IntColumn get unitPrice => integer()(); // piasters
  IntColumn get totalPrice => integer()(); // piasters
}

class Invoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceNumber => integer().unique()();
  IntColumn get workOrderId => integer().nullable().references(WorkOrders, #id)();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get subtotal => integer()(); // piasters
  IntColumn get discountAmount => integer().withDefault(const Constant(0))(); // piasters
  IntColumn get totalAmount => integer()(); // piasters (subtotal - discount)
  IntColumn get paidAmount => integer().withDefault(const Constant(0))(); // piasters
  IntColumn get status => intEnum<InvoiceStatus>().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  TextColumn get cancellationReason => text().nullable()();
  DateTimeColumn get issuedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
}

class InvoiceLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().references(Invoices, #id)();
  IntColumn get lineType => intEnum<LineType>()();
  IntColumn get serviceId => integer().nullable().references(Services, #id)();
  IntColumn get itemId => integer().nullable().references(Items, #id)();
  TextColumn get description => text()();
  RealColumn get quantity => real()();
  IntColumn get unitPrice => integer()(); // piasters
  IntColumn get unitCost => integer()(); // snapshot from items.costPrice at issue time (Rule R8)
  IntColumn get totalPrice => integer()(); // piasters
}

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().references(Invoices, #id)();
  IntColumn get amount => integer()(); // piasters (positive for payment, negative for refund)
  IntColumn get paymentMethod => intEnum<PaymentMethod>()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get paidAt => dateTime().withDefault(currentDateAndTime)();
}

class StockCounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get countNumber => integer().unique()();
  TextColumn get scope => text()(); // 'all', 'category', 'recent'
  IntColumn get status => intEnum<StockCountStatus>().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get finalizedAt => dateTime().nullable()();
}

class StockCountLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get stockCountId => integer().references(StockCounts, #id)();
  IntColumn get itemId => integer().references(Items, #id)();
  RealColumn get systemQty => real()();
  RealColumn get countedQty => real().nullable()();
  RealColumn get difference => real().nullable()();
  TextColumn get notes => text().nullable()();
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ── Database Class ─────────────────────────────────────────────────────

@DriftDatabase(tables: [
  Customers,
  Vehicles,
  Services,
  ItemCategories,
  Items,
  StockMovements,
  Suppliers,
  PurchaseInvoices,
  PurchaseInvoiceLines,
  WorkOrders,
  WorkOrderLines,
  Invoices,
  InvoiceLines,
  Payments,
  StockCounts,
  StockCountLines,
  AppSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (OpeningDetails details) async {
        // Enforce foreign keys.
        await customStatement('PRAGMA foreign_keys = ON;');
        // FULL synchronous durability against power cuts.
        await customStatement('PRAGMA synchronous = FULL;');
        // WAL journal mode for reliable concurrent reads/writes.
        await customStatement('PRAGMA journal_mode = WAL;');
      },
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  /// Computes the current on-hand quantity for [itemId] per Rule R2:
  /// Stock on hand is SUM(stock_movements.qty).
  Future<double> stockOf(int itemId) async {
    final qtySum = stockMovements.qty.sum();
    final query = selectOnly(stockMovements)
      ..addColumns([qtySum])
      ..where(stockMovements.itemId.equals(itemId));

    final row = await query.getSingle();
    return row.read(qtySum) ?? 0.0;
  }

  /// Watches all items with their current stock levels.
  Stream<List<DbItemWithStock>> watchStockLevels() {
    final qtySum = stockMovements.qty.sum();
    final query = select(items).join([
      leftOuterJoin(
        stockMovements,
        stockMovements.itemId.equalsExp(items.id),
      ),
    ])
      ..addColumns([qtySum])
      ..groupBy([items.id]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final item = row.readTable(items);
        final onHand = row.read(qtySum) ?? 0.0;
        return DbItemWithStock(item: item, onHand: onHand);
      }).toList();
    });
  }

  /// Returns the next sequential invoice number without gaps (Rule R6).
  /// Must be called inside a transaction that inserts the invoice.
  Future<int> nextInvoiceNumber() async {
    final maxNumber = invoices.invoiceNumber.max();
    final query = selectOnly(invoices)..addColumns([maxNumber]);
    final row = await query.getSingle();
    final currentMax = row.read(maxNumber);

    if (currentMax == null || currentMax <= 0) {
      // Check if a starting number is configured in AppSettings.
      final setting = await (select(appSettings)..where((t) => t.key.equals('starting_invoice_number'))).getSingleOrNull();
      if (setting != null) {
        return int.tryParse(setting.value) ?? 1;
      }
      return 1;
    }
    return currentMax + 1;
  }

  /// Returns the next sequential work order number without gaps (Rule R6).
  /// Must be called inside a transaction that inserts the work order.
  Future<int> nextWorkOrderNumber() async {
    final maxNumber = workOrders.orderNumber.max();
    final query = selectOnly(workOrders)..addColumns([maxNumber]);
    final row = await query.getSingle();
    final currentMax = row.read(maxNumber);

    if (currentMax == null || currentMax <= 0) {
      final setting = await (select(appSettings)..where((t) => t.key.equals('starting_work_order_number'))).getSingleOrNull();
      if (setting != null) {
        return int.tryParse(setting.value) ?? 1;
      }
      return 1;
    }
    return currentMax + 1;
  }

  /// Backs up the SQLite database using SQLite's online backup API (VACUUM INTO).
  Future<void> backupTo(String destinationPath) async {
    await customStatement('VACUUM INTO ?', [destinationPath]);
  }
}

/// Helper model pairing an [Item] with its calculated stock on hand.
class DbItemWithStock {
  const DbItemWithStock({
    required this.item,
    required this.onHand,
  });

  final Item item;
  final double onHand;
}
