import 'package:sqflite/sqflite.dart';

/// 키-값 설정 (사운드, 광고 제거 구매 여부, 튜토리얼 완료 등).
class SettingsRepository {
  SettingsRepository(this._db);
  final Database _db;

  static const soundOn = 'sound_on';
  static const adFree = 'ad_free';

  Future<String?> get(String key) async {
    final rows =
        await _db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> set(String key, String value) => _db.insert(
      'settings', {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<bool> getBool(String key, {bool fallback = false}) async {
    final v = await get(key);
    return v == null ? fallback : v == '1';
  }

  Future<void> setBool(String key, bool value) => set(key, value ? '1' : '0');
}
