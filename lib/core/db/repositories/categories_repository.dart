import 'package:drift/drift.dart';

import '../../errors/app_exceptions.dart';
import '../database.dart';

abstract interface class CategoriesRepository {
  Future<ItemCategory> getById(int id);
  Future<List<ItemCategory>> getAll();
  Future<int> insertCategory(String name);
  Future<void> renameCategory(int id, String newName);
  Future<void> mergeAndDelete(int sourceCategoryId, int targetCategoryId);
}

class DriftCategoriesRepository implements CategoriesRepository {
  const DriftCategoriesRepository(this._db);

  final AppDatabase _db;

  @override
  Future<ItemCategory> getById(int id) async {
    final cat = await (_db.select(_db.itemCategories)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (cat == null) {
      throw NotFoundException('القسم برقم ($id) غير موجود.');
    }
    return cat;
  }

  @override
  Future<List<ItemCategory>> getAll() {
    return _db.select(_db.itemCategories).get();
  }

  @override
  Future<int> insertCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('اسم القسم مطلوب.');
    }
    final existing = await (_db.select(_db.itemCategories)..where((t) => t.name.equals(trimmed))).getSingleOrNull();
    if (existing != null) {
      throw ValidationException('القسم ($trimmed) مسجل مسبقاً.');
    }
    return _db.into(_db.itemCategories).insert(
          ItemCategoriesCompanion(name: Value(trimmed)),
        );
  }

  @override
  Future<void> renameCategory(int id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('اسم القسم الجديد مطلوب.');
    }
    final updated = await (_db.update(_db.itemCategories)..where((t) => t.id.equals(id))).write(
      ItemCategoriesCompanion(name: Value(trimmed)),
    );
    if (updated == 0) {
      throw NotFoundException('القسم برقم ($id) غير موجود لتعديل اسمه.');
    }
  }

  @override
  Future<void> mergeAndDelete(int sourceCategoryId, int targetCategoryId) async {
    if (sourceCategoryId == targetCategoryId) {
      throw const ValidationException('لا يمكن دمج القسم في نفسه.');
    }

    // Verify target category exists
    await getById(targetCategoryId);

    await _db.transaction(() async {
      // Move all items from source category to target category
      await (_db.update(_db.items)..where((t) => t.categoryId.equals(sourceCategoryId))).write(
        ItemsCompanion(categoryId: Value(targetCategoryId)),
      );

      // Delete the empty source category
      final deleted = await (_db.delete(_db.itemCategories)..where((t) => t.id.equals(sourceCategoryId))).go();
      if (deleted == 0) {
        throw NotFoundException('القسم المصدر برقم ($sourceCategoryId) غير موجود.');
      }
    });
  }
}
