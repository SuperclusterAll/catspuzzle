import 'dart:io';

import 'package:catspuzzle/core/db/app_database.dart';
import 'package:catspuzzle/core/repositories/settings_repository.dart';
import 'package:catspuzzle/core/repositories/wallet_repository.dart';
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
    dir = await Directory.systemTemp.createTemp('catspuzzle_test');
    dbPath = p.join(dir.path, 'test.db');
  });
  tearDown(() => dir.delete(recursive: true));

  Future<SaveStore> openStore() async => SaveStore.open(
    database: await AppDatabase.open(factory: factory, path: dbPath),
  );

  test('첫 실행 시 기본 고양이와 붕어빵 지급, 재실행해도 중복 지급 안 됨', () async {
    var store = await openStore();
    expect(await store.cats.count(), 1);
    expect(
      await store.wallet.balance(Currency.bungeoppang),
      SaveStore.starterBungeoppang,
    );
    await store.close();

    store = await openStore();
    expect(await store.cats.count(), 1);
    expect(
      await store.wallet.balance(Currency.bungeoppang),
      SaveStore.starterBungeoppang,
    );
    await store.close();
  });

  test('DB를 닫았다 다시 열어도 재화/고양이/진행도/설정 유지', () async {
    var store = await openStore();
    await store.wallet.earn(Currency.cash, 30, reason: 'iap');
    await store.cats.adopt(
      breedId: 'black',
      name: '까망',
      currency: Currency.bungeoppang,
      price: 60,
    );
    await store.progress.recordPlay('block_blast', 1200);
    await store.progress.recordPlay('block_blast', 800);
    await store.progress.clearLevel('cat_sort', 3, stars: 2);
    await store.settings.setBool(SettingsRepository.adFree, true);
    await store.close();

    store = await openStore();
    expect(await store.wallet.balance(Currency.cash), 30);
    expect(await store.wallet.balance(Currency.bungeoppang), 40);
    expect((await store.cats.all()).map((c) => c.name), ['나비', '까망']);
    expect(await store.progress.bestScore('block_blast'), 1200);
    expect(await store.progress.highestCleared('cat_sort'), 3);
    expect(await store.progress.stars('cat_sort', 3), 2);
    expect(await store.settings.getBool(SettingsRepository.adFree), isTrue);
    await store.close();
  });

  test('잔액 부족 시 입양 실패하고 아무것도 바뀌지 않음', () async {
    final store = await openStore();
    await expectLater(
      store.cats.adopt(
        breedId: 'black',
        name: 'x',
        currency: Currency.bungeoppang,
        price: 999,
      ),
      throwsA(isA<InsufficientFundsException>()),
    );
    expect(await store.cats.count(), 1);
    expect(
      await store.wallet.balance(Currency.bungeoppang),
      SaveStore.starterBungeoppang,
    );
    await store.close();
  });
}
