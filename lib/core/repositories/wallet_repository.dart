import 'package:sqflite/sqflite.dart';

enum Currency {
  cash('cash'),
  bungeoppang('bungeoppang');

  const Currency(this.key);
  final String key;
}

class InsufficientFundsException implements Exception {
  InsufficientFundsException(this.currency, this.required, this.available);
  final Currency currency;
  final int required;
  final int available;

  @override
  String toString() =>
      'InsufficientFunds(${currency.key}: need $required, have $available)';
}

/// 재화 잔액과 변동 이력. 모든 증감은 이 클래스를 통해서만 한다.
class WalletRepository {
  WalletRepository(this._db);
  final Database _db;

  Future<int> balance(Currency c) async {
    final rows = await _db.query('wallet',
        columns: ['amount'], where: 'currency = ?', whereArgs: [c.key]);
    return rows.first['amount'] as int;
  }

  Future<Map<Currency, int>> balances() async {
    final rows = await _db.query('wallet');
    final byKey = {for (final r in rows) r['currency']: r['amount'] as int};
    return {for (final c in Currency.values) c: byKey[c.key] ?? 0};
  }

  Future<int> earn(Currency c, int amount,
      {required String reason, String? source}) {
    assert(amount > 0);
    return _db.transaction((txn) => _apply(txn, c, amount, reason, source));
  }

  /// 잔액이 부족하면 [InsufficientFundsException]을 던지고 아무것도 바꾸지 않는다.
  Future<int> spend(Currency c, int amount,
      {required String reason, String? source}) {
    assert(amount > 0);
    return _db.transaction((txn) => _apply(txn, c, -amount, reason, source));
  }

  /// 트랜잭션 안에서 다른 작업(예: 고양이 입양)과 묶어 쓸 때 사용.
  Future<int> applyIn(Transaction txn, Currency c, int delta,
          {required String reason, String? source}) =>
      _apply(txn, c, delta, reason, source);

  Future<int> _apply(DatabaseExecutor txn, Currency c, int delta, String reason,
      String? source) async {
    final rows = await txn.query('wallet',
        columns: ['amount'], where: 'currency = ?', whereArgs: [c.key]);
    final current = rows.first['amount'] as int;
    final next = current + delta;
    if (next < 0) throw InsufficientFundsException(c, -delta, current);
    await txn.update('wallet', {'amount': next},
        where: 'currency = ?', whereArgs: [c.key]);
    await txn.insert('wallet_ledger', {
      'currency': c.key,
      'delta': delta,
      'reason': reason,
      'source': source,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return next;
  }
}
