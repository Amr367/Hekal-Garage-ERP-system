import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../errors/app_exceptions.dart';
import '../../strings.dart';
import '../database.dart';

/// Offline SQLite backup, restore, and rotation for workshop data.
class BackupService {
  BackupService(this._db, {Directory? backupsDirectory})
      : _backupsDirectoryOverride = backupsDirectory;

  final AppDatabase _db;
  final Directory? _backupsDirectoryOverride;

  static const int keepAutoBackups = 14;
  static const String autoBackupPrefix = 'garage_backup_';
  static const String autoBackupSuffix = '.sqlite';

  /// Resolves the application `backups` folder under the support directory.
  Future<Directory> backupsDirectory() async {
    final overrideDir = _backupsDirectoryOverride;
    if (overrideDir != null) {
      if (!await overrideDir.exists()) {
        await overrideDir.create(recursive: true);
      }
      return overrideDir;
    }

    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Writes a consistent snapshot to [destinationPath] via `VACUUM INTO`.
  Future<void> backupToFile(String destinationPath) async {
    final dest = File(destinationPath);
    final parent = dest.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    if (await dest.exists()) {
      await dest.delete();
    }
    await _db.backupTo(destinationPath);
  }

  /// Creates a timestamped backup in the backups folder and prunes old copies.
  Future<File> createAutoBackup() async {
    final dir = await backupsDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final unique = DateTime.now().microsecondsSinceEpoch;
    final file = File(p.join(dir.path, '$autoBackupPrefix${stamp}_$unique$autoBackupSuffix'));
    await backupToFile(file.path);
    await pruneOldAutoBackups();
    return file;
  }

  /// Deletes oldest auto-backups beyond [keepAutoBackups].
  Future<void> pruneOldAutoBackups() async {
    final backups = await listAutoBackups();
    if (backups.length <= keepAutoBackups) {
      return;
    }
    final extra = backups.skip(keepAutoBackups);
    for (final file in extra) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Ignore prune failures; never block backup or shutdown.
      }
    }
  }

  /// Newest-first list of automatic backup files.
  Future<List<File>> listAutoBackups() async {
    final dir = await backupsDirectory();
    if (!await dir.exists()) {
      return const <File>[];
    }
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) {
          final name = p.basename(f.path);
          return name.startsWith(autoBackupPrefix) && name.endsWith(autoBackupSuffix);
        })
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Replaces the live database file with [sourcePath].
  ///
  /// The caller must close the Drift connection first. WAL/SHM sidecars are
  /// removed so the restored snapshot is the only file SQLite will open.
  Future<void> restoreDatabaseFile({
    required String sourcePath,
    required String destinationPath,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const ValidationException(AppStrings.backupFileNotFound);
    }

    final dest = File(destinationPath);
    final destDir = dest.parent;
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    await _deleteIfExists(File('$destinationPath-wal'));
    await _deleteIfExists(File('$destinationPath-shm'));
    await _deleteIfExists(File('$destinationPath-journal'));
    await _deleteIfExists(dest);

    await source.copy(destinationPath);
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
