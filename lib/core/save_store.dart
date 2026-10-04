import 'package:sqflite/sqflite.dart';

import 'db/app_database.dart';
import 'items.dart';
import 'repositories/cat_repository.dart';
import 'repositories/codex_repository.dart';
import 'repositories/inventory_repository.dart';
import 'repositories/progress_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/wallet_repository.dart';
import 'rewards.dart';

/// 코어 저장소 묶음. 앱 시작 시 한 번 열고 게임 모듈에 넘긴다.
class SaveStore {
  SaveStore._(this.database)
      : wallet = WalletRepository(database.db),
        progress = ProgressRepository(database.db),
        settings = SettingsRepository(database.db),
        codex = CodexRepository(database.db),
        inventory = InventoryRepository(database.db) {
    cats = CatRepository(database.db, wallet);
  }

  final AppDatabase database;
  final WalletRepository wallet;
  final ProgressRepository progress;
  final SettingsRepository settings;
  final CodexRepository codex;
  final InventoryRepository inventory;
  late final CatRepository cats;

  static const starterBreed = 'cheese_tabby';
  static const starterName = '나비';
  static const starterBungeoppang = 100;

  static Future<SaveStore> open({AppDatabase? database}) async {
    final store = SaveStore._(database ?? await AppDatabase.open());
    await store._ensureStarterData();
    return store;
  }

  /// 첫 실행 시 기본 고양이와 시작 재화 지급. 이미 받았으면 아무것도 안 한다.
  Future<void> _ensureStarterData() async {
    if (await settings.getBool(_starterKey)) return;
    // 중간에 앱이 종료돼도 중복 지급되지 않도록 한 트랜잭션으로 묶는다.
    await database.db.transaction((txn) async {
      await txn.insert('cats', {
        'breed_id': starterBreed,
        'name': starterName,
        'obtained_at': DateTime.now().millisecondsSinceEpoch,
      });
      await wallet.applyIn(txn, Currency.bungeoppang, starterBungeoppang,
          reason: 'starter');
      await txn.insert('settings', {'key': _starterKey, 'value': '1'});
    });
  }

  static const _starterKey = 'starter_granted';

  /// 게임 한 판 종료 처리: 기록 저장, 붕어빵 지급, 출전 고양이 경험치.
  /// 무한 모드 게임은 끝날 때 이것만 호출한다.
  Future<GameReward> finishPlay(
      {required String gameId, required int score, required int catId}) async {
    final reward = RewardPolicy.forScore(gameId, score);
    await database.db.transaction((txn) async {
      await ProgressRepository(txn).recordPlay(gameId, score);
      await _grant(txn, reward, gameId, catId);
    });
    return reward;
  }

  /// 스테이지 클리어 처리. 별/점수는 더 좋을 때만 갱신된다.
  Future<GameReward> finishStage({
    required String gameId,
    required int level,
    required int stars,
    required int score,
    required int catId,
  }) =>
      database.db.transaction((txn) async {
        final progress = ProgressRepository(txn);
        final firstClear = await progress.stars(gameId, level) == 0;
        final reward = RewardPolicy.forStage(gameId,
            stars: stars, firstClear: firstClear, score: score);
        await progress.clearLevel(gameId, level, stars: stars, score: score);
        await _grant(txn, reward, gameId, catId);
        return reward;
      });

  /// 도감 첫 발견이면 기록하고 보상 붕어빵 수를 돌려준다. 이미 있으면 0.
  Future<int> discover(String gameId, String entryId, {required bool rare}) =>
      database.db.transaction((txn) async {
        if (!await CodexRepository(txn).add(gameId, entryId)) return 0;
        final fish = RewardPolicy.codexReward(rare: rare);
        await wallet.applyIn(txn, Currency.bungeoppang, fish,
            reason: 'codex', source: gameId);
        return fish;
      });

  /// 붕어빵으로 아이템 1개 구매. 잔액 부족 시 [InsufficientFundsException].
  Future<void> buyItem(ItemId item) => database.db.transaction((txn) async {
        await wallet.applyIn(txn, Currency.bungeoppang, -item.price,
            reason: 'buy_item', source: item.key);
        await InventoryRepository(txn).add(item, 1);
      });

  Future<void> _grant(
      Transaction txn, GameReward reward, String gameId, int catId) async {
    if (reward.bungeoppang > 0) {
      await wallet.applyIn(txn, Currency.bungeoppang, reward.bungeoppang,
          reason: 'game_reward', source: gameId);
    }
    if (reward.catExp > 0) {
      await txn.rawUpdate('UPDATE cats SET exp = exp + ? WHERE id = ?',
          [reward.catExp, catId]);
    }
  }

  Future<void> close() => database.close();
}
