import 'package:drift/drift.dart';

import 'database.dart';

/// Initial seed data offered on first run and available via a debug button.
///
/// Contains:
/// - 15 common automotive maintenance services with standard prices.
/// - 10 common automotive spare parts categories.
///
/// Can be loaded only once (tracked by the `seed_data_loaded` AppSetting).
abstract final class SeedData {
  static const String seedLoadedKey = 'seed_data_loaded';

  static const List<Map<String, dynamic>> defaultServices = [
    {'name': 'تغيير زيت المحرك', 'price': 15000}, // 150.00 EGP
    {'name': 'تغيير فلتر الزيت', 'price': 5000}, // 50.00 EGP
    {'name': 'تغيير فلتر الهواء', 'price': 3000}, // 30.00 EGP
    {'name': 'تغيير فلتر التكييف', 'price': 4000}, // 40.00 EGP
    {'name': 'فحص كمبيوتر (OBD-II)', 'price': 15000}, // 150.00 EGP
    {'name': 'ضبط زوايا بالليزر', 'price': 20000}, // 200.00 EGP
    {'name': 'ترصيص إطارات (للعجلة)', 'price': 3500}, // 35.00 EGP
    {'name': 'تغيير تيل فرامل أمامي', 'price': 15000}, // 150.00 EGP
    {'name': 'تغيير تيل فرامل خلفي', 'price': 15000}, // 150.00 EGP
    {'name': 'غسيل وتشحيم شاسيه', 'price': 12000}, // 120.00 EGP
    {'name': 'فحص كهرباء وإصلاح ضفيرة', 'price': 20000}, // 200.00 EGP
    {'name': 'تغيير بطارية وفحص دينامو', 'price': 5000}, // 50.00 EGP
    {'name': 'تغيير بوجيهات (شمعات الإشعال)', 'price': 8000}, // 80.00 EGP
    {'name': 'تغيير سير مجموعة أو دينامو', 'price': 12000}, // 120.00 EGP
    {'name': 'تنظيف دورة التبريد وتغيير مياه رادياتير', 'price': 15000}, // 150.00 EGP
  ];

  static const List<String> defaultCategories = [
    'زيوت وسوائل',
    'فلاتر',
    'فرامل وتيل',
    'كهرباء وبطاريات',
    'إطارات وجنوط',
    'سيور ومجموعات',
    'عفشة وتعليق',
    'تبريد ورادياتير',
    'إكسسوارات',
    'متفرقات',
  ];

  /// Loads seed categories and services into [db] if not already loaded.
  ///
  /// Returns `true` if loaded, `false` if already loaded previously.
  static Future<bool> loadIfFirstRun(AppDatabase db) async {
    final setting = await (db.select(db.appSettings)..where((t) => t.key.equals(seedLoadedKey))).getSingleOrNull();
    if (setting != null && setting.value == 'true') {
      return false; // Already loaded
    }

    await db.transaction(() async {
      // 1. Insert categories
      for (final catName in defaultCategories) {
        final existing = await (db.select(db.itemCategories)..where((t) => t.name.equals(catName))).getSingleOrNull();
        if (existing == null) {
          await db.into(db.itemCategories).insert(
                ItemCategoriesCompanion(name: Value(catName)),
              );
        }
      }

      // 2. Insert services
      for (final s in defaultServices) {
        final name = s['name'] as String;
        final price = s['price'] as int;
        final existing = await (db.select(db.services)..where((t) => t.name.equals(name))).getSingleOrNull();
        if (existing == null) {
          await db.into(db.services).insert(
                ServicesCompanion(
                  name: Value(name),
                  defaultPrice: Value(price),
                ),
              );
        }
      }

      // 3. Mark as loaded
      await db.into(db.appSettings).insertOnConflictUpdate(
            const AppSettingsCompanion(
              key: Value(seedLoadedKey),
              value: Value('true'),
            ),
          );
    });

    return true;
  }
}
