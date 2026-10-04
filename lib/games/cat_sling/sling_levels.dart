import 'dart:math';

enum SlingTime { day, sunset, night }

/// 블록 재질. 튼튼할수록 무겁고 잘 안 부서진다.
enum BlockKind {
  /// 골판지 상자. 잘 부서진다.
  cardboard(hp: 1.0, density: 0.5),

  /// 나무 판자.
  wood(hp: 1.8, density: 0.8),

  /// 벽돌. 고양이를 세게 쏴야 부서진다.
  brick(hp: 4.0, density: 2.2);

  const BlockKind({required this.hp, required this.density});
  final double hp;
  final double density;
}

/// 블록 하나. 좌표는 월드(m), 땅(y=0) 기준 위쪽이 음수. [x], [y]는 중심.
class BlockSpec {
  const BlockSpec(this.kind, this.x, this.y, this.halfW, this.halfH);
  final BlockKind kind;
  final double x;
  final double y;
  final double halfW;
  final double halfH;
}

class MouseSpec {
  const MouseSpec(this.x, this.y, {this.boss = false});
  final double x;
  final double y;

  /// 뚱뚱한 대장 쥐. 크고 한 번 더 맞아야 잡힌다.
  final bool boss;
}

class SlingLevel {
  const SlingLevel({
    required this.number,
    required this.blocks,
    required this.mice,
    required this.shots,
  });

  final int number;
  final List<BlockSpec> blocks;
  final List<MouseSpec> mice;

  /// 쏠 수 있는 고양이 수.
  final int shots;

  /// 두 스테이지마다 낮 → 노을 → 밤.
  SlingTime get time => SlingTime.values[(number - 1) ~/ 2 % 3];

  /// 분신 아이템으로 늘어나는 고양이 수 (+2 ~ +5).
  /// 쉬운 스테이지는 +2로 시작하고, 부술 게 많아질수록 늘어난다.
  /// +4는 상위 10%, +5는 상위 3% 정도로 사물이 아주 많은 판에서만 나온다.
  int get splitCount => splitCountFor(blocks.length + mice.length);

  static int splitCountFor(int objects) =>
      2 + [22, 34, 37].where((n) => objects >= n).length;

  /// 남은 고양이 수로 별 계산.
  int starsFor(int shotsLeft) => shotsLeft >= 2
      ? 3
      : shotsLeft == 1
      ? 2
      : 1;
}

/// 스테이지 번호로 항상 같은 모양을 만든다 (레벨 파일 없이 무한 스테이지).
abstract final class SlingLevels {
  static const mouseRadius = 0.5;
  static const bossRadius = 0.72;

  /// 구조물이 놓이는 x 범위.
  static const minX = 5.0;
  static const maxX = 27.0;

  static const _box = 0.6; // 상자 반 변
  static const _plankHalfH = 0.18;

  static SlingLevel build(int number) {
    final rng = Random(number * 7919 + 17);
    final towers = min(1 + number ~/ 3, 3);
    final floorsMax = min(1 + number ~/ 2, 3);
    final blocks = <BlockSpec>[];
    final mice = <MouseSpec>[];

    // 탑들을 오른쪽 구역에 겹치지 않게 나눠 세운다.
    final slot = (maxX - minX) / towers;
    for (var t = 0; t < towers; t++) {
      final floors = 1 + rng.nextInt(floorsMax);
      final cx = minX + slot * (t + 0.5);
      // 기둥 중심 간 반 거리. 판자 끝(span + _box)이 옆 탑과 겹치지 않게.
      final span = min(slot / 2 - _box - 0.15, 1.4 + rng.nextDouble() * 1.2);
      var base = 0.0; // 이 층이 올라설 바닥 높이 (음수로 쌓인다)

      for (var f = 0; f < floors; f++) {
        final kind = _kindFor(number, rng);
        final pillarH = _box * (1 + rng.nextInt(2)); // 반 높이 0.6 또는 1.2
        // 기둥 두 개
        for (final dx in [-span, span]) {
          blocks.add(BlockSpec(kind, cx + dx, base - pillarH, _box, pillarH));
        }
        // 기둥 사이 쥐 (위층이 무너지면 깔린다). 쥐는 항상 사물 위에 둔다:
        // 2층부터는 아래층 판자 위, 1층은 기둥이 높을 때만 상자를 깔고 그 위에.
        if (rng.nextDouble() < 0.55) {
          if (f > 0) {
            mice.add(MouseSpec(cx, base - mouseRadius));
          } else if (pillarH > _box) {
            blocks.add(BlockSpec(BlockKind.cardboard, cx, -_box, _box, _box));
            mice.add(MouseSpec(cx, -_box * 2 - mouseRadius));
          }
        }
        base -= pillarH * 2;
        // 지붕 판자
        blocks.add(
          BlockSpec(
            _kindFor(number, rng),
            cx,
            base - _plankHalfH,
            span + _box,
            _plankHalfH,
          ),
        );
        base -= _plankHalfH * 2;
      }
      // 꼭대기: 상자 하나 또는 쥐
      if (rng.nextBool()) {
        blocks.add(BlockSpec(BlockKind.cardboard, cx, base - _box, _box, _box));
        base -= _box * 2;
      }
      final boss = number >= 4 && t == towers - 1 && rng.nextDouble() < 0.5;
      final r = boss ? bossRadius : mouseRadius;
      mice.add(MouseSpec(cx, base - r, boss: boss));
    }

    return SlingLevel(
      number: number,
      blocks: blocks,
      mice: mice,
      shots: min(mice.length + 2, 7),
    );
  }

  /// 초반은 상자 위주, 뒤로 갈수록 나무/벽돌이 섞인다.
  static BlockKind _kindFor(int number, Random rng) {
    final roll = rng.nextDouble();
    if (number >= 5 && roll < min(0.1 + number * 0.02, 0.35)) {
      return BlockKind.brick;
    }
    if (number >= 2 && roll < 0.6) return BlockKind.wood;
    return BlockKind.cardboard;
  }
}
