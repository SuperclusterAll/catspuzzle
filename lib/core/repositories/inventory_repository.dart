import 'package:sqflite/sqflite.dart';

import '../items.dart';

class InventoryRepository {
  InventoryRepository(this._db);
  final DatabaseExecutor _db;

  Future<Map<ItemId, int>> counts() async {
    final rows = await _db.query('inventory');
    final byKey = {for (final r in rows) r['item_id']: r['count'] as int};
    return {for (final i in ItemId.values) i: byKey[i.key] ?? 0};
  }

  Future<void> add(ItemId item, int n) => _db.rawInsert(
        '''
        INSERT INTO inventory (item_id, count) VALUES (?, ?)
        ON CONFLICT(item_id) DO UPDATE SET count = count + excluded.count
        ''',
        [item.key, n],
      );

  /// 1개 사용. 없으면 false.
  Future<bool> consume(ItemId item) async =>
      await _db.rawUpdate(
          'UPDATE inventory SET count = count - 1 '
          'WHERE item_id = ? AND count > 0',
          [item.key]) >
      0;
}
