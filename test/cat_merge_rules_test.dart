import 'package:catspuzzle/core/rewards.dart';
import 'package:catspuzzle/games/cat_merge/cat_tiers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('단계가 오를수록 크기와 합체 점수가 커짐', () {
    for (var i = 1; i < catTiers.length; i++) {
      expect(catTiers[i].radius, greaterThan(catTiers[i - 1].radius));
      expect(mergePoints(i), greaterThan(mergePoints(i - 1)));
    }
    // 가장 큰 고양이도 상자(폭 10)에 들어가야 함
    expect(catTiers.last.radius * 2, lessThan(10));
    expect(lionTier, catTiers.length - 1);
    expect(fatTier, lessThan(lionTier));
  });

  test('품종마다 털색 이름이 CatCoat 수만큼 있고 도감 id는 고유', () {
    for (final t in catTiers) {
      expect(t.coats.length, CatCoat.values.length, reason: t.name);
    }
    final ids = {
      for (var t = 0; t < catTiers.length; t++)
        for (final c in CatCoat.values) codexId(t, c),
    };
    expect(ids.length, codexTotal);
  });

  test('연쇄는 간격 안의 합체만 이어지고 배수는 상한이 있음', () {
    final c = ChainCounter(window: 0.8, maxMultiplier: 5);
    expect(c.active, isFalse);
    expect(c.hit(), 1);
    expect(c.active, isTrue);
    c.tick(0.5);
    expect(c.hit(), 2);
    c.tick(0.9);
    expect(c.active, isFalse);
    expect(c.hit(), 1);
    for (var i = 0; i < 10; i++) {
      c.tick(0.1);
      c.hit();
    }
    expect(c.multiplier, 5);
  });

  test('보상은 점수에 비례하고 상한이 있음', () {
    expect(RewardPolicy.forScore('cat_merge', 0).bungeoppang, 0);
    expect(RewardPolicy.forScore('cat_merge', 1000).bungeoppang, 20);
    expect(
      RewardPolicy.forScore('cat_merge', 999999).bungeoppang,
      RewardPolicy.maxBungeoppangPerPlay,
    );
  });
}
