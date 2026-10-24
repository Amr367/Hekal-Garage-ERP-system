import 'package:drift/drift.dart';

import '../database.dart';

abstract interface class SettingsRepository {
  Future<String?> get(String key);
  Future<String> getWithDefault(String key, String defaultValue);
  Future<int> getInt(String key, int defaultValue);
  Future<bool> getBool(String key, bool defaultValue);
  Future<void> set(String key, String value);
  Future<void> setInt(String key, int value);
  Future<void> setBool(String key, bool value);
  Stream<String?> watch(String key);
  Future<Map<String, String>> getAll();
}

class DriftSettingsRepository implements SettingsRepository {
  const DriftSettingsRepository(this._db);

  final AppDatabase _db;

  @override
  Future<String?> get(String key) async {
    final setting = await (_db.select(_db.appSettings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return setting?.value;
  }

  @override
  Future<String> getWithDefault(String key, String defaultValue) async {
    final val = await get(key);
    return val ?? defaultValue;
  }

  @override
  Future<int> getInt(String key, int defaultValue) async {
    final val = await get(key);
    if (val == null) return defaultValue;
    return int.tryParse(val) ?? defaultValue;
  }

  @override
  Future<bool> getBool(String key, bool defaultValue) async {
    final val = await get(key);
    if (val == null) return defaultValue;
    return val.toLowerCase() == 'true';
  }

  @override
  Future<void> set(String key, String value) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion(
            key: Value(key),
            value: Value(value),
          ),
        );
  }

  @override
  Future<void> setInt(String key, int value) => set(key, value.toString());

  @override
  Future<void> setBool(String key, bool value) => set(key, value.toString());

  @override
  Stream<String?> watch(String key) {
    return (_db.select(_db.appSettings)..where((t) => t.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  @override
  Future<Map<String, String>> getAll() async {
    final rows = await _db.select(_db.appSettings).get();
    return {for (final r in rows) r.key: r.value};
  }
}
