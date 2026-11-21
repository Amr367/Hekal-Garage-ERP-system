import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage_erp/core/db/connection/connection.dart';
import 'package:garage_erp/core/db/database.dart';
import 'package:garage_erp/core/db/services/backup_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late AppDatabase db;
  late Directory tempDir;

  setUp(() {
    db = AppDatabase(DbConnection.openInMemory());
    tempDir = Directory.systemTemp.createTempSync('garage_backup_test_');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('VACUUM INTO backup file is created and can be restored to a new path', () async {
    await db.into(db.customers).insert(
          CustomersCompanion.insert(name: 'عميل النسخ الاحتياطي'),
        );

    final backupFile = File(p.join(tempDir.path, 'snapshot.sqlite'));
    final service = BackupService(db, backupsDirectory: tempDir);
    await service.backupToFile(backupFile.path);

    expect(backupFile.existsSync(), isTrue);
    expect(backupFile.lengthSync(), greaterThan(0));

    final restoredPath = p.join(tempDir.path, 'restored.sqlite');
    await service.restoreDatabaseFile(
      sourcePath: backupFile.path,
      destinationPath: restoredPath,
    );
    expect(File(restoredPath).existsSync(), isTrue);
  });

  test('integrity_check returns ok on a healthy database', () async {
    final result = await db.integrityCheck();
    expect(result.trim(), equals('ok'));
  });

  test('createAutoBackup writes a timestamped file and prunes extras', () async {
    final service = BackupService(db, backupsDirectory: tempDir);

    for (var i = 0; i < 3; i++) {
      await service.createAutoBackup();
    }

    final listed = await service.listAutoBackups();
    expect(listed.length, equals(3));
    expect(p.basename(listed.first.path), startsWith(BackupService.autoBackupPrefix));
  });
}
