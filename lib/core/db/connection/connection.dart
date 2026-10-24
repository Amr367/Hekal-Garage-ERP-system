import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages database connections for both production (Windows desktop)
/// and automated unit tests (in-memory).
abstract final class DbConnection {
  static String? _databasePath;

  /// Returns the absolute path to the local `garage.sqlite` file once initialized.
  static String? get databasePath => _databasePath;

  /// Creates a persistent SQLite database connection for desktop Windows.
  ///
  /// Places `garage.sqlite` in the application support directory,
  /// logs the path to console/logger, and ensures the parent folder exists.
  static LazyDatabase openConnection() {
    return LazyDatabase(() async {
      final Directory dbFolder = await getApplicationSupportDirectory();
      final File file = File(p.join(dbFolder.path, 'garage.sqlite'));

      if (!await dbFolder.exists()) {
        await dbFolder.create(recursive: true);
      }

      _databasePath = file.path;

      return NativeDatabase.createInBackground(file);
    });
  }

  /// Creates an in-memory database connection for unit tests.
  static DatabaseConnection openInMemory() {
    return DatabaseConnection(NativeDatabase.memory());
  }

  /// Opens the database directory in Windows File Explorer.
  static Future<void> openDatabaseFolder() async {
    final Directory dbFolder = await getApplicationSupportDirectory();
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [dbFolder.path]);
    }
  }
}
