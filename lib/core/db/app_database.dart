import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';

/// 앱 전체에서 하나만 여는 SQLite 연결.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const fileName = 'catspuzzle.db';

  /// [factory]와 [path]는 테스트에서 FFI/메모리 DB를 주입할 때만 쓴다.
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: latestSchemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: _migrate,
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    final batch = db.batch();
    for (var v = from; v < to; v++) {
      for (final sql in migrations[v]) {
        batch.execute(sql);
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() => db.close();
}
