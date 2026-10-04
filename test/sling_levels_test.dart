import 'package:catspuzzle/games/cat_sling/sling_levels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('같은 번호는 항상 같은 스테이지', () {
    final a = SlingLevels.build(7), b = SlingLevels.build(7);
    expect(a.blocks.length, b.blocks.length);
    expect(a.mice.map((m) => m.x), b.mice.map((m) => m.x));
  });

  test('모든 스테이지에 쥐가 있고 고양이가 쥐보다 많다', () {
    for (var n = 1; n <= 60; n++) {
      final l = SlingLevels.build(n);
      expect(l.mice, isNotEmpty, reason: 'level $n');
      expect(
        l.shots,
        greaterThanOrEqualTo(l.mice.length.clamp(0, 7)),
        reason: 'level $n',
      );
      expect(l.shots, lessThanOrEqualTo(7));
    }
  });

  test('구조물은 정해진 구역 안, 땅 위에 있다', () {
    for (var n = 1; n <= 60; n++) {
      for (final b in SlingLevels.build(n).blocks) {
        expect(
          b.x - b.halfW,
          greaterThanOrEqualTo(SlingLevels.minX - 0.8),
          reason: 'level $n',
        );
        expect(
          b.x + b.halfW,
          lessThanOrEqualTo(SlingLevels.maxX + 0.8),
          reason: 'level $n',
        );
        expect(b.y + b.halfH, lessThanOrEqualTo(1e-9), reason: 'level $n');
      }
    }
  });

  test('쥐는 땅이 아니라 항상 사물 위에 있다', () {
    for (var n = 1; n <= 60; n++) {
      final l = SlingLevels.build(n);
      for (final m in l.mice) {
        final r = m.boss ? SlingLevels.bossRadius : SlingLevels.mouseRadius;
        final feet = m.y + r;
        expect(feet, lessThan(-0.1), reason: 'level $n 쥐가 땅 위');
        // 발 바로 밑에 블록 윗면이 있어야 한다
        final under = l.blocks.any(
          (b) =>
              (b.y - b.halfH - feet).abs() < 1e-6 &&
              (m.x - b.x).abs() <= b.halfW,
        );
        expect(under, isTrue, reason: 'level $n 쥐 밑에 받침이 없음');
      }
    }
  });

  test('이웃한 탑의 판자는 겹치지 않는다', () {
    for (var n = 1; n <= 60; n++) {
      final planks = SlingLevels.build(n).blocks
          .where((b) => b.halfW > 1)
          .toList();
      for (final p in planks) {
        for (final q in planks) {
          if (identical(p, q) || (p.x - q.x).abs() < 0.01) continue;
          expect(
            (p.x - q.x).abs(),
            greaterThan(p.halfW + q.halfW),
            reason: 'level $n',
          );
        }
      }
    }
  });

  test('별: 남은 고양이 2+ → 3개, 1 → 2개, 0 → 1개', () {
    final l = SlingLevels.build(1);
    expect(
      [l.starsFor(3), l.starsFor(2), l.starsFor(1), l.starsFor(0)],
      [3, 3, 2, 1],
    );
  });

  test('분신 수: 대부분 +2~+3, +4~+5는 사물이 아주 많은 판에서만', () {
    expect(SlingLevel.splitCountFor(4), 2);
    expect(SlingLevel.splitCountFor(21), 2);
    expect(SlingLevel.splitCountFor(22), 3);
    expect(SlingLevel.splitCountFor(33), 3);
    expect(SlingLevel.splitCountFor(34), 4);
    expect(SlingLevel.splitCountFor(37), 5);
    final counts = [for (var n = 1; n <= 300; n++) SlingLevels.build(n).splitCount];
    final big = counts.where((c) => c >= 4).length;
    expect(big, lessThan(300 * 0.15), reason: '+4 이상이 너무 흔함');
    expect(counts.where((c) => c == 5).length, lessThan(300 * 0.05));
    expect(SlingLevels.build(1).splitCount, 2);
  });
}
