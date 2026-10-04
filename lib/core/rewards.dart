/// 한 판 보상.
class GameReward {
  const GameReward({required this.bungeoppang, required this.catExp});
  final int bungeoppang;
  final int catExp;

  static const none = GameReward(bungeoppang: 0, catExp: 0);
}

/// 게임별 보상 공식을 한곳에서 관리한다.
/// 게임마다 획득량이 제각각 늘어나 재화가 흔해지는 걸 막기 위함.
abstract final class RewardPolicy {
  /// 붕어빵 1개당 필요한 점수.
  static const _scorePerBungeoppang = {'cat_merge': 50};
  static const _scorePerExp = {'cat_merge': 10, 'cat_sling': 100};

  /// 한 판에서 받을 수 있는 붕어빵 상한.
  static const maxBungeoppangPerPlay = 100;

  /// 도감 첫 발견 보상.
  static const codexCommon = 5;
  static const codexRare = 15;

  static GameReward forScore(String gameId, int score) {
    if (score <= 0) return GameReward.none;
    final fish = (score ~/ (_scorePerBungeoppang[gameId] ?? 100))
        .clamp(1, maxBungeoppangPerPlay);
    return GameReward(bungeoppang: fish, catExp: _exp(gameId, score));
  }

  /// 스테이지 클리어 보상. 첫 클리어는 크게, 재도전은 조금.
  static GameReward forStage(String gameId,
          {required int stars, required bool firstClear, required int score}) =>
      GameReward(
        bungeoppang: firstClear ? 20 + stars * 10 : stars * 3,
        catExp: _exp(gameId, score),
      );

  static int codexReward({required bool rare}) => rare ? codexRare : codexCommon;

  static int _exp(String gameId, int score) =>
      score ~/ (_scorePerExp[gameId] ?? 20);
}
