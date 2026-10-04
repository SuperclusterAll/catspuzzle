import 'package:sqflite/sqflite.dart';

/// 게임별 도감 (발견한 항목 목록).
class CodexRepository {
  CodexRepository(this._db);
  final DatabaseExecutor _db;

  Future<Set<String>> entries(String gameId) async {
    final rows = await _db.query('codex',
        columns: ['entry_id'], where: 'game_id = ?', whereArgs: [gameId]);
    return {for (final r in rows) r['entry_id'] as String};
  }

  /// 처음 발견이면 기록하고 true.
  Future<bool> add(String gameId, String entryId) async {
    final exists = await _db.query('codex',
        where: 'game_id = ? AND entry_id = ?', whereArgs: [gameId, entryId]);
    if (exists.isNotEmpty) return false;
    await _db.insert('codex', {
      'game_id': gameId,
      'entry_id': entryId,
      'first_at': DateTime.now().millisecondsSinceEpoch,
    });
    return true;
  }
}
