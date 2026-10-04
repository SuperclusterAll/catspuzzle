// GameWidget 없이 게임을 띄우려고 flame 내부 lifecycle API(load/mount)를 직접 쓴다.
// ignore_for_file: invalid_use_of_internal_member

import 'package:catspuzzle/games/cat_merge/merge_sfx.dart';
import 'package:catspuzzle/games/cat_sling/cat_sling_game.dart';
import 'package:catspuzzle/games/cat_sling/sling_levels.dart';
import 'package:flame_forge2d/flame_forge2d.dart' show CircleShape;

import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// GameWidget 없이 게임을 띄운다 (flame_test의 initializeGame과 같은 순서).
Future<CatSlingGame> _boot(void Function(SlingResult) onEnd) async {
  Sfx.enabled = false;
  final game = CatSlingGame(onEnd: onEnd);
  game.onGameResize(Vector2(900, 420));
  await game.load();
  game.mount();
  game.update(0);
  await game.ready();
  return game;
}

void _run(CatSlingGame g, double seconds) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    g.update(1 / 60);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('가만히 두면 구조물이 스스로 무너지지 않는다', () async {
    for (var n = 1; n <= 20; n++) {
      final g = await _boot((_) {});
      final level = SlingLevels.build(n);
      g.startLevel(level);
      await g.ready();
      _run(g, 4);
      expect(
        g.world.children.whereType<SlingBlock>().length,
        level.blocks.length,
        reason: 'level $n 블록이 저절로 부서짐',
      );
      expect(g.miceLeft.value, level.mice.length, reason: 'level $n 쥐가 저절로 잡힘');
      expect(g.score.value, 0);
    }
  });

  test('한 방 제대로 맞으면 뭔가 부서지고, 결국 끝난다', () async {
    SlingResult? result;
    final g = await _boot((r) => result = r);
    g.startLevel(SlingLevels.build(1));
    await g.ready();
    _run(g, 1);
    // 수평에 가깝게 최대로 당겨 쏜다
    var hits = 0;
    for (var shot = 0; shot < 8 && result == null; shot++) {
      g.pull.setValues(
        -CatSlingGame.maxPull * 0.97,
        CatSlingGame.maxPull * 0.24,
      );
      g.fire();
      await g.ready();
      _run(g, 9);
      hits = g.score.value;
    }
    expect(hits, greaterThan(0), reason: '최대로 쏴도 아무것도 안 부서짐');
    expect(result, isNotNull, reason: '고양이를 다 써도 판이 안 끝남');
  });

  test('별을 먹은 무적 고양이는 탑을 뚫고 지나가며 쓸어버린다', () async {
    final g = await _boot((_) {});
    final level = SlingLevels.build(4);
    g.startLevel(level);
    await g.ready();
    _run(g, 1);
    final cat = SlingCat(
      SlingShot.standard,
      start: Vector2(-1, -1.2),
      velocity: Vector2(15, 0),
    );
    g.world.add(cat);
    await g.ready();
    cat.goSuper();
    // 부서진 블록 제거는 Flame 큐에서 비동기로 처리되므로 중간중간 기다린다.
    for (var i = 0; i < 6; i++) {
      _run(g, 0.2);
      await g.ready();
    }
    g.update(0);
    final left = g.world.children.whereType<SlingBlock>().length;
    expect(left, lessThan(level.blocks.length - 3), reason: '무적인데 거의 못 부숨');
  });

  test('새에 맞으면 위로 튀고 냥펀치가 다시 충전된다', () async {
    final g = await _boot((_) {});
    g.startLevel(SlingLevels.build(1));
    await g.ready();
    final bird = SlingBird(start: Vector2(0, -8), speed: 0, phase: 0);
    final cat = SlingCat(
      SlingShot.standard,
      start: Vector2(-2, -8),
      velocity: Vector2(12, 2),
    );
    g.world.addAll([bird, cat]);
    await g.ready();
    cat.usePower();
    expect(cat.canPower, isFalse);
    for (var i = 0; i < 30 && g.score.value == 0; i++) {
      g.update(1 / 60);
    }
    expect(g.score.value, 300, reason: '새에 안 맞음');
    expect(cat.body.linearVelocity.y, lessThan(0), reason: '위로 안 튐');
    g.update(0.1);
    expect(cat.canPower, isTrue, reason: '냥펀치 재충전 안 됨');
  });

  test('쏜 고양이는 다음 차례가 오고 2~3초 뒤 사라진다', () async {
    final g = await _boot((_) {});
    g.startLevel(SlingLevels.build(6));
    await g.ready();
    _run(g, 1);
    // 맵 안에 떨어지게 약하게 쏜다
    g.pull.setValues(-CatSlingGame.maxPull * 0.5, CatSlingGame.maxPull * 0.3);
    g.fire();
    await g.ready();
    // 무너지는 걸 지켜본 뒤 다음 차례가 온다 (최대 약 6초)
    for (var t = 0.0; t < 10 && !g.canAim; t += 1 / 60) {
      g.update(1 / 60);
    }
    expect(g.canAim, isTrue, reason: '다음 고양이가 안 올라옴');
    await g.ready();
    expect(
      g.world.children.whereType<SlingCat>(),
      isNotEmpty,
      reason: '차례가 오자마자 사라지면 안 됨',
    );
    _run(g, CatSlingGame.spentLinger + 0.2);
    await g.ready();
    g.update(0);
    expect(
      g.world.children.whereType<SlingCat>(),
      isEmpty,
      reason: '2~3초 뒤에도 안 사라짐',
    );
  });

  test('카메라: 확대 → 전체 → 새총 연출, 발사하면 고양이를 따라간다', () async {
    final g = await _boot((_) {});
    g.startLevel(SlingLevels.build(7));
    await g.ready();
    g.update(1 / 60);
    final closeW = g.camera.viewfinder.visibleGameSize!.x;
    var maxW = closeW;
    for (var t = 0.0; t < 8 && g.introPlaying; t += 1 / 60) {
      g.update(1 / 60);
      maxW = max(maxW, g.camera.viewfinder.visibleGameSize!.x);
    }
    expect(g.introPlaying, isFalse, reason: '연출이 안 끝남');
    final normalW = g.camera.viewfinder.visibleGameSize!.x;
    expect(closeW, lessThan(normalW), reason: '처음에 확대돼 있지 않음');
    expect(maxW, greaterThan(normalW), reason: '전체 보기로 안 줄어듦');
    final slingCamX = g.camera.viewfinder.position.x;

    g.pull.setValues(-CatSlingGame.maxPull, CatSlingGame.maxPull * 0.6);
    g.fire();
    await g.ready();
    _run(g, 1.0);
    expect(
      g.camera.viewfinder.position.x,
      greaterThan(slingCamX + 1),
      reason: '날아가는 고양이를 안 따라감',
    );
  });

  test('부딪힌 뒤 무너지는 동안은 다음 차례가 오지 않는다', () async {
    final g = await _boot((_) {});
    g.startLevel(SlingLevels.build(7));
    await g.ready();
    _run(g, 5);
    g.pull.setValues(-CatSlingGame.maxPull, CatSlingGame.maxPull * 0.45);
    g.fire();
    await g.ready();
    var t = 0.0;
    for (; t < 11 && !g.canAim; t += 1 / 60) {
      g.update(1 / 60);
    }
    expect(g.canAim, isTrue);
    expect(t, greaterThan(3.0), reason: '너무 빨리 돌아옴');
    expect(t, lessThan(10), reason: '너무 오래 기다림');
  });

  test('두 손가락으로 확대/축소하면 화면 폭이 바뀌고 한계가 있다', () async {
    final g = await _boot((_) {});
    g.startLevel(SlingLevels.build(3));
    await g.ready();
    _run(g, 5);
    final w0 = g.camera.viewfinder.visibleGameSize!.x;
    g.pinchZoom(0.6);
    g.update(1 / 60);
    final zoomedIn = g.camera.viewfinder.visibleGameSize!.x;
    expect(zoomedIn, lessThan(w0));
    for (var i = 0; i < 10; i++) {
      g.pinchZoom(2);
    }
    g.update(1 / 60);
    final far = g.camera.viewfinder.visibleGameSize!.x;
    expect(far, greaterThan(w0));
    expect(far, lessThan(45), reason: '맵보다 더 멀리 봄');
  });

  test('고양이가 쥐에 살짝만 닿아도 잡는다', () async {
    final g = await _boot((_) {});
    g.startLevel(SlingLevels.build(1));
    await g.ready();
    _run(g, 1.5);
    final mouse = g.world.children.whereType<SlingMouse>().first;
    final at = mouse.body.position.clone();
    // 쥐 바로 옆에서 아주 천천히 다가간다
    final cat = SlingCat(
      SlingShot.standard,
      start: at - Vector2(SlingShot.size + SlingLevels.mouseRadius + 0.2, 0),
      velocity: Vector2(1.2, 0),
    );
    g.world.add(cat);
    await g.ready();
    final before = g.miceLeft.value;
    for (var i = 0; i < 60 && g.miceLeft.value == before; i++) {
      g.update(1 / 60);
    }
    expect(g.miceLeft.value, before - 1, reason: '닿았는데 안 잡힘');
  });

  Future<(CatSlingGame, SlingCat)> flyingCat(
    int level, {
    Vector2? at,
    Vector2? v,
    void Function(String)? onLetter,
  }) async {
    Sfx.enabled = false;
    final g = CatSlingGame(onEnd: (_) {}, onLetter: onLetter);
    g.onGameResize(Vector2(900, 420));
    await g.load();
    g.mount();
    g.update(0);
    await g.ready();
    g.startLevel(SlingLevels.build(level));
    await g.ready();
    _run(g, 1);
    final cat = SlingCat(
      SlingShot.standard,
      start: at ?? Vector2(-2, -6),
      velocity: v ?? Vector2(10, 0),
    );
    g.world.add(cat);
    await g.ready();
    return (g, cat);
  }

  test('분신: +N 마리로 흩어진다', () async {
    final (g, cat) = await flyingCat(3);
    g.debugCollect(cat, PickupKind.split, count: 4);
    await g.ready();
    expect(g.world.children.whereType<SlingCat>().length, 5);
  });

  test('폭탄: 다음에 부딪힌 곳 주변을 부순다', () async {
    final (g, cat) = await flyingCat(4, at: Vector2(4, -2), v: Vector2(14, 0));
    final before = g.world.children.whereType<SlingBlock>().length;
    g.debugCollect(cat, PickupKind.bomb);
    expect(cat.hasBomb, isTrue);
    for (var i = 0; i < 6; i++) {
      _run(g, 0.2);
      await g.ready();
    }
    g.update(0);
    expect(cat.hasBomb, isFalse, reason: '부딪혔는데 안 터짐');
    expect(
      g.world.children.whereType<SlingBlock>().length,
      lessThan(before - 2),
      reason: '폭발로 거의 안 부서짐',
    );
  });

  test('버섯: 고양이가 커진다', () async {
    final (g, cat) = await flyingCat(2);
    final r0 = cat.radius;
    g.debugCollect(cat, PickupKind.giant);
    g.update(1 / 60);
    expect(cat.radius, greaterThan(r0 * 1.5));
    expect(
      (cat.body.fixtures.first.shape as CircleShape).radius,
      closeTo(cat.radius, 1e-6),
      reason: '물리 크기는 그대로',
    );
  });

  test('알파벳 A~F를 다 모으면 보너스 점수, 화면에 알린다', () async {
    final got = <String>[];
    final (g, cat) = await flyingCat(1, onLetter: got.add);
    g.letters = {'A', 'B', 'C', 'D', 'E'};
    final s0 = g.score.value;
    g.debugCollect(cat, PickupKind.letter, letter: 'F');
    expect(got, ['F']);
    expect(g.letters.length, 6);
    expect(
      g.score.value - s0,
      greaterThanOrEqualTo(CatSlingGame.letterBonusScore),
    );
  });

  test('선물은 새총과 첫 구조물 사이에서만 떠다닌다', () async {
    for (final n in [1, 4, 9]) {
      final (g, _) = await flyingCat(n);
      final (left, right) = g.pickupBand;
      final firstBlock = SlingLevels.build(n).blocks
          .map((b) => b.x - b.halfW)
          .reduce(min);
      expect(left, greaterThan(CatSlingGame.slingX + 2));
      expect(right, lessThan(firstBlock), reason: 'level $n');
    }
  });
}
