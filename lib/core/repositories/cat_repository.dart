import 'package:sqflite/sqflite.dart';

import '../models/cat.dart';
import 'wallet_repository.dart';

class CatRepository {
  CatRepository(this._db, this._wallet);
  final Database _db;
  final WalletRepository _wallet;

  Future<List<Cat>> all() async {
    final rows = await _db.query('cats', orderBy: 'obtained_at');
    return rows.map(Cat.fromRow).toList();
  }

  Future<int> count() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM cats')) ??
      0;

  Future<Cat> add({required String breedId, required String name}) async {
    final id = await _db.insert('cats', _newRow(breedId, name));
    return (await byId(id))!;
  }

  /// 재화 차감과 고양이 추가를 하나의 트랜잭션으로 처리한다.
  Future<Cat> adopt({
    required String breedId,
    required String name,
    required Currency currency,
    required int price,
  }) async {
    final id = await _db.transaction((txn) async {
      await _wallet.applyIn(txn, currency, -price,
          reason: 'adopt', source: breedId);
      return txn.insert('cats', _newRow(breedId, name));
    });
    return (await byId(id))!;
  }

  Future<Cat?> byId(int id) async {
    final rows = await _db.query('cats', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Cat.fromRow(rows.first);
  }

  Future<void> feed(int id, {int amount = 30}) => _db.rawUpdate(
        'UPDATE cats SET hunger = MIN(100, hunger + ?), last_fed_at = ? '
        'WHERE id = ?',
        [amount, DateTime.now().millisecondsSinceEpoch, id],
      );

  Future<void> addExp(int id, int exp) =>
      _db.rawUpdate('UPDATE cats SET exp = exp + ? WHERE id = ?', [exp, id]);

  Map<String, Object?> _newRow(String breedId, String name) => {
        'breed_id': breedId,
        'name': name,
        'obtained_at': DateTime.now().millisecondsSinceEpoch,
      };
}
