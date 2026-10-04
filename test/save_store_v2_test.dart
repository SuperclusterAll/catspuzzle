import 'dart:io';

import 'package:catspuzzle/core/db/app_database.dart';
import 'package:catspuzzle/core/db/migrations.dart';
import 'package:catspuzzle/core/items.dart';
import 'package:catspuzzle/core/repositories/wallet_repository.dart';
import 'package:catspuzzle/core/rewards.dart';
import 'package:catspuzzle/core/save_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  late Directory dir;
  late String dbPath;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('catspuzzle_v2');
    dbPath = p.join(dir.path, 'test.db');
  });
  tearDown(() => dir.delete(recursive: true));

  Future<SaveStore> openStore() async => SaveStore.open(
    database: await AppDatabase.open(factory: factory, path: dbPath),
  );

  test('v1 DB가 v2로 올라가도 기존 데이터 유지 + 체험 아이템 지급', () async {
    final v1 = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          for (final sql in migrations[0]) {
            await db.execute(sql);
          }
        },
      ),
    );
    await v1.update(
      'wallet',
      {'amount': 77},
      where: 'currency = ?',
      whereArgs: ['cash'],
    );
    await v1.close();

    final store = await openStore();
    expect(await store.database.db.getVersion(), latestSchemaVersion);
    expect(await store.wallet.balance(Currency.cash), 77);
    expect(await store.inventory.counts(), {
      ItemId.churu: 2,
      ItemId.cucumber: 2,
    });
    await store.close();
  });

  test('도감은 처음 발견할 때만 보상, 다시 열어도 유지', () async {
    var store = await openStore();
    final before = await store.wallet.balance(Currency.bungeoppang);
    expect(
      await store.discover('cat_merge', 't0_plain', rare: false),
      RewardPolicy.codexCommon,
    );
    expect(await store.discover('cat_merge', 't0_plain', rare: false), 0);
    expect(
      await store.discover('cat_merge', 't3_calico', rare: true),
      RewardPolicy.codexRare,
    );
    await store.close();

    store = await openStore();
    expect(await store.codex.entries('cat_merge'), {'t0_plain', 't3_calico'});
    expect(
      await store.wallet.balance(Currency.bungeoppang),
      before + RewardPolicy.codexCommon + RewardPolicy.codexRare,
    );
    await store.close();
  });

  test('아이템 구매는 붕어빵 차감, 사용은 0개면 실패', () async {
    final store = await openStore();
    final fish = await store.wallet.balance(Currency.bungeoppang);
    await store.buyItem(ItemId.churu);
    expect((await store.inventory.counts())[ItemId.churu], 3);
    expect(
      await store.wallet.balance(Currency.bungeoppang),
      fish - ItemId.churu.price,
    );

    for (var i = 0; i < 2; i++) {
      expect(await store.inventory.consume(ItemId.cucumber), isTrue);
    }
    expect(await store.inventory.consume(ItemId.cucumber), isFalse);
    expect((await store.inventory.counts())[ItemId.cucumber], 0);

    // 잔액 부족이면 아무것도 안 바뀜
    await store.wallet.spend(
      Currency.bungeoppang,
      await store.wallet.balance(Currency.bungeoppang),
      reason: 'test',
    );
    await expectLater(
      store.buyItem(ItemId.churu),
      throwsA(isA<InsufficientFundsException>()),
    );
    expect((await store.inventory.counts())[ItemId.churu], 3);
    await store.close();
  });

  test('스테이지 첫 클리어는 큰 보상, 재도전은 작은 보상, 별은 최고치 유지', () async {
    final store = await openStore();
    final cat = (await store.cats.all()).first;
    final first = await store.finishStage(
      gameId: 'cat_merge',
      level: 1,
      stars: 2,
      score: 100,
      catId: cat.id,
    );
    expect(first.bungeoppang, 40);
    final replay = await store.finishStage(
      gameId: 'cat_merge',
      level: 1,
      stars: 1,
      score: 50,
      catId: cat.id,
    );
    expect(replay.bungeoppang, 3);
    expect(await store.progress.allStars('cat_merge'), {1: 2});
    await store.close();
  });
}
