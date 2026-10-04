import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show Colors, FontWeight, HSVColor, TextPainter, TextSpan, TextStyle;

import '../../theme/app_tokens.dart';
import '../cat_merge/cat_art.dart';
import '../cat_merge/cat_tiers.dart';
import '../cat_merge/merge_fx.dart';
import '../cat_merge/merge_sfx.dart';
import 'sling_levels.dart';

part 'sling_camera.dart';
part 'sling_extras.dart';
part 'sling_scene.dart';

/// 날아가는 중 화면을 톡 치면 쓰는 품종별 기술.
enum SlingPower {
  /// 작은 고양이: 셋으로 갈라진다.
  split('분신술'),

  /// 중간 고양이: 앞으로 돌진.
  dash('냥펀치'),

  /// 큰 고양이: 수직으로 내리꽂는다.
  slam('엉덩방아');

  const SlingPower(this.label);
  final String label;

  static SlingPower of(int tier) => tier <= 1
      ? split
      : tier <= 3
      ? dash
      : slam;
}

/// 새총에 올릴 고양이 한 마리.
class SlingShot {
  const SlingShot(this.tier, this.coat);
  final int tier;
  final CatCoat coat;

  /// 새총에는 늘 같은 고양이가 오른다: 중간 크기의 치즈 코숏.
  static const standard = SlingShot(1, CatCoat.base);

  /// 생김새와 상관없이 크기·무게는 모두 같다.
  static const size = 0.72;

  SlingPower get power => SlingPower.dash;
  double get radius => size;
}

class SlingResult {
  const SlingResult({
    required this.cleared,
    required this.score,
    required this.stars,
  });
  final bool cleared;
  final int score;

  /// 클리어 못 했으면 0.
  final int stars;
}

/// 새총으로 고양이를 날려 쥐를 잡는 스테이지 게임.
///
/// 드래그로 당겼다 놓으면 발사, 날아가는 중 탭하면 품종 기술.
/// 쥐를 다 잡으면 클리어, 고양이를 다 쓰고도 남아 있으면 실패.
class CatSlingGame extends Forge2DGame with DragCallbacks, TapCallbacks {
  CatSlingGame({required this.onEnd, this.onLetter, Random? random})
    : _rng = random ?? Random(),
      super(gravity: Vector2(0, 20));

  static const id = 'cat_sling';

  // 월드 좌표(m). 땅이 y=0, 위쪽이 음수.
  static const slingX = -6.6;
  static const slingY = -2.8;
  static const maxPull = 2.2;
  static const maxSpeed = 29.0;

  /// 시작 직후 구조물이 자리 잡는 동안은 부서지지 않는다.
  static const _grace = 0.7;

  static const miceScore = 500;
  static const bossScore = 1500;
  static const shotBonus = 1000;

  final void Function(SlingResult) onEnd;

  /// 알파벳을 먹을 때마다. 모은 글자 저장·보너스는 화면이 맡는다.
  final void Function(String letter)? onLetter;

  /// 모을 글자들.
  static const alphabet = ['A', 'B', 'C', 'D', 'E', 'F'];

  /// 지금까지 모은 글자 (스테이지를 넘어 이어진다).
  Set<String> letters = {};
  final Random _rng;

  final score = ValueNotifier<int>(0);
  final miceLeft = ValueNotifier<int>(0);

  /// 남은 고양이들. 맨 앞이 새총 위.
  final shots = ValueNotifier<List<SlingShot>>(const []);

  SlingLevel? _level;
  SlingLevel? get level => _level;

  /// 조준 시작 지점(화면 픽셀)과 그때의 축척(m/픽셀).
  /// 당기는 동안 카메라가 줄어들어도 손가락 거리 = 당긴 거리가 유지된다.
  Vector2? _dragStart;
  double _aimScale = 0.02;
  final _pull = Vector2.zero();
  double _time = 0;
  double _clock = 0;
  double _birdIn = 2;
  double _flyT = -1;
  double _winT = -1;
  double _shakeT = 0;
  int _brokeThisShot = 0;
  bool _over = true;
  late final _cam = _SlingCamera(this);

  /// 화면 끌기: 새총 근처를 잡으면 조준, 아니면 맵 둘러보기. 두 손가락이면 확대/축소.
  bool _panning = false;
  int? _aimPointer;
  bool _zoomedOut = false;
  final _touches = <int, Vector2>{};
  double? _pinchDist;

  /// 쏜 고양이가 처음 무언가에 부딪힌 뒤 흐른 시간 (-1 = 아직).
  double _impactT = -1;

  /// 카메라가 지켜보는 곳 (무너지는 곳의 가운데).
  double? _watchX;

  /// 새총에서 이 거리(m) 안을 잡아야 조준이 된다.
  static const _grabRadius = 2.6;
  final _flying = <SlingCat>[];

  /// 다음 고양이가 올라온 뒤 쏜 고양이가 남아 있는 시간.
  static const spentLinger = 2.5;

  /// 쏘고 나서 이만큼 지나면 다음 고양이가 올라온다 (무너지는 걸 끝까지 안 기다린다).
  /// 쏘고 나서 최소 이만큼은 지켜본다.
  static const reloadDelay = 1.6;

  /// 부딪힌 뒤 소란이 가라앉길 기다리는 최소/최대 시간.
  static const _watchMin = 3.0;
  static const _watchMax = 6.5;

  /// 움직임이 멎은 뒤에도 이만큼 더 보여주고 새총으로 돌아간다.
  static const _afterQuiet = 1.2;
  double _quietT = 0;

  static final slingPos = Vector2(slingX, slingY);

  double get time => _time;

  /// 판이 끝나도 계속 흐르는 시계 (배경 애니메이션용).
  double get clock => _clock;
  SlingTime get timeOfDay => _level?.time ?? SlingTime.day;
  SlingScenePalette get palette => switch (timeOfDay) {
    SlingTime.day => SlingScenes.day,
    SlingTime.sunset => SlingScenes.sunset,
    SlingTime.night => SlingScenes.night,
  };
  bool get isOver => _over;
  Vector2 get pull => _pull;
  bool get canAim => !_over && _flyT < 0 && shots.value.isNotEmpty;

  /// 시작 연출(확대 → 전체 보기 → 새총) 중인가.
  bool get introPlaying => _introOn && _cam.moving;
  bool _introOn = false;
  SlingShot? get onSling => canAim ? shots.value.first : null;
  bool get _damageOn => _time > _grace;

  /// 날아가는 고양이 중 아직 기술을 쓸 수 있는 녀석.
  SlingCat? get _powerReady =>
      _flying.where((c) => c.isMounted && c.canPower).firstOrNull;

  @override
  Color backgroundColor() => AppColors.sky;

  @override
  Future<void> onLoad() async {
    _cam.skip();
    _cam.apply(Vector2.zero());
    world.addAll([_Sky(), _Clouds(), _Scenery(), _Ground(), _Sling()]);
    _ready = true;
    final pending = _pending;
    if (pending != null) startLevel(pending);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // 화면이 돌아가면(세로 → 가로) 폭 기준이 바뀌므로 새총 화면으로 다시 맞춘다.
    if (!isLoaded) return;
    // 가로로 돌아간 뒤: 연출 중이면 이어서, 아니면 새총 화면으로 다시 맞춘다.
    if (!introPlaying) _cam.skip();
  }

  SlingLevel? _pending;
  bool _ready = false;

  /// 스테이지를 (다시) 시작한다. 로딩 전에 불리면 로딩 끝나고 시작.
  void startLevel(SlingLevel level) {
    if (!_ready) {
      _pending = level;
      return;
    }
    _pending = null;
    for (final c
        in world.children
            .where(
              (c) =>
                  c is SlingBlock ||
                  c is SlingMouse ||
                  c is SlingCat ||
                  c is FxBurst ||
                  c is SlingBird ||
                  c is SlingSkyBody ||
                  c is SlingPickup,
            )
            .toList()) {
      c.removeFromParent();
    }
    _level = level;
    _flying.clear();
    _time = 0;
    _flyT = -1;
    _winT = -1;
    _pull.setZero();
    _dragStart = null;
    _over = false;
    score.value = 0;
    miceLeft.value = level.mice.length;
    shots.value = List.filled(level.shots, SlingShot.standard);
    world.addAll([
      for (final b in level.blocks) SlingBlock(b),
      for (final m in level.mice) SlingMouse(m),
      SlingSkyBody(level.time),
    ]);
    _birdIn = 1.2;
    _maybeSpawnPickup(start: true);
    _panning = false;
    _introOn = true;
    _cam.intro(level);
  }

  // ---------------------------------------------------------------- 입력

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (introPlaying) {
      // 손대면 연출은 건너뛴다
      _cam.skip();
      _introOn = false;
    }
    _touches[event.pointerId] = event.canvasPosition.clone();
    if (_touches.length >= 2) {
      // 두 번째 손가락: 조준·이동을 멈추고 확대/축소로
      _aimPointer = null;
      _dragStart = null;
      _pull.setZero();
      _panning = false;
      final ps = _touches.values.take(2).toList();
      _pinchDist = ps[0].distanceTo(ps[1]);
      return;
    }
    final at = screenToWorld(event.canvasPosition);
    if (canAim && at.distanceTo(slingPos) < _grabRadius) {
      _dragStart = event.canvasPosition.clone();
      _aimScale = _cam.width / max(canvasSize.x, 1);
      _aimPointer = event.pointerId;
      _zoomedOut = false;
    } else {
      _panning = true;
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _touches[event.pointerId] = event.canvasEndPosition.clone();
    final pinch = _pinchDist;
    if (pinch != null && _touches.length >= 2) {
      final ps = _touches.values.take(2).toList();
      final d = ps[0].distanceTo(ps[1]);
      if (d > 10 && pinch > 10) _cam.zoomBy(pinch / d, (ps[0].x + ps[1].x) / 2);
      _pinchDist = d;
      return;
    }
    if (_panning) {
      _cam.pan(event.canvasDelta.x);
      return;
    }
    final start = _dragStart;
    if (start == null || !canAim || event.pointerId != _aimPointer) return;
    _pull.setFrom((event.canvasEndPosition - start) * _aimScale);
    if (_pull.length > maxPull) _pull.scaleTo(maxPull);
    // 실제로 당기기 시작하면 맵 전체가 보이게 줄인다
    if (!_zoomedOut && _pull.length > 0.35) {
      _zoomedOut = true;
      _cam.showWholeMap();
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _releaseTouch(event.pointerId);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _pull.setZero();
    _dragStart = null;
    if (_zoomedOut) _cam.focusSling();
    _releaseTouch(event.pointerId);
  }

  void _releaseTouch(int id) {
    _touches.remove(id);
    if (_pinchDist != null) {
      // 확대/축소 끝: 남은 손가락은 이동으로 이어진다
      if (_touches.length < 2) _pinchDist = null;
      _panning = _touches.isNotEmpty;
      return;
    }
    if (_touches.isEmpty) _panning = false;
    if (id != _aimPointer) return;
    _aimPointer = null;
    if (_dragStart == null) return;
    _dragStart = null;
    // 살짝 건드린 건 취소
    if (_pull.length < 0.5 || !canAim) {
      _pull.setZero();
      if (_zoomedOut) _cam.focusSling();
      return;
    }
    _launch();
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (introPlaying) {
      _cam.skip();
      _introOn = false;
      return;
    }
    final cat = _powerReady;
    if (cat != null) cat.usePower();
  }

  /// 두 손가락 확대/축소를 화면 가운데에서 한 것처럼 (테스트용).
  @visibleForTesting
  void pinchZoom(double factor) => _cam.zoomBy(factor, canvasSize.x / 2);

  /// 아이템을 바로 먹은 것처럼 (테스트용).
  @visibleForTesting
  void debugCollect(
    SlingCat cat,
    PickupKind kind, {
    int count = 3,
    String letter = 'A',
  }) => collect(
    SlingPickup(kind, cat.body.position, count: count, letter: letter),
    cat,
  );

  /// 선물이 떠다니는 구역 (테스트용).
  @visibleForTesting
  (double, double) get pickupBand => _pickupBand;

  /// 지금 당긴 상태로 바로 발사 (테스트용).
  @visibleForTesting
  void fire() {
    if (canAim) _launch();
  }

  /// 당긴 만큼의 발사 속도.
  Vector2 get launchVelocity => -_pull / maxPull * maxSpeed;

  void _launch() {
    final shot = shots.value.first;
    shots.value = shots.value.sublist(1);
    final cat = SlingCat(
      shot,
      start: slingPos + _pull,
      velocity: launchVelocity,
    );
    _flying
      ..clear()
      ..add(cat);
    world.add(cat);
    _pull.setZero();
    _flyT = 0;
    _brokeThisShot = 0;
    _introOn = false;
    _impactT = -1;
    _quietT = 0;
    _watchX = null;
    Sfx.launch();
    Sfx.meow('meow_hi.wav');
  }

  /// 분신술로 늘어난 고양이.
  void addClone(SlingCat cat) {
    _flying.add(cat);
    world.add(cat);
  }

  // ---------------------------------------------------------------- 점수

  // ---------------------------------------------------------------- 하늘의 친구들

  void _spawnBird() {
    if (world.children.whereType<SlingBird>().length >= 2) return;
    final fromLeft = _rng.nextBool();
    final speed = (2.4 + _rng.nextDouble() * 1.8) * (fromLeft ? 1 : -1);
    world.add(
      SlingBird(
        start: Vector2(
          fromLeft ? _SlingCamera.mapLeft - 2 : _SlingCamera.mapRight + 2,
          -5.5 - _rng.nextDouble() * 4.5,
        ),
        speed: speed,
        phase: _rng.nextDouble() * 2 * pi,
      ),
    );
  }

  /// 선물이 떠다니는 구역: 새총 앞 ~ 첫 구조물 바로 앞.
  (double, double) get _pickupBand {
    const left = slingX + 3.2;
    final blocks = _level?.blocks ?? const <BlockSpec>[];
    var right = blocks.isEmpty
        ? SlingLevels.minX
        : blocks.map((b) => b.x - b.halfW).reduce(min);
    right -= 1.2;
    return (left, max(right, left + 2));
  }

  /// 아이템 뽑기 가중치.
  static const _itemWeights = {
    PickupKind.star: 22,
    PickupKind.split: 26,
    PickupKind.bungeoppang: 18,
    PickupKind.bomb: 20,
    PickupKind.giant: 14,
  };

  PickupKind _rollItem() {
    final total = _itemWeights.values.reduce((a, b) => a + b);
    var r = _rng.nextInt(total);
    for (final e in _itemWeights.entries) {
      if ((r -= e.value) < 0) return e.key;
    }
    return PickupKind.star;
  }

  /// 새총과 구조물 사이 하늘에 선물이 뿅. 아이템 하나, 알파벳 하나까지.
  void _maybeSpawnPickup({required bool start}) {
    final here = world.children.whereType<SlingPickup>().toList();
    final hasLetter = here.any((p) => p.kind == PickupKind.letter);
    final hasItem = here.any((p) => p.kind != PickupKind.letter);
    final missing = alphabet.where((l) => !letters.contains(l)).toList();
    if (!hasLetter &&
        missing.isNotEmpty &&
        _rng.nextDouble() < (start ? 0.8 : 0.3)) {
      _spawnPickup(
        PickupKind.letter,
        letter: missing[_rng.nextInt(missing.length)],
        quiet: start,
      );
    }
    if (!hasItem && _rng.nextDouble() < (start ? 0.75 : 0.5)) {
      _spawnPickup(_rollItem(), quiet: start);
    }
  }

  void _spawnPickup(PickupKind kind, {String letter = '', bool quiet = false}) {
    final (left, right) = _pickupBand;
    final swingX = (right - left) / 2;
    final center = Vector2(
      (left + right) / 2,
      // 오르내리는 폭을 생각해 가운데 높이에 둔다 (땅·하늘 끝에 닿지 않게).
      -5.2 - _rng.nextDouble() * 3.2,
    );
    final pickup = SlingPickup(
      kind,
      center,
      phase: _rng.nextDouble() * 2 * pi,
      xSwing: swingX * 0.85,
      count: _level?.splitCount ?? 2,
      letter: letter,
    );
    world.add(pickup);
    _burst(
      center,
      0.6,
      [AppColors.star, Colors.white],
      [FxIcon.sparkle],
      count: 8,
      life: 0.5,
    );
    if (!quiet) Sfx.codex();
  }

  /// 새에 부딪힘: 위로 튀어 오르고 냥펀치 재충전.
  void birdHit(SlingBird bird, SlingCat cat) {
    final v = cat.body.linearVelocity;
    cat.body.linearVelocity = Vector2(max(v.x, 7), min(v.y, 0) - 9);
    cat.recharge();
    score.value += 300;
    final at = bird.body.position;
    _burst(
      at,
      0.6,
      [AppColors.bird, AppColors.birdBelly, Colors.white],
      [FxIcon.sparkle, FxIcon.heart],
      count: 10,
      ring: Colors.white,
    );
    shout('퍼덕!', at, size: 28, color: AppColors.bird, dy: -24);
    shout(
      '+300 · 냥펀치 충전',
      at,
      size: 16,
      color: Colors.white,
      stroke: AppColors.bird,
      dy: 8,
      delay: 0.05,
    );
    Sfx.cucumber();
  }

  /// 해/달에 부딪힘: 바깥으로 튕겨낸다.
  void skyBump(SlingSkyBody sky, SlingCat cat) {
    final n = cat.body.position - sky.body.position;
    if (n.length2 < 1e-6) n.setValues(0, 1);
    n.normalize();
    final v = cat.body.linearVelocity;
    final along = v.dot(n);
    cat.body.linearVelocity = v - n * (2 * min(along, 0.0)) + n * 5;
    cat.react(CatFace.surprised, 0.8);
    final at = cat.body.position;
    if (sky.isMoon) {
      shout('퉁~', at, size: 28, color: AppColors.moon, stroke: AppColors.ink);
      _burst(at, 0.6, [AppColors.moon, Colors.white], [FxIcon.star], count: 8);
    } else {
      shout('앗 뜨거!', at, size: 28, color: AppColors.sunset);
      _burst(
        at,
        0.6,
        [AppColors.sun, AppColors.sunset],
        [FxIcon.sparkle],
        count: 8,
      );
    }
    Sfx.thud();
    Sfx.meow('meow_low.wav');
  }

  void collect(SlingPickup p, SlingCat cat) {
    final at = p.isMounted ? p.body.position : cat.body.position.clone();
    switch (p.kind) {
      case PickupKind.star:
        // 가장 가까운 쥐를 향해 돌진한다 (별이 높이 떠 있어도 하늘로 날아가 버리지 않게)
        final target = world.children
            .whereType<SlingMouse>()
            .where((m) => m.isMounted && !m.isRemoving)
            .map((m) => m.body.position)
            .fold<Vector2?>(
              null,
              (best, p) =>
                  best == null || p.distanceTo(at) < best.distanceTo(at)
                  ? p
                  : best,
            );
        cat.goSuper(toward: target);
        shout(
          '무적 냥!!',
          at,
          size: 40,
          color: AppColors.star,
          stroke: const Color(0xFF7A3E00),
          wobble: true,
          dy: -30,
        );
        camera.viewport.add(
          FxFlash(
            canvasSize.clone(),
            color: const Color(0xFFFFF4C2),
            strength: 0.35,
          ),
        );
        shake(0.15);
        Sfx.fanfare();
      case PickupKind.split:
        _split(cat, p.count);
        shout(
          '+${p.count} 분신!',
          at,
          size: 34,
          color: AppColors.tabby,
          wobble: true,
          dy: -30,
        );
        _burst(
          at,
          0.8,
          [AppColors.tabby, Colors.white],
          [FxIcon.paw, FxIcon.star],
          count: 12,
          ring: AppColors.tabby,
        );
        Sfx.fluff();
      case PickupKind.bomb:
        cat.armBomb();
        shout('폭탄 냥!', at, size: 32, color: AppColors.danger, dy: -30);
        Sfx.tick();
      case PickupKind.giant:
        cat.grow();
        shout(
          '거대 냥!!',
          at,
          size: 38,
          color: AppColors.danger,
          wobble: true,
          dy: -30,
        );
        shake(0.2);
        Sfx.roar();
      case PickupKind.letter:
        _collectLetter(p.letter, at);
      case PickupKind.bungeoppang:
        shots.value = [...shots.value, SlingShot.standard];
        shout('+1 냥!', at, size: 30, color: AppColors.tabby, dy: -24);
        _burst(
          at,
          0.6,
          [AppColors.bungeoppang, Colors.white],
          [FxIcon.fish],
          count: 8,
        );
        Sfx.codex();
    }
  }

  /// 먹은 자리에서 고양이가 부채꼴로 흩어진다.
  void _split(SlingCat cat, int n) {
    final v = cat.body.linearVelocity;
    final base = v.length2 < 1 ? Vector2(12, -2) : v.clone();
    for (var i = 0; i < n; i++) {
      final a = (i - (n - 1) / 2) * 0.16 + (i.isEven ? 0.08 : -0.08);
      final dir = base.clone()..rotate(a);
      addClone(
        SlingCat(SlingShot.standard, start: cat.body.position, velocity: dir)
          ..markClone(),
      );
    }
  }

  void _collectLetter(String l, Vector2 at) {
    if (letters.contains(l)) return;
    letters = {...letters, l};
    score.value += 200;
    final c = AppColors.letters[alphabet.indexOf(l)];
    shout(l, at, size: 48, color: c, wobble: true, dy: -30);
    shout(
      '${letters.length}/${alphabet.length}',
      at,
      size: 20,
      color: Colors.white,
      stroke: c,
      dy: 10,
      delay: 0.05,
    );
    _burst(
      at,
      0.8,
      [c, Colors.white],
      [FxIcon.star, FxIcon.sparkle],
      count: 12,
      ring: c,
    );
    Sfx.codex();
    if (letters.length == alphabet.length) {
      score.value += letterBonusScore;
      shout(
        'ABCDEF 완성!!',
        Vector2(camera.viewfinder.position.x, -7),
        size: 44,
        color: AppColors.star,
        stroke: const Color(0xFF7A3E00),
        wobble: true,
        delay: 0.3,
      );
      camera.viewport.add(
        FxFlash(
          canvasSize.clone(),
          color: const Color(0xFFFFF4C2),
          strength: 0.45,
        ),
      );
      Sfx.fanfare();
    }
    onLetter?.call(l);
  }

  /// A~F를 다 모으면 받는 점수.
  static const letterBonusScore = 5000;

  /// 폭탄 고양이가 부딪힌 곳에서 펑.
  void explode(Vector2 at) {
    const smashR = 2.6, pushR = 5.5;
    for (final c in world.children.whereType<BodyComponent>().toList()) {
      if (!c.isMounted || c is SlingCat) continue;
      final d = c.body.position - at;
      final dist = d.length;
      if (c is SlingBlock && dist < smashR) {
        c.smash();
      } else if (c is SlingMouse && dist < smashR + 0.3) {
        c.smash();
      } else if ((c is SlingBlock || c is SlingMouse) && dist < pushR) {
        final k = 1 - dist / pushR;
        final dir = dist < 0.01 ? Vector2(0, -1) : d / dist;
        c.body.applyLinearImpulse(
          (dir + Vector2(0, -0.4)) * (18 * k * c.body.mass),
        );
      }
    }
    _burst(
      at,
      2.2,
      [AppColors.danger, AppColors.star, Colors.white],
      [FxIcon.bang, FxIcon.star, FxIcon.sparkle],
      count: 24,
      ring: AppColors.star,
      life: 0.9,
    );
    shout(
      '펑!!',
      at,
      size: 50,
      color: AppColors.danger,
      stroke: Colors.white,
      wobble: true,
      dy: -40,
    );
    camera.viewport.add(
      FxFlash(
        canvasSize.clone(),
        color: const Color(0xFFFFE0B0),
        strength: 0.5,
      ),
    );
    shake(0.55);
    Sfx.boom();
  }

  static final _rainbow = [
    for (var h = 0; h < 360; h += 60)
      HSVColor.fromAHSV(1, h.toDouble(), 0.65, 1).toColor(),
  ];

  /// 무적 고양이가 남기는 무지개 꼬리.
  void superTrail(SlingCat cat) => world.add(
    FxBurst(
      at: cat.body.position.clone(),
      radius: cat.radius * 0.6,
      colors: _rainbow,
      icons: const [FxIcon.star, FxIcon.sparkle],
      count: 3,
      life: 0.45,
      random: _rng,
    ),
  );

  void blockBroken(SlingBlock b) {
    if (_over) return;
    final pts = switch (b.spec.kind) {
      BlockKind.cardboard => 50,
      BlockKind.wood => 100,
      BlockKind.brick => 200,
    };
    score.value += pts;
    _brokeThisShot++;
    Sfx.crack();
    _burst(
      b.body.position,
      max(b.spec.halfW, b.spec.halfH),
      [b.color, b.darkColor, Colors.white],
      [FxIcon.sparkle, FxIcon.star],
      count: 7,
    );
  }

  void mouseCaught(SlingMouse m) {
    if (_over) return;
    final pts = m.spec.boss ? bossScore : miceScore;
    score.value += pts;
    miceLeft.value--;
    Sfx.squeak();
    Sfx.meow();
    _burst(
      m.body.position,
      m.radius,
      [AppColors.star, AppColors.mouseEar, Colors.white],
      [FxIcon.star, FxIcon.paw, FxIcon.fish],
      count: 12,
      ring: AppColors.star,
    );
    shout(
      m.spec.boss ? '대장 쥐 잡았다!!' : '잡았다!',
      m.body.position,
      size: m.spec.boss ? 34 : 28,
      color: const Color(0xFFFF5C8A),
      wobble: m.spec.boss,
    );
    shout(
      '+$pts',
      m.body.position,
      size: 20,
      color: Colors.white,
      stroke: const Color(0xFFFF8A3D),
      dy: 34,
      delay: 0.05,
    );
    shake(m.spec.boss ? 0.25 : 0.12);
    if (miceLeft.value == 0 && _winT < 0) _winT = 0;
  }

  void powerFx(SlingCat cat) {
    shout(
      '${cat.shot.power.label}!',
      cat.body.position,
      size: 28,
      color: const Color(0xFF3BA7FF),
      dy: -30,
    );
    _burst(
      cat.body.position,
      cat.radius,
      [Colors.white, const Color(0xFFBFE3FF)],
      [FxIcon.sparkle],
      count: 8,
      ring: Colors.white,
      life: 0.5,
    );
    switch (cat.shot.power) {
      case SlingPower.split:
        Sfx.fluff();
      case SlingPower.dash:
        Sfx.cucumber();
      case SlingPower.slam:
        Sfx.boom();
    }
  }

  void slamLanded(SlingCat cat) {
    shake(0.3);
    _burst(
      cat.body.position,
      cat.radius * 1.4,
      [AppColors.soil, Colors.white],
      [FxIcon.bang, FxIcon.star],
      count: 10,
      ring: Colors.white,
    );
  }

  // ---------------------------------------------------------------- 연출

  void shout(
    String text,
    Vector2 worldPos, {
    double size = 30,
    Color color = const Color(0xFFFF8A3D),
    Color stroke = Colors.white,
    bool wobble = false,
    double dy = 0,
    double delay = 0,
  }) {
    final at = worldToScreen(worldPos)..y += dy;
    at.x = at.x.clamp(size * 2, max(size * 2, canvasSize.x - size * 2));
    // 위쪽 메뉴에 가리지 않게
    at.y = max(at.y, 64 + size / 2);
    camera.viewport.add(
      FxText(
        text,
        at,
        size: size,
        color: color,
        stroke: stroke,
        wobble: wobble,
        delay: delay,
      ),
    );
  }

  void _burst(
    Vector2 at,
    double radius,
    List<Color> colors,
    List<FxIcon> icons, {
    int count = 10,
    Color? ring,
    double life = 0.7,
  }) => world.add(
    FxBurst(
      at: at.clone(),
      radius: radius,
      colors: colors,
      icons: icons,
      count: count,
      ringColor: ring,
      life: life,
      random: _rng,
    ),
  );

  void shake(double amp) {
    _shakeT = max(_shakeT, 0.2);
    _shakeAmp = max(_shakeAmp, amp);
  }

  double _shakeAmp = 0;

  // ---------------------------------------------------------------- 루프

  @override
  void update(double dt) {
    // 화면 회전·로딩으로 한 프레임이 길어지면 물리가 크게 튀어 탑이 저절로 무너진다.
    dt = min(dt, 1 / 30);
    super.update(dt);
    _clock += dt;
    if (_introOn && !_cam.moving) _introOn = false;
    _updateCameraTarget();
    _cam.update(dt);
    _updateShake(dt);
    if (_over) return;
    _time += dt;
    if ((_birdIn -= dt) <= 0) {
      _birdIn = 2.5 + _rng.nextDouble() * 3;
      _spawnBird();
    }

    if (_winT >= 0) {
      // 쥐를 다 잡아도 무너지는 걸 잠깐 보여준 뒤 끝낸다.
      if ((_winT += dt) > 1.4) _end(cleared: true);
      return;
    }
    if (_flyT >= 0) {
      _flyT += dt;
      if (_impactT >= 0) {
        _impactT += dt;
        _quietT = _tumbling.isEmpty ? _quietT + dt : 0;
      }
      if (shots.value.isNotEmpty) {
        if (_shotDone) _reload();
      } else if (_flyT > 1.2 && (_settled || _flyT > 6)) {
        // 마지막 고양이는 떨어지는 쥐가 있을 수 있어 조금 더 지켜본다.
        _end(cleared: false);
      }
    }
  }

  bool get _settled => world.children
      .whereType<BodyComponent>()
      .where((c) => c.isMounted)
      .every((c) {
        final b = c.body;
        return b.bodyType != BodyType.dynamic ||
            (b.linearVelocity.length2 < 0.05 && b.angularVelocity.abs() < 0.3);
      });

  /// 다음 고양이를 새총에 올린다. 쏜 고양이는 그대로 두고 계속 굴러가게.
  void _reload() {
    _flyT = -1;
    _maybeSpawnPickup(start: false);
    // 쏜 고양이는 다음 차례가 오고 2.5초 뒤 퐁 하고 사라진다.
    for (final c in _flying.where((c) => c.isMounted)) {
      c.vanishIn(spentLinger);
    }
    _flying.clear();
    _cam.focusSling();
    if (_brokeThisShot >= 6) {
      shout(
        '와르르!!',
        Vector2(camera.viewfinder.position.x, -6),
        size: 40,
        color: AppColors.star,
        wobble: true,
      );
    }
  }

  void catVanished(SlingCat c) => _burst(
    c.body.position,
    c.radius,
    [Colors.white, const Color(0xFFF1E6D6)],
    [FxIcon.paw],
    count: 6,
    life: 0.5,
  );

  void _end({required bool cleared}) {
    _over = true;
    final left = shots.value.length;
    var stars = 0;
    if (cleared) {
      stars = _level!.starsFor(left);
      if (left > 0) {
        score.value += left * shotBonus;
        shout(
          '남은 고양이 +${left * shotBonus}',
          Vector2(camera.viewfinder.position.x, -8),
          size: 26,
          color: AppColors.star,
        );
      }
      Sfx.fanfare();
    } else {
      Sfx.gameOver();
    }
    onEnd(SlingResult(cleared: cleared, score: score.value, stars: stars));
  }

  /// 쏜 고양이가 처음 무언가에 부딪혔다.
  void catImpact() {
    if (_impactT < 0 && _flyT >= 0) _impactT = 0;
  }

  /// 무너지는 중인 것들: 움직이는 블록, 굴러가거나 떨어지는 쥐.
  /// 쥐는 느리게 굴러도 곧 떨어질 수 있어 더 민감하게 본다.
  Iterable<BodyComponent> get _tumbling =>
      world.children.whereType<BodyComponent>().where((c) {
        if (!c.isMounted) return false;
        final v2 = c.body.linearVelocity.length2;
        if (c is SlingMouse) return v2 > 0.6 * 0.6;
        return c is SlingBlock && v2 > 1.5 * 1.5;
      });

  /// 이번 발사 구경이 끝났나: 부딪히고 소란이 가라앉았거나, 너무 오래 걸리거나,
  /// 고양이가 맵 밖으로 사라졌을 때.
  bool get _shotDone {
    if (_flyT < reloadDelay) return false;
    final alive = _flying.any((c) => c.isMounted);
    if (!alive) return _flyT > reloadDelay;
    if (_impactT < 0) return _flyT > 6;
    if (_impactT < _watchMin) return false;
    return _quietT >= _afterQuiet || _impactT > _watchMax;
  }

  /// 카메라가 볼 곳: 부딪히기 전엔 고양이 앞쪽, 부딪힌 뒤엔 무너지는 곳.
  void _updateCameraTarget() {
    if (_flyT < 0) return;
    final cats = _flying.where((c) => c.isMounted).toList();
    if (_impactT < 0 && cats.isNotEmpty) {
      final lead = cats.reduce(
        (a, b) => a.body.position.x > b.body.position.x ? a : b,
      );
      // 가는 방향을 조금 앞서 본다
      _cam.track(
        lead.body.position.x + lead.body.linearVelocity.x * 0.2,
        w: _cam.flightW,
        smooth: 0.5,
      );
      return;
    }
    final moving = _tumbling.toList();
    if (moving.isNotEmpty) {
      final cx =
          moving.map((c) => c.body.position.x).reduce((a, b) => a + b) /
          moving.length;
      _watchX = _watchX == null ? cx : _watchX! + (cx - _watchX!) * 0.05;
    } else if (cats.isNotEmpty) {
      _watchX ??= cats.first.body.position.x;
    }
    if (_watchX != null) _cam.track(_watchX!, w: _cam.flightW, smooth: 0.7);
  }

  void _updateShake(double dt) {
    if (_shakeT <= 0) {
      _cam.apply(Vector2.zero());
      return;
    }
    _shakeT -= dt;
    _cam.apply(
      Vector2(_rng.nextDouble() - 0.5, _rng.nextDouble() - 0.5) * _shakeAmp,
    );
    if (_shakeT <= 0) _shakeAmp = 0;
  }
}

/// 부딪힌 충격(impulse)의 최댓값.
double _maxImpulse(ContactImpulse imp) {
  var m = 0.0;
  for (var i = 0; i < imp.count; i++) {
    m = max(m, imp.normalImpulses[i]);
  }
  return m;
}

// ================================================================ 고양이

class SlingCat extends BodyComponent<CatSlingGame> with ContactCallbacks {
  SlingCat(this.shot, {required Vector2 start, required Vector2 velocity})
    : _start = start.clone(),
      _velocity = velocity.clone(),
      super(renderBody: false, priority: 2);

  final SlingShot shot;
  final Vector2 _start;
  final Vector2 _velocity;

  double get radius => shot.radius * _scale;
  bool _hit = false;

  /// 버섯을 먹으면 커진다.
  double _scale = 1;
  double _growTo = 1;

  /// 폭탄을 품었다: 다음에 부딪히면 펑.
  bool _bomb = false;
  bool _boomNow = false;
  double _superT = 0;
  double _trailIn = 0;

  /// 별을 먹은 무적 상태.
  bool get isSuper => _superT > 0;

  /// 사라지기까지 남은 시간 (음수 = 예정 없음).
  double _vanishT = -1;
  static const _fade = 0.4;

  void vanishIn(double seconds) => _vanishT = seconds;
  bool _powered = false;
  bool _slamming = false;
  double _age = 0;
  double _faceT = 0;
  CatFace? _face = CatFace.happy;

  /// 아무 데도 안 부딪혔고 기술을 아직 안 썼을 때만.
  bool get canPower => !_hit && !_powered && _age > 0.08;

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: _start,
        linearVelocity: _velocity,
        angularDamping: 0.8,
        bullet: true,
        userData: this,
      ),
    );
    body.createFixture(
      FixtureDef(
        CircleShape()..radius = radius,
        density: 1.6,
        friction: 0.5,
        restitution: 0.2,
      ),
    );
    return body;
  }

  void usePower() {
    _powered = true;
    final v = body.linearVelocity;
    switch (shot.power) {
      case SlingPower.split:
        for (final a in [-0.2, 0.2]) {
          final dir = Vector2(v.x, v.y)..rotate(a);
          game.addClone(
            SlingCat(shot, start: body.position, velocity: dir)
              .._powered = true,
          );
        }
      case SlingPower.dash:
        final speed = max(v.length * 1.8, 24.0);
        body.linearVelocity = v.normalized() * speed;
      case SlingPower.slam:
        _slamming = true;
        body.linearVelocity = Vector2(v.x * 0.15, 30);
    }
    _react(CatFace.proud, 0.8);
    game.powerFx(this);
  }

  void _react(CatFace f, double t) {
    _face = f;
    _faceT = t;
  }

  void react(CatFace f, double t) => _react(f, t);

  /// 분신으로 태어난 고양이: 냥펀치는 못 쓴다.
  void markClone() => _powered = true;

  void armBomb() {
    _bomb = true;
    _react(CatFace.surprised, 0.6);
  }

  bool get hasBomb => _bomb;

  /// 거대해진다. 물리 몸체는 다음 프레임에 바꾼다 (충돌 처리 중엔 못 바꾼다).
  void grow() {
    _growTo = 1.9;
    _react(CatFace.proud, 1.5);
  }

  /// 새에 맞으면 냥펀치를 한 번 더 쓸 수 있다.
  void recharge() {
    _hit = false;
    _powered = false;
    _react(CatFace.love, 0.8);
  }

  static const _superSpeed = 15.0;

  /// 무적: 중력이 약해지고 속도를 유지하며 닿는 블록·쥐를 모두 부순다.
  void goSuper({Vector2? toward, double seconds = 3.2}) {
    _superT = seconds;
    body.gravityScale = Vector2(1, 0.3);
    final v = body.linearVelocity;
    final dir = toward != null
        ? (toward - body.position)
        : (v.length2 < 0.01 ? Vector2(1, 0) : v.clone());
    body.linearVelocity = dir.normalized() * max(v.length, _superSpeed);
    _react(CatFace.proud, seconds);
  }

  @override
  void preSolve(Object other, Contact contact, Manifold oldManifold) {
    if (!isSuper) return;
    if (other is SlingBlock) {
      contact.isEnabled = false;
      other.smash();
    } else if (other is SlingMouse) {
      contact.isEnabled = false;
      other.smash();
    }
  }

  @override
  void beginContact(Object other, Contact contact) {
    // 새·해·선물은 센서라 부딪힌 걸로 치지 않는다
    if (other is SlingBird || other is SlingSkyBody || other is SlingPickup) {
      return;
    }
    game.catImpact();
    if (_bomb) {
      _bomb = false;
      _boomNow = true;
    }
    if (!_hit) {
      _hit = true;
      _react(CatFace.surprised, 0.9);
      Sfx.thud();
      if (_slamming) {
        _slamming = false;
        game.slamLanded(this);
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_faceT > 0 && (_faceT -= dt) <= 0) _face = null;
    if (_boomNow) {
      _boomNow = false;
      game.explode(body.position.clone());
    }
    if (_growTo != _scale) {
      _scale = _growTo;
      for (final f in body.fixtures.toList()) {
        body.destroyFixture(f);
      }
      body.createFixture(
        FixtureDef(
          CircleShape()..radius = radius,
          density: 1.6,
          friction: 0.5,
          restitution: 0.2,
        ),
      );
    }
    if (_superT > 0) {
      _superT -= dt;
      final v = body.linearVelocity;
      if (v.length < _superSpeed * 0.8 && v.length2 > 0.01) {
        body.linearVelocity = v.normalized() * (_superSpeed * 0.8);
      }
      if ((_trailIn -= dt) <= 0) {
        _trailIn = 0.07;
        game.superTrail(this);
      }
      if (_superT <= 0) body.gravityScale = null;
    }
    if (_vanishT >= 0 && (_vanishT -= dt) < 0) {
      game.catVanished(this);
      removeFromParent();
      return;
    }
    final p = body.position;
    // 화면 밖으로 나가면 정리
    if (p.x > _SlingCamera.mapRight + 4 ||
        p.x < _SlingCamera.mapLeft - 4 ||
        p.y > 4) {
      removeFromParent();
    }
  }

  final _aura = Paint();

  @override
  void render(Canvas canvas) {
    if (_bomb) {
      // 폭탄을 품은 고양이: 붉게 깜빡이는 테두리
      final k = 0.5 + 0.5 * sin(game.clock * 18);
      _aura
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.14
        ..color = AppColors.danger.withValues(alpha: 0.4 + 0.5 * k);
      canvas.drawCircle(Offset.zero, radius * 1.25, _aura);
    }
    if (isSuper) {
      // 무지개빛으로 번쩍번쩍
      final hue = (game.clock * 720) % 360;
      final c = HSVColor.fromAHSV(1, hue, 0.6, 1).toColor();
      _aura
        ..style = PaintingStyle.fill
        ..color = c.withValues(alpha: 0.35);
      canvas.drawCircle(Offset.zero, radius * 1.45, _aura);
      _aura
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.12
        ..color = c;
      canvas.drawCircle(Offset.zero, radius * 1.2, _aura);
    }
    canvas.save();
    // 굴러도 얼굴은 대체로 똑바로
    canvas.rotate(-body.angle + 0.25 * sin(body.angle));
    paintCat(
      canvas,
      shot.tier,
      shot.coat,
      radius,
      face: _vanishT >= 0 && _vanishT < 1.2 ? CatFace.sleepy : _face,
      opacity: _vanishT >= 0 && _vanishT < _fade ? _vanishT / _fade : 1,
    );
    canvas.restore();
  }
}

// ================================================================ 블록

class SlingBlock extends BodyComponent<CatSlingGame> with ContactCallbacks {
  SlingBlock(this.spec) : super(renderBody: false);

  final BlockSpec spec;

  /// 부딪힘 충격 단위. 이만큼 쌓이면 부서진다.
  late double _hp = spec.kind.hp * 10;
  late final double _maxHp = _hp;
  bool _broken = false;
  double _hitFlash = 0;
  double _load = 0;

  Color get color => switch (spec.kind) {
    BlockKind.cardboard => AppColors.cardboard,
    BlockKind.wood => AppColors.wood,
    BlockKind.brick => AppColors.brick,
  };
  Color get darkColor => switch (spec.kind) {
    BlockKind.cardboard => AppColors.cardboardDark,
    BlockKind.wood => AppColors.woodDark,
    BlockKind.brick => AppColors.brickDark,
  };

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: Vector2(spec.x, spec.y),
        userData: this,
      ),
    );
    body.createFixture(
      FixtureDef(
        PolygonShape()..setAsBoxXY(spec.halfW, spec.halfH),
        density: spec.kind.density,
        friction: 0.7,
        restitution: 0.05,
      ),
    );
    return body;
  }

  /// 무적 고양이에게 닿으면 바로 부서진다.
  void smash() {
    if (_broken) return;
    _broken = true;
    game.blockBroken(this);
    game.shake(0.1);
    removeFromParent();
  }

  @override
  void postSolve(Object other, Contact contact, ContactImpulse impulse) {
    if (_broken) return;
    // 가만히 쌓여 있어도 매 스텝 위에 얹힌 무게만큼 충격이 들어온다.
    // 평소 받던 하중(이동 평균)보다 훌쩍 큰 충격만 피해로 친다.
    final imp = _maxImpulse(impulse);
    final base = _load;
    _load += (imp - _load) * 0.1;
    if (!game._damageOn) return;
    final dmg = imp - (2.0 + body.mass + base * 1.5);
    if (dmg <= 0) return;
    _hp -= dmg;
    _hitFlash = 0.12;
    if (_hp <= 0) {
      _broken = true;
      game.blockBroken(this);
      removeFromParent();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hitFlash > 0) _hitFlash -= dt;
    if (!_broken && body.position.y > 6) {
      _broken = true;
      removeFromParent();
    }
  }

  final _fill = Paint();
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void render(Canvas canvas) {
    final w = spec.halfW, h = spec.halfH;
    final rect = Rect.fromLTRB(-w, -h, w, h);
    _fill.color = _hitFlash > 0
        ? Color.lerp(color, Colors.white, 0.45)!
        : color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(0.06)),
      _fill,
    );
    _line
      ..color = darkColor
      ..strokeWidth = 0.07;
    switch (spec.kind) {
      case BlockKind.cardboard:
        // 테이프 한 줄
        _fill.color = const Color(0xFFE9C58F);
        final tw = min(w, h) * 0.28;
        canvas.drawRect(
          w >= h
              ? Rect.fromLTRB(-w, -tw, w, tw)
              : Rect.fromLTRB(-tw, -h, tw, h),
          _fill,
        );
      case BlockKind.wood:
        // 나뭇결
        for (final k in [-0.4, 0.35]) {
          if (w >= h) {
            canvas.drawLine(
              Offset(-w * 0.8, h * k),
              Offset(w * 0.6, h * k),
              _line,
            );
          } else {
            canvas.drawLine(
              Offset(w * k, -h * 0.8),
              Offset(w * k, h * 0.6),
              _line,
            );
          }
        }
      case BlockKind.brick:
        // 벽돌 줄눈
        _line.strokeWidth = 0.05;
        final rows = max(1, (h * 2 / 0.4).round());
        for (var i = 1; i < rows; i++) {
          final y = -h + i * h * 2 / rows;
          canvas.drawLine(Offset(-w, y), Offset(w, y), _line);
        }
    }
    // 금이 간다
    final worn = 1 - _hp / _maxHp;
    if (worn > 0.3) {
      _line
        ..color = darkColor
        ..strokeWidth = 0.06;
      canvas.drawPath(
        Path()
          ..moveTo(-w * 0.1, -h)
          ..lineTo(w * 0.15, -h * 0.3)
          ..lineTo(-w * 0.2, h * 0.2)
          ..lineTo(w * 0.05, h * (worn > 0.6 ? 1 : 0.5)),
        _line,
      );
    }
    _line
      ..color = darkColor
      ..strokeWidth = 0.08;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(0.06)),
      _line,
    );
  }
}

// ================================================================ 쥐

class SlingMouse extends BodyComponent<CatSlingGame> with ContactCallbacks {
  SlingMouse(this.spec) : super(renderBody: false, priority: 1);

  final MouseSpec spec;
  double get radius =>
      spec.boss ? SlingLevels.bossRadius : SlingLevels.mouseRadius;
  late double _hp = spec.boss ? 14 : 5;
  bool _caught = false;
  double _hurt = 0;
  double _blinkIn = 1 + Random().nextDouble() * 3;
  double _blinkT = 0;

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: Vector2(spec.x, spec.y),
        angularDamping: 2,
        userData: this,
      ),
    );
    body.createFixture(
      FixtureDef(
        CircleShape()..radius = radius,
        density: 0.6,
        friction: 0.6,
        restitution: 0.1,
      ),
    );
    return body;
  }

  @override
  void postSolve(Object other, Contact contact, ContactImpulse impulse) {
    if (_caught || !game._damageOn) return;
    // 고양이 발에 직접 닿으면 더 아프다
    final k = other is SlingCat ? 2.0 : 1.0;
    final dmg = (_maxImpulse(impulse) - 0.8) * k;
    if (dmg <= 0) return;
    _hp -= dmg;
    _hurt = 0.6;
    if (_hp <= 0) _catch();
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (_caught || !game._damageOn) return;
    // 쥐는 모두 사물 위에서 시작한다. 땅에 떨어지면 잡힌다.
    // 고양이 발에 닿으면 살짝이어도 잡힌다.
    if (other is _Ground || other is SlingCat) _catch();
  }

  void smash() {
    if (!_caught) _catch();
  }

  void _catch() {
    _caught = true;
    game.mouseCaught(this);
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hurt > 0) _hurt -= dt;
    if (_blinkT > 0) _blinkT -= dt;
    if ((_blinkIn -= dt) <= 0) {
      _blinkT = 0.14;
      _blinkIn = 2 + Random().nextDouble() * 3;
    }
    final p = body.position;
    if (!_caught &&
        (p.y > 3 ||
            p.x < _SlingCamera.mapLeft - 4 ||
            p.x > _SlingCamera.mapRight + 4)) {
      _catch();
    }
  }

  final _p = Paint();
  final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void render(Canvas canvas) {
    final r = radius;
    canvas.save();
    canvas.rotate(-body.angle * 0.8);
    // 꼬리
    _stroke
      ..color = AppColors.mouseEar
      ..strokeWidth = r * 0.12;
    canvas.drawPath(
      Path()
        ..moveTo(r * 0.8, r * 0.4)
        ..quadraticBezierTo(r * 1.6, r * 0.2, r * 1.4, -r * 0.5),
      _stroke,
    );
    // 귀
    for (final s in [-1.0, 1.0]) {
      _p.color = AppColors.mouse;
      canvas.drawCircle(Offset(s * r * 0.62, -r * 0.7), r * 0.46, _p);
      _p.color = AppColors.mouseEar;
      canvas.drawCircle(Offset(s * r * 0.62, -r * 0.7), r * 0.28, _p);
    }
    _p.color = AppColors.mouse;
    canvas.drawCircle(Offset.zero, r, _p);
    _p.color = const Color(0xFFD8DADF);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, r * 0.35),
        width: r * 1.1,
        height: r * 0.8,
      ),
      _p,
    );
    // 눈
    _p.color = AppColors.ink;
    _stroke
      ..color = AppColors.ink
      ..strokeWidth = r * 0.1;
    for (final s in [-1.0, 1.0]) {
      final eye = Offset(s * r * 0.34, -r * 0.12);
      if (_hurt > 0) {
        // 질끈 감은 눈 ><
        canvas.drawLine(eye + Offset(-s * r * 0.12, -r * 0.1), eye, _stroke);
        canvas.drawLine(eye + Offset(-s * r * 0.12, r * 0.1), eye, _stroke);
      } else if (_blinkT > 0) {
        canvas.drawLine(
          eye - Offset(r * 0.1, 0),
          eye + Offset(r * 0.1, 0),
          _stroke,
        );
      } else {
        canvas.drawCircle(eye, r * 0.11, _p);
      }
    }
    // 코와 수염
    _p.color = AppColors.mouseEar;
    canvas.drawCircle(Offset(0, r * 0.18), r * 0.12, _p);
    _stroke
      ..color = AppColors.muted
      ..strokeWidth = r * 0.05;
    for (final s in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(s * r * 0.2, r * 0.22),
        Offset(s * r * 0.9, r * 0.1),
        _stroke,
      );
      canvas.drawLine(
        Offset(s * r * 0.2, r * 0.3),
        Offset(s * r * 0.9, r * 0.4),
        _stroke,
      );
    }
    // 대장 쥐 왕관
    if (spec.boss) {
      _p.color = AppColors.star;
      canvas.drawPath(
        Path()
          ..moveTo(-r * 0.45, -r * 0.85)
          ..lineTo(-r * 0.5, -r * 1.35)
          ..lineTo(-r * 0.2, -r * 1.1)
          ..lineTo(0, -r * 1.45)
          ..lineTo(r * 0.2, -r * 1.1)
          ..lineTo(r * 0.5, -r * 1.35)
          ..lineTo(r * 0.45, -r * 0.85)
          ..close(),
        _p,
      );
    }
    canvas.restore();
  }
}

// ================================================================ 배경/땅/새총

class _Ground extends BodyComponent<CatSlingGame> {
  _Ground() : super(renderBody: false, priority: -1);
  final _p = Paint();
  static const _flowers = [
    Color(0xFFFF9EB5),
    Color(0xFFFFFFFF),
    Color(0xFFFFD35C),
  ];

  @override
  Body createBody() {
    final body = world.createBody(BodyDef(userData: this));
    body.createFixture(
      FixtureDef(
        EdgeShape()..set(Vector2(-40, 0), Vector2(40, 0)),
        friction: 0.8,
      ),
    );
    return body;
  }

  @override
  void render(Canvas canvas) {
    final pal = game.palette;
    _p.color = pal.soil;
    canvas.drawRect(const Rect.fromLTRB(-40, 0.3, 40, 20), _p);
    _p.color = pal.grass;
    canvas.drawRect(const Rect.fromLTRB(-40, 0, 40, 0.45), _p);
    // 새총 쪽 풀밭에 꽃
    for (var i = 0; i < 9; i++) {
      final x = -9.2 + i * 0.95 + (i.isEven ? 0.2 : 0);
      if ((x - CatSlingGame.slingX).abs() < 0.5) continue;
      _p.color = pal.leafDark;
      canvas.drawRect(Rect.fromLTRB(x - 0.02, 0.05, x + 0.02, 0.3), _p);
      _p.color = _flowers[i % _flowers.length];
      canvas.drawCircle(Offset(x, 0.05), 0.11, _p);
      _p.color = const Color(0xFFFFE8A3);
      canvas.drawCircle(Offset(x, 0.05), 0.045, _p);
    }
  }
}

/// 새총, 올려둔 고양이, 조준 점선.
class _Sling extends Component with HasGameReference<CatSlingGame> {
  _Sling() : super(priority: 3);

  final _wood = Paint()
    ..color = AppColors.slingWood
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 0.32;
  final _band = Paint()
    ..color = AppColors.rubber
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 0.14;
  final _dot = Paint()..color = Colors.white;

  static const _x = CatSlingGame.slingX, _y = CatSlingGame.slingY;
  static const _leftFork = Offset(_x - 0.45, _y - 0.3);
  static const _rightFork = Offset(_x + 0.45, _y - 0.3);

  @override
  void render(Canvas canvas) {
    // 뒤쪽 가지와 고무줄
    final shot = game.onSling;
    final pos = (CatSlingGame.slingPos + game.pull).toOffset();
    if (shot != null) canvas.drawLine(_rightFork, pos, _band);
    canvas.drawLine(const Offset(_x, 0), const Offset(_x, _y + 0.6), _wood);
    canvas.drawLine(const Offset(_x, _y + 0.6), _rightFork, _wood);

    // 앞쪽 가지는 고양이 뒤에 (얼굴을 가리지 않게). 고무줄만 앞으로.
    canvas.drawLine(const Offset(_x, _y + 0.6), _leftFork, _wood);
    if (shot != null) {
      _trajectory(canvas, shot);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      paintCat(
        canvas,
        shot.tier,
        shot.coat,
        shot.radius,
        face: game.pull.length > 1.2 ? CatFace.surprised : null,
      );
      canvas.restore();
      canvas.drawLine(_leftFork, pos + Offset(-shot.radius * 0.7, 0), _band);
    }
  }

  /// 처음 일부만 보여준다 (끝까지 보여주면 너무 쉽다).
  void _trajectory(Canvas canvas, SlingShot shot) {
    if (game.pull.length < 0.5) return;
    final p0 = CatSlingGame.slingPos + game.pull;
    final v = game.launchVelocity;
    final g = game.world.gravity;
    for (var i = 1; i <= 9; i++) {
      final t = i * 0.06;
      final p = p0 + v * t + g * (0.5 * t * t);
      _dot.color = Colors.white.withValues(alpha: 1 - i / 11);
      canvas.drawCircle(p.toOffset(), 0.14 - i * 0.008, _dot);
    }
  }
}
