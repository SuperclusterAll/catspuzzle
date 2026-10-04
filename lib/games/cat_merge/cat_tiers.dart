import 'dart:math';
import 'dart:ui';


/// 털색 변형. 합체는 단계(품종) 기준이라 털색이 달라도 같은 품종이면 합쳐진다.
/// 이름이 SVG 파일명(assets/cats/head_t{단계}_{name}.svg)이 된다.
enum CatCoat {
  base(65),
  alt(28),
  rare(7);

  const CatCoat(this.weight);

  /// 등장 가중치.
  final int weight;

  bool get isRare => this == rare;
}

class CatTier {
  const CatTier(this.name, this.radius, this.fur, this.coats);

  /// 품종 이름.
  final String name;

  /// 물리 월드 단위(m).
  final double radius;

  /// 기본 털색 (합체 순서표 등 대표 색).
  final Color fur;

  /// [CatCoat] 순서의 털색 이름.
  final List<String> coats;

  String coatName(CatCoat c) => coats[c.index];
}

/// 작은 것부터 큰 것 순. 같은 단계 둘이 닿으면 다음 단계로 합체.
/// 단계마다 품종이 달라 생김새(귀, 털 모양, 무늬, 눈 색)로도 구분된다.
const catTiers = [
  CatTier('터키시 앙고라', 0.42, Color(0xFFFFFFFF), ['흰색', '크림', '실버']),
  CatTier('코리안숏헤어', 0.56, Color(0xFFE8943A), ['치즈', '크림', '삼색']),
  CatTier('러시안블루', 0.72, Color(0xFF7F8FA6), ['블루', '실버블루', '라일락']),
  CatTier('샴', 0.88, Color(0xFFF3E6D3), ['실 포인트', '블루 포인트', '레드 포인트']),
  CatTier('고등어', 1.06, Color(0xFF9A948A), ['고등어', '실버 태비', '브라운 태비']),
  CatTier('턱시도', 1.28, Color(0xFF2F2A28), ['턱시도', '스모크', '블루 턱시도']),
  CatTier('스코티시폴드', 1.50, Color(0xFFFBF6EE), ['삼색', '크림', '블루']),
  CatTier('뱅갈', 1.74, Color(0xFFE2A24A), ['골드', '스노우', '실버']),
  CatTier('페르시안', 1.98, Color(0xFFF6E3C4), ['크림', '화이트', '친칠라']),
  CatTier('메인쿤', 2.26, Color(0xFFA0673F), ['브라운 태비', '레드 태비', '실버 태비']),
  CatTier('사자', 2.56, Color(0xFFF4C542), ['황금', '흰사자', '벚꽃']),
];

/// 합체로 만들어지면 주변을 밀쳐내는 단계 (페르시안: 털이 부풀어 밀어낸다).
const fatTier = 8;

/// 합체로 만들어지면 포효해서 작은 고양이를 쫓아내는 단계 (최상위).
const lionTier = 10;

/// 포효에 도망가는 단계 (이하).
const roarMaxTier = 1;

/// 떨어뜨릴 수 있는 건 앞 5단계만. 작은 것일수록 자주 나온다.
const dropWeights = [30, 25, 20, 15, 10];

/// 합체로 [tier]가 만들어질 때 점수 (삼각수).
int mergePoints(int tier) => (tier + 1) * (tier + 2) ~/ 2;

/// 사자 둘이 합쳐져 사라질 때 점수.
const topMergePoints = 100;

/// 출전 고양이가 있으면 희귀 털색이 이만큼 더 잘 나온다.
const partnerRareBoost = 2.0;

String codexId(int tier, CatCoat coat) => 't${tier}_${coat.name}';

final codexTotal = catTiers.length * CatCoat.values.length;

/// 짧은 간격으로 이어지는 합체를 연쇄로 센다.
class ChainCounter {
  ChainCounter({this.window = 0.8, this.maxMultiplier = 5});
  final double window;
  final int maxMultiplier;

  int chain = 0;
  double _since = double.infinity;

  void tick(double dt) => _since += dt;

  /// 합체 1회 기록 후 현재 연쇄 수를 돌려준다.
  int hit() {
    chain = _since <= window ? chain + 1 : 1;
    _since = 0;
    return chain;
  }

  int get multiplier => min(chain, maxMultiplier);

  /// 아직 연쇄가 이어질 수 있는 시간 안인지.
  bool get active => chain > 0 && _since <= window;

  void reset() {
    chain = 0;
    _since = double.infinity;
  }
}
