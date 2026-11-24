// ignore_for_file: experimental_member_use, deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift/remote.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:stream_channel/stream_channel.dart';

import '../services/network_db_service.dart';

/// Manages database connections for production (Windows desktop)
/// supporting both local master mode and LAN remote client mode,
/// as well as automated unit tests (in-memory).
abstract final class DbConnection {
  static String? _databasePath;

  /// Returns the absolute path to `garage.sqlite` or LAN connection info once initialized.
  static String? get databasePath => _databasePath;

  /// Creates a persistent SQLite database connection for desktop Windows,
  /// or connects remotely to the master garage PC over LAN.
  static QueryExecutor openConnection() {
    return LazyDatabase(() async {
      final config = await NetworkDbService.instance.loadConfig();

      if (config.isClient) {
        // Connect to master PC via Drift Remote Protocol over LAN
        final uri = 'ws://${config.serverIp}:${config.port}';
        _databasePath = 'شبكة محلية: $uri';

        try {
          final ws = await WebSocket.connect(uri).timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException(
              'تعذر الاتصال بسيرفر المركز على $uri. تأكد من تشغيل البرنامج على الجهاز الرئيسي وتوصيل الشبكة.',
            ),
          );

          final channel = StreamChannel<Object?>(ws, ws);
          return remote(channel);
        } catch (e) {
          // If remote fails, fallback to local database with a clear error
          rethrow;
        }
      } else {
        // Master / Standalone mode: Persistent local SQLite database
        final Directory dbFolder = await getApplicationSupportDirectory();
        final File file = File(p.join(dbFolder.path, 'garage.sqlite'));

        if (!await dbFolder.exists()) {
          await dbFolder.create(recursive: true);
        }

        _databasePath = file.path;
        return NativeDatabase.createInBackground(file);
      }
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
