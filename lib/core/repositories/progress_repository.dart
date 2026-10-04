import 'package:sqflite/sqflite.dart';

/// 게임 모듈별 기록. game_id는 모듈이 정하는 고정 문자열 (예: 'cat_merge').
class ProgressRepository {
  ProgressRepository(this._db);
  final DatabaseExecutor _db;

  /// 한 판이 끝났을 때 호출. 최고점은 더 높을 때만 갱신된다.
  Future<void> recordPlay(String gameId, int score) => _db.rawInsert(
        '''
        INSERT INTO game_progress (game_id, best_score, play_count, updated_at)
        VALUES (?, ?, 1, ?)
        ON CONFLICT(game_id) DO UPDATE SET
          best_score = MAX(best_score, excluded.best_score),
          play_count = play_count + 1,
          updated_at = excluded.updated_at
        ''',
        [gameId, score, DateTime.now().millisecondsSinceEpoch],
      );

  Future<int> bestScore(String gameId) async {
    final rows = await _db.query('game_progress',
        columns: ['best_score'], where: 'game_id = ?', whereArgs: [gameId]);
    return rows.isEmpty ? 0 : rows.first['best_score'] as int;
  }

  /// 레벨 클리어 기록. 별/점수는 기존보다 좋을 때만 갱신된다.
  Future<void> clearLevel(String gameId, int level,
          {int stars = 0, int score = 0}) =>
      _db.rawInsert(
        '''
        INSERT INTO level_progress (game_id, level, stars, best_score, cleared_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(game_id, level) DO UPDATE SET
          stars = MAX(stars, excluded.stars),
          best_score = MAX(best_score, excluded.best_score)
        ''',
        [gameId, level, stars, score, DateTime.now().millisecondsSinceEpoch],
      );

  /// 클리어한 가장 높은 레벨 (없으면 0).
  Future<int> highestCleared(String gameId) async => Sqflite.firstIntValue(
          await _db.rawQuery(
              'SELECT MAX(level) FROM level_progress WHERE game_id = ?',
              [gameId])) ??
      0;

  /// 레벨별 별 개수 (클리어한 레벨만).
  Future<Map<int, int>> allStars(String gameId) async {
    final rows = await _db.query('level_progress',
        columns: ['level', 'stars'], where: 'game_id = ?', whereArgs: [gameId]);
    return {for (final r in rows) r['level'] as int: r['stars'] as int};
  }

  Future<int> stars(String gameId, int level) async {
    final rows = await _db.query('level_progress',
        columns: ['stars'],
        where: 'game_id = ? AND level = ?',
        whereArgs: [gameId, level]);
    return rows.isEmpty ? 0 : rows.first['stars'] as int;
  }
}
