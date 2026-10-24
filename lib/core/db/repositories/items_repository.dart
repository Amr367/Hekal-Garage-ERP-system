import 'package:drift/drift.dart';

import '../../errors/app_exceptions.dart';
import '../database.dart';

abstract interface class ItemsRepository {
  Future<Item> getById(int id);
  Future<Item?> getBySku(String sku);
  Future<Item?> getByBarcode(String barcode);
  Future<List<Item>> getAll({bool onlyActive = false, int? categoryId});
  Future<List<Item>> search(String query);
  Future<int> insertItem(ItemsCompanion item);
  Future<bool> updateItem(Item item);
  Future<void> deactivate(int id);
  Future<void> deleteItem(int id);
}

class DriftItemsRepository implements ItemsRepository {
  const DriftItemsRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Item> getById(int id) async {
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (item == null) {
      throw NotFoundException('الصنف برقم ($id) غير موجود.');
    }
    return item;
  }

  @override
  Future<Item?> getBySku(String sku) {
    final trimmed = sku.trim();
    if (trimmed.isEmpty) return Future.value(null);
    return (_db.select(_db.items)..where((t) => t.sku.equals(trimmed))).getSingleOrNull();
  }

  @override
  Future<Item?> getByBarcode(String barcode) {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return Future.value(null);
    return (_db.select(_db.items)..where((t) => t.barcode.equals(trimmed))).getSingleOrNull();
  }

  @override
  Future<List<Item>> getAll({bool onlyActive = false, int? categoryId}) {
    final query = _db.select(_db.items);
    if (onlyActive) {
      query.where((t) => t.isActive.equals(true));
    }
    if (categoryId != null) {
      query.where((t) => t.categoryId.equals(categoryId));
    }
    return query.get();
  }

  @override
  Future<List<Item>> search(String query) {
    final cleaned = query.trim();
    if (cleaned.isEmpty) {
      return getAll(onlyActive: true);
    }
    return (_db.select(_db.items)
          ..where((t) =>
              t.name.contains(cleaned) |
              t.sku.contains(cleaned) |
              t.barcode.contains(cleaned)))
        .get();
  }

  @override
  Future<int> insertItem(ItemsCompanion item) async {
    final name = item.name.value.trim();
    if (name.isEmpty) {
      throw const ValidationException('اسم الصنف مطلوب.');
    }

    if (item.sku.present && item.sku.value != null && item.sku.value!.trim().isNotEmpty) {
      final existingSku = await getBySku(item.sku.value!);
      if (existingSku != null) {
        throw ValidationException('كود الصنف (SKU: ${item.sku.value}) مستخدم مسبقاً لصنف آخر.');
      }
    }

    return _db.into(_db.items).insert(item);
  }

  @override
  Future<bool> updateItem(Item item) {
    return _db.update(_db.items).replace(item);
  }

  @override
  Future<void> deactivate(int id) async {
    final updated = await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(
      const ItemsCompanion(isActive: Value(false)),
    );
    if (updated == 0) {
      throw NotFoundException('الصنف برقم ($id) غير موجود لتعطيله.');
    }
  }

  @override
  Future<void> deleteItem(int id) async {
    // Check if item has stock movements or invoice/work-order lines
    final movementCount = await (_db.selectOnly(_db.stockMovements)
          ..addColumns([_db.stockMovements.id.count()])
          ..where(_db.stockMovements.itemId.equals(id)))
        .getSingle();

    final int movements = movementCount.read(_db.stockMovements.id.count()) ?? 0;
    if (movements > 0) {
      throw const BusinessRuleException(
        'لا يمكن حذف هذا الصنف لوجود حركات مخزنية مسجلة له. يمكنك إلغاء تفعيله بدلاً من الحذف.',
      );
    }

    final deleted = await (_db.delete(_db.items)..where((t) => t.id.equals(id))).go();
    if (deleted == 0) {
      throw NotFoundException('الصنف برقم ($id) غير موجود لحذفه.');
    }
  }
}
