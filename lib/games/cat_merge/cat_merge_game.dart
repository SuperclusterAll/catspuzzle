import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors;

import '../../core/items.dart';
import '../../theme/app_tokens.dart';
import 'cat_art.dart';
import 'cat_tiers.dart';
import 'merge_fx.dart';
import 'merge_items.dart';
import 'merge_sfx.dart';

class RunResult {
  const RunResult(
      {required this.score, required this.bestTier, required this.gaveUp});
  final int score;

  /// 합체로 만든 가장 높은 단계 (-1 = 없음).
  final int bestTier;

  /// 넘쳐서가 아니라 직접 그만둔 판.
  final bool gaveUp;
}

/// 수박게임 방식 무한 모드: 상자에 고양이를 떨어뜨려 같은 품종끼리 합체시킨다.
///
/// 끝나는 조건: 고양이가 빨간 선 위에 [overLimit]초 동안 머물면 끝.
/// 그 사이 화면에 카운트다운([countdown])이 뜬다. [giveUp]으로 직접 끝낼 수도 있다.
class CatMergeGame extends Forge2DGame with TapCallbacks, DragCallbacks {
  CatMergeGame({
    required this.onEnd,
    this.onSpawn,
    this.withPartner = false,
    Random? random,
  })  : _rng = random ?? Random(),
        super(gravity: Vector2(0, 28));

  static const id = 'cat_merge';

  // 월드 좌표(m). 상자 바닥 중앙이 원점, 위쪽이 음수.
  static const halfWidth = 5.0;
  static const boxHeight = 13.0;
  static const dangerY = -11.4;
  static const dropY = -14.0;

  /// 빨간 선 위에 이만큼 머물면 게임 끝.
  static const overLimit = 3.0;

  static const _dropCooldown = 0.45;

  /// 방금 떨어뜨린 고양이는 이 시간 동안 선을 넘어도 봐준다.
  static const _graceAge = 1.0;

  /// 아이템이 "다음"에 나오는 간격 (떨어뜨린 횟수).
  static const _itemEveryMin = 14;
  static const _itemEveryJitter = 7;

  // 페르시안 밀치기
  static const _pushRadius = 4.5;
  static const _pushSpeed = 9.0;

  /// 위로 튀는 속도 상한 (선 밖으로 날아가 억울하게 끝나는 것 방지).
  static const _pushUpCap = 5.0;

  // 츄르: 주변 고양이를 끌어당긴다
  static const churuDuration = 1.6;
  static const churuRadius = 4.5;
  static const _churuPull = 20.0;

  // 오이: 주변 고양이가 놀라 튀어 오른다
  static const _cucumberRadius = 2.4;
  static const _cucumberJump = 11.0;

  /// 출전 고양이와 함께면 희귀 털색이 [partnerRareBoost]배 잘 나온다.
  final bool withPartner;
  final void Function(RunResult result) onEnd;

  /// 고양이가 새로 생길 때마다 (떨어뜨림/합체). 도감 기록용.
  final void Function(int tier, CatCoat coat)? onSpawn;
  final Random _rng;

  final score = ValueNotifier<int>(0);
  late final next = ValueNotifier<DropSpec>(_rollSpec());

  /// 합체로 만든 가장 높은 단계 (-1 = 아직 없음).
  final bestTier = ValueNotifier<int>(-1);

  /// 현재 연쇄 수 (0 = 연쇄 중 아님). HUD 배지용.
  final chain = ValueNotifier<int>(0);

  /// 넘침 카운트다운 3·2·1 (0 = 안전).
  final countdown = ValueNotifier<int>(0);

  final _chain = ChainCounter();
  final _pending = <(CatBall, CatBall)>[];
  final _cameraBase = Vector2(0, -8.3);

  late DropSpec _current;
  int _untilItem = _itemEveryMin;
  double _aimX = 0;
  double _cooldown = 0;
  double _overT = 0;
  double _shakeT = 0;
  double _shakeAmp = 0;
  double _time = 0;
  bool _over = false;

  /// 0~1. 선 넘은 채로 버틴 정도 (선 깜빡임 세기).
  double get danger => (_overT / overLimit).clamp(0, 1);
  double get time => _time;
  DropSpec get current => _current;
  double get aimX => _aimX;
  bool get isOver => _over;
  bool get canDrop => !_over && _cooldown <= 0;

  /// 지금 손에 든 게 아이템이 아니면 인벤토리 아이템으로 바꿀 수 있다.
  bool get canUseItem => canDrop && _current.item == null;

  Iterable<CatBall> get _liveCats => world.children
      .whereType<CatBall>()
      .where((c) => !c.merged && c.isMounted);

  @override
  Color backgroundColor() => AppColors.cream;

  @override
  Future<void> onLoad() async {
    camera.viewfinder
      ..visibleGameSize = Vector2(halfWidth * 2 + 1.6, 19.2)
      ..position = _cameraBase.clone();
    world.addAll([_Box(), _Aim()]);
    _resetRun();
  }

  void _resetRun() {
    _pending.clear();
    _chain.reset();
    score.value = 0;
    bestTier.value = -1;
    chain.value = 0;
    countdown.value = 0;
    _current = DropSpec.cat(_rollTier(), _rollCoat());
    next.value = _rollSpec();
    _aimX = 0;
    _cooldown = 0;
    _overT = 0;
    _over = false;
  }

  void restart() {
    for (final c in <Component>[
      ...world.children.whereType<CatBall>(),
      ...world.children.whereType<ItemBall>(),
      ...world.children.whereType<FxBurst>(),
    ]) {
      c.removeFromParent();
    }
    _resetRun();
  }

  /// 직접 그만두기. 지금까지 점수로 보상을 받는다.
  void giveUp() {
    if (!_over) _end(gaveUp: true);
  }

  int _rollTier() {
    final total = dropWeights.reduce((a, b) => a + b);
    var x = _rng.nextInt(total);
    for (var i = 0; i < dropWeights.length; i++) {
      x -= dropWeights[i];
      if (x < 0) return i;
    }
    return 0;
  }

  CatCoat _rollCoat() {
    double weight(CatCoat c) =>
        c.weight * (withPartner && c.isRare ? partnerRareBoost : 1);
    final total = CatCoat.values.fold(0.0, (s, c) => s + weight(c));
    var x = _rng.nextDouble() * total;
    for (final c in CatCoat.values) {
      x -= weight(c);
      if (x < 0) return c;
    }
    return CatCoat.base;
  }

  DropSpec _rollSpec() {
    if (--_untilItem <= 0) {
      _untilItem = _itemEveryMin + _rng.nextInt(_itemEveryJitter);
      return DropSpec.item(ItemId.values[_rng.nextInt(ItemId.values.length)]);
    }
    return DropSpec.cat(_rollTier(), _rollCoat());
  }

  void _clampAim() {
    final r = _current.radius;
    _aimX = _aimX.clamp(-halfWidth + r, halfWidth - r);
  }

  void _aimAt(Vector2 canvasPos) {
    _aimX = screenToWorld(canvasPos).x;
    _clampAim();
  }

  void _drop() {
    if (!canDrop) return;
    final spec = _current;
    final pos = Vector2(_aimX, dropY);
    final item = spec.item;
    if (item != null) {
      world.add(ItemBall(item: item, start: pos));
    } else {
      world.add(CatBall(tier: spec.tier, coat: spec.coat, start: pos));
      onSpawn?.call(spec.tier, spec.coat);
    }
    Sfx.drop();
    _current = next.value;
    next.value = _rollSpec();
    _cooldown = _dropCooldown;
    _clampAim();
  }

  /// 손에 든 고양이를 인벤토리 아이템으로 바꾼다. 든 고양이는 "다음"으로 밀린다.
  bool useItem(ItemId item) {
    if (!canUseItem) return false;
    next.value = _current;
    _current = DropSpec.item(item);
    _clampAim();
    return true;
  }

  @override
  void onTapDown(TapDownEvent event) => _aimAt(event.canvasPosition);

  @override
  void onTapUp(TapUpEvent event) {
    _aimAt(event.canvasPosition);
    _drop();
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _aimAt(event.canvasPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) => _aimAt(event.canvasEndPosition);

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _drop();
  }

  void queueMerge(CatBall a, CatBall b) => _pending.add((a, b));

  void shake(double amp, {double duration = 0.18}) {
    _shakeAmp = max(_shakeAmp, amp);
    _shakeT = max(_shakeT, duration);
  }

  // ---------------------------------------------------------------- 연출

  /// 외침 글자. [worldPos] 위에 뜬다.
  void shout(
    String text,
    Vector2 worldPos, {
    double size = 30,
    Color color = const Color(0xFFFF8A3D),
    Color stroke = Colors.white,
    double life = 1.0,
    bool wobble = false,
    double dy = 0,
    double delay = 0,
  }) {
    final at = worldToScreen(worldPos)..y += dy;
    // 화면 밖으로 잘리지 않게 좌우를 붙잡는다.
    camera.viewport.add(FxText(text, at,
        size: size,
        color: color,
        stroke: stroke,
        life: life,
        wobble: wobble,
        delay: delay));
  }

  void _burst(Vector2 at, double radius, List<Color> colors, List<FxIcon> icons,
          {int count = 10, Color? ring, double life = 0.7}) =>
      world.add(FxBurst(
          at: at.clone(),
          radius: radius,
          colors: colors,
          icons: icons,
          count: count,
          ringColor: ring,
          life: life,
          random: _rng));

  void _flash({Color color = Colors.white, double strength = 0.45}) =>
      camera.viewport.add(FxFlash(canvasSize.clone(), color: color, strength: strength));

  static const _gold = Color(0xFFFFC53D);
  static const _pink = Color(0xFFFF5C8A);
  static const _orange = Color(0xFFFF8A3D);
  static const _red = Color(0xFFFF4D4D);
  static const _sky = Color(0xFF3BA7FF);
  static const _green = Color(0xFF3FA34D);
  static const _deep = Color(0xFF7A3E00);

  /// 연쇄가 길어질수록 글자·조각·소리·흔들림이 커진다.
  void _mergeFx(int tier, int chainCount, int points, Vector2 at) {
    final r = catTiers[min(tier, lionTier)].radius;
    final big = chainCount >= 4;
    _burst(
      at,
      r,
      [_gold, _pink, Colors.white, if (big) _orange],
      [FxIcon.star, FxIcon.sparkle, FxIcon.paw, if (chainCount >= 2) FxIcon.heart],
      count: 8 + min(chainCount, 5) * 3,
      ring: chainCount >= 2 ? _gold : Colors.white,
    );
    Sfx.merge(tier);
    Sfx.chain(chainCount);

    final (label, color, size) = switch (chainCount) {
      <= 1 => ('냥!', _orange, 26.0),
      2 => ('냥냥!', _pink, 34.0),
      3 => ('냥냥냥!!', _red, 40.0),
      _ => ('냥냥 폭풍!!', _gold, 46.0),
    };
    shout(label, at, size: size, color: color,
        stroke: big ? _deep : Colors.white, wobble: chainCount >= 3);
    shout('+$points', at, size: 20 + min(chainCount, 5) * 2.0,
        color: Colors.white, stroke: _orange, dy: size * 0.9, delay: 0.05);
    if (chainCount >= 3) shake(0.08 * chainCount, duration: 0.22);
    if (big) _flash(color: const Color(0xFFFFF4C2), strength: 0.35);
  }

  // ---------------------------------------------------------------- 루프

  @override
  void update(double dt) {
    super.update(dt);
    if (_over) return;
    _time += dt;
    _cooldown -= dt;
    _chain.tick(dt);
    if (!_chain.active && chain.value != 0) chain.value = 0;
    _resolveMerges();
    _checkOverflow(dt);
    _updateShake(dt);
  }

  void _resolveMerges() {
    for (final (a, b) in _pending) {
      if (a.merged || b.merged || !a.isMounted || !b.isMounted) continue;
      a.merged = b.merged = true;
      final mid = (a.body.position + b.body.position) / 2;
      final vel = (a.body.linearVelocity + b.body.linearVelocity) / 2;
      a.removeFromParent();
      b.removeFromParent();

      final n = _chain.hit();
      chain.value = n;
      final tier = a.tier;
      var points = 0;
      if (tier < lionTier) {
        final t = tier + 1;
        final ball = CatBall(
            tier: t, coat: _rollCoat(), start: mid, velocity: vel, popped: true);
        world.add(ball);
        onSpawn?.call(t, ball.coat);
        if (t > bestTier.value) bestTier.value = t;
        points = mergePoints(t) * _chain.multiplier;
        if (t == fatTier) {
          _push(mid);
        } else if (t == lionTier) {
          points += _roar(mid);
        } else if (t >= 6) {
          shake(0.05 * (t - 5));
        }
        _mergeFx(t, n, points, mid);
      } else {
        points = topMergePoints * _chain.multiplier;
        _ascend(mid, points);
      }
      score.value += points;
    }
    _pending.clear();
  }

  /// 페르시안 탄생: 털이 부풀어 주변 고양이를 밀쳐낸다.
  void _push(Vector2 center) {
    for (final c in _liveCats) {
      final d = c.body.position - center;
      final dist = d.length;
      if (dist < 0.01 || dist > _pushRadius) continue;
      final k = 1 - dist / _pushRadius;
      final dv = d / dist * (_pushSpeed * k);
      dv.y = max(dv.y, -_pushUpCap * k);
      c.body.applyLinearImpulse(dv * c.body.mass);
      c.protect(1.5);
      c.react(CatFace.surprised, 1.0);
    }
    _burst(center, _pushRadius * 0.45, [Colors.white, const Color(0xFFFFF1DC)],
        [FxIcon.sparkle, FxIcon.star], count: 16, ring: Colors.white, life: 0.8);
    shout('복슬복슬!!', center, size: 40, color: _sky, wobble: true, dy: -50);
    shake(0.3);
    Sfx.fluff();
  }

  /// 사자 탄생: 작은 고양이들이 놀라 도망간다 (점수로 환산).
  int _roar(Vector2 at) {
    var pts = 0;
    for (final c in _liveCats.where((c) => c.tier <= roarMaxTier).toList()) {
      c.merged = true;
      _burst(c.body.position, c.radius, [_gold, Colors.white], [FxIcon.star], count: 6);
      c.removeFromParent();
      pts += mergePoints(c.tier);
    }
    _flash(color: const Color(0xFFFFE08A), strength: 0.5);
    shout('어흥!!!', at, size: 54, color: _gold, stroke: _deep, wobble: true, dy: -70, life: 1.3);
    shake(0.45, duration: 0.35);
    Sfx.roar();
    return pts;
  }

  void _ascend(Vector2 at, int points) {
    _flash(color: const Color(0xFFFFF4C2), strength: 0.6);
    _burst(at, 3, [_gold, _pink, Colors.white], [FxIcon.star, FxIcon.sparkle, FxIcon.heart],
        count: 24, ring: _gold, life: 1.0);
    shout('사자 승천!!!', at, size: 48, color: _gold, stroke: _deep, wobble: true, life: 1.4);
    shout('+$points', at, size: 30, color: Colors.white, stroke: _orange, dy: 50, delay: 0.1);
    shake(0.35);
    Sfx.fanfare();
  }

  /// 츄르가 켜진 순간.
  void churuStart(Vector2 at) {
    shout('츄르츄르!!', at, size: 40, color: _pink, wobble: true, dy: -40, life: 1.2);
    _burst(at, 1.2, [_pink, const Color(0xFFFFB3C7), Colors.white],
        [FxIcon.heart, FxIcon.fish], count: 14, ring: _pink, life: 0.9);
    Sfx.churu();
  }

  /// 츄르가 켜져 있는 동안 매 프레임 호출.
  void churuPull(Vector2 center, double dt) {
    for (final c in _liveCats) {
      final d = center - c.body.position;
      final dist = d.length;
      if (dist < 0.01 || dist > churuRadius) continue;
      final k = 1 - dist / churuRadius;
      c.body.applyForce(d / dist * (_churuPull * k * c.body.mass));
      c.protect(0.5);
      c.react(CatFace.love, 0.4);
      // 끌려오는 고양이 머리 위로 하트가 가끔 뿅
      if (_rng.nextDouble() < dt * 2.5) {
        _burst(c.body.position - Vector2(0, c.radius), c.radius * 0.6,
            [_pink], [FxIcon.heart], count: 3, life: 0.6);
      }
    }
  }

  void cucumberScare(Vector2 center) {
    var n = 0;
    for (final c in _liveCats) {
      final dist = c.body.position.distanceTo(center);
      if (dist > _cucumberRadius + c.radius) continue;
      final k = 1 - (dist / (_cucumberRadius + c.radius)).clamp(0.0, 1.0);
      final target = Vector2(
          (_rng.nextDouble() - 0.5) * 6, -_cucumberJump * (0.6 + 0.4 * k));
      c.body.applyLinearImpulse((target - c.body.linearVelocity) * c.body.mass);
      c.protect(1.8);
      c.react(CatFace.surprised, 1.3);
      _burst(c.body.position - Vector2(0, c.radius * 1.2), c.radius * 0.5,
          [_red], [FxIcon.bang], count: 1, life: 0.8);
      n++;
    }
    if (n > 0) {
      shout('화들짝!!', center, size: 40, color: _green, wobble: true, dy: -40);
      _burst(center, 1.4, [_green, Colors.white], [FxIcon.bang, FxIcon.star],
          count: 10, ring: _green);
      shake(0.2);
      Sfx.cucumber();
    } else {
      shout('오이...?', center, size: 24, color: _green);
    }
  }

  // ---------------------------------------------------------------- 끝

  void _checkOverflow(double dt) {
    final spilling = _liveCats.any((c) =>
        c.age > _graceAge &&
        !c.isProtected &&
        c.body.position.y - c.radius < dangerY);
    _overT = spilling ? _overT + dt : max(0, _overT - dt * 2);
    final cd = _overT > 0.15 ? (overLimit - _overT).ceil().clamp(1, 3) : 0;
    if (cd != countdown.value) {
      if (cd > 0) Sfx.tick();
      countdown.value = cd;
    }
    if (_overT >= overLimit) _end(gaveUp: false);
  }

  void _end({required bool gaveUp}) {
    _over = true;
    countdown.value = 0;
    chain.value = 0;
    camera.viewfinder.position = _cameraBase;
    Sfx.gameOver();
    onEnd(RunResult(score: score.value, bestTier: bestTier.value, gaveUp: gaveUp));
  }

  void _updateShake(double dt) {
    if (_shakeT <= 0) {
      camera.viewfinder.position = _cameraBase;
      return;
    }
    _shakeT -= dt;
    camera.viewfinder.position = _cameraBase +
        Vector2(_rng.nextDouble() - 0.5, _rng.nextDouble() - 0.5) * _shakeAmp;
    if (_shakeT <= 0) _shakeAmp = 0;
  }
}

class CatBall extends BodyComponent<CatMergeGame> with ContactCallbacks {
  CatBall({
    required this.tier,
    required this.coat,
    required Vector2 start,
    Vector2? velocity,
    this.popped = false,
  })  : _start = start,
        _velocity = velocity,
        _blinkIn = 1.5 + Random().nextDouble() * 4,
        super(renderBody: false) {
    // 합체로 태어나면 잠깐 활짝 웃는다.
    if (popped) react(CatFace.happy, 0.6);
  }

  static const _popDuration = 0.28;
  static const _blinkDuration = 0.13;

  final int tier;
  final CatCoat coat;
  final bool popped;
  final Vector2 _start;
  final Vector2? _velocity;

  bool merged = false;
  bool _landed = false;
  double age = 0;
  double _protect = 0;
  double _blinkIn;
  double _blinkT = 0;
  CatFace? _reaction;
  double _reactionT = 0;

  double get radius => catTiers[tier].radius;

  /// 잠깐 표정을 바꾼다 (놀람, 하트 눈 등).
  void react(CatFace face, double seconds) {
    if (_reaction != face) _reactionT = 0;
    _reaction = face;
    _reactionT = max(_reactionT, seconds);
  }

  /// 밀치기/오이로 튄 고양이는 잠깐 게임 오버 판정에서 뺀다.
  void protect(double seconds) => _protect = max(_protect, seconds);
  bool get isProtected => _protect > 0;

  @override
  Body createBody() {
    final body = world.createBody(BodyDef(
      type: BodyType.dynamic,
      position: _start,
      linearVelocity: _velocity ?? Vector2.zero(),
      angularDamping: 0.6,
      userData: this,
    ));
    body.createFixture(FixtureDef(CircleShape()..radius = radius,
        density: 1, friction: 0.35, restitution: 0.12));
    return body;
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (merged) return;
    if (other is CatBall && other.tier == tier && !other.merged) {
      game.queueMerge(this, other);
    } else if (!_landed) {
      _landed = true;
      if (tier >= 6 && !popped) game.shake(0.04 * (tier - 5));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    age += dt;
    if (_protect > 0) _protect -= dt;
    if (_reactionT > 0 && (_reactionT -= dt) <= 0) _reaction = null;
    if (_blinkT > 0) {
      _blinkT -= dt;
    } else if ((_blinkIn -= dt) <= 0) {
      _blinkT = _blinkDuration;
      _blinkIn = 2 + Random().nextDouble() * 4;
    }
  }

  @override
  void render(Canvas canvas) {
    var sx = 1.0, sy = 1.0;
    if (popped && age < _popDuration) {
      // 합체 직후 쫀득하게 튕기는 스쿼시
      final k = sin(age / _popDuration * pi);
      sx = 1 + 0.22 * k;
      sy = 1 - 0.14 * k;
    }
    canvas.save();
    // 물리는 계속 굴러가지만 얼굴은 거의 똑바로. 구르는 방향으로 살짝만 기우뚱.
    canvas.rotate(-body.angle + 0.22 * sin(body.angle));
    canvas.scale(sx, sy);
    paintCat(canvas, tier, coat, radius,
        face: _reaction, blink: _reaction == null && _blinkT > 0);
    canvas.restore();
  }
}

/// 떨어뜨린 아이템. 처음 무언가에 닿는 순간 발동한다.
class ItemBall extends BodyComponent<CatMergeGame> with ContactCallbacks {
  ItemBall({required this.item, required Vector2 start})
      : _start = start,
        super(renderBody: false);

  final ItemId item;
  final Vector2 _start;

  bool _hit = false;
  bool _done = false;
  double _active = -1;

  final _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.08;

  @override
  Body createBody() {
    final body = world.createBody(BodyDef(
      type: BodyType.dynamic,
      position: _start,
      userData: this,
    ));
    body.createFixture(FixtureDef(CircleShape()..radius = item.radius,
        density: 0.8, friction: 0.5, restitution: 0.1));
    return body;
  }

  @override
  void beginContact(Object other, Contact contact) => _hit = true;

  @override
  void update(double dt) {
    super.update(dt);
    if (!_hit || _done) return;
    switch (item) {
      case ItemId.churu:
        if (_active < 0) {
          _active = 0;
          game.churuStart(body.position);
        }
        _active += dt;
        game.churuPull(body.position, dt);
        if (_active >= CatMergeGame.churuDuration) {
          _done = true;
          removeFromParent();
        }
      case ItemId.cucumber:
        _done = true;
        game.cucumberScare(body.position);
        removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_active >= 0) {
      // 츄르 향기가 퍼지는 원 (두 겹)
      for (final off in [0.0, 0.5]) {
        final k = ((_active / CatMergeGame.churuDuration) * 2 + off) % 1;
        _ring
          ..color = AppColors.churu.withValues(alpha: 0.6 * (1 - k))
          ..strokeWidth = 0.14 * (1 - k) + 0.03;
        canvas.drawCircle(Offset.zero, CatMergeGame.churuRadius * k, _ring);
      }
    }
    paintItem(canvas, item, item.radius);
  }
}

/// 상자 (벽은 정적 바디). 선 넘으면 경고선이 붉게 깜빡인다.
class _Box extends BodyComponent<CatMergeGame> {
  _Box() : super(renderBody: false);

  static const _wall = 0.4;

  final _p = Paint();
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.08;

  @override
  Body createBody() {
    const hw = CatMergeGame.halfWidth;
    // userData가 있어야 바닥/벽에 닿을 때도 상대 쪽 충돌 콜백이 불린다.
    final body = world.createBody(BodyDef(userData: this));
    // 벽은 상자보다 훨씬 높게 (튕겨 나가는 것 방지). 보이는 건 상자 높이까지만.
    for (final (a, b) in [
      (Vector2(-hw, 0), Vector2(hw, 0)),
      (Vector2(-hw, 0), Vector2(-hw, -30)),
      (Vector2(hw, 0), Vector2(hw, -30)),
    ]) {
      body.createFixture(FixtureDef(EdgeShape()..set(a, b), friction: 0.4));
    }
    return body;
  }

  @override
  void render(Canvas canvas) {
    const hw = CatMergeGame.halfWidth, h = CatMergeGame.boxHeight;
    _p.color = AppColors.boxInner;
    canvas.drawRect(Rect.fromLTRB(-hw, -h, hw, 0), _p);

    // 위험할수록 상자 윗부분이 붉게 물든다
    final d = game.danger;
    if (d > 0) {
      _p.color = AppColors.danger
          .withValues(alpha: 0.18 * d * (0.6 + 0.4 * sin(game.time * 14)));
      canvas.drawRect(
          Rect.fromLTRB(-hw, -h, hw, CatMergeGame.dangerY + 0.6), _p);
    }

    _p.color = AppColors.box;
    canvas.drawRRect(
        RRect.fromLTRBR(
            -hw - _wall, -h, -hw, _wall, const Radius.circular(0.12)),
        _p);
    canvas.drawRRect(
        RRect.fromLTRBR(hw, -h, hw + _wall, _wall, const Radius.circular(0.12)),
        _p);
    canvas.drawRRect(
        RRect.fromLTRBR(
            -hw - _wall, 0, hw + _wall, _wall, const Radius.circular(0.12)),
        _p);
    // 상자 날개
    _p.color = AppColors.boxShadow;
    for (final s in [-1.0, 1.0]) {
      canvas.drawPath(
          Path()
            ..moveTo(s * (hw + _wall), -h)
            ..lineTo(s * (hw + 1.1), -h - 0.9)
            ..lineTo(s * (hw + 0.7), -h - 1.0)
            ..lineTo(s * hw, -h)
            ..close(),
          _p);
    }

    // 경고선 (점선). 평소에도 붉은 기가 돌아 "여기를 넘으면 안 된다"가 보이게.
    final pulse = d > 0 ? 0.5 + 0.5 * sin(game.time * (8 + d * 12)) : 0.0;
    _line
      ..strokeWidth = 0.08 + 0.06 * d
      ..color = Color.lerp(AppColors.danger.withValues(alpha: 0.45),
          AppColors.danger, max(d, pulse * d))!;
    for (var x = -hw; x < hw; x += 0.6) {
      canvas.drawLine(Offset(x, CatMergeGame.dangerY),
          Offset(min(x + 0.3, hw), CatMergeGame.dangerY), _line);
    }
  }
}

/// 떨어뜨릴 고양이(또는 아이템)와 조준선.
class _Aim extends Component with HasGameReference<CatMergeGame> {
  final _guide = Paint()
    ..color = AppColors.muted.withValues(alpha: 0.35)
    ..strokeWidth = 0.05;

  @override
  void render(Canvas canvas) {
    if (game.isOver) return;
    final x = game.aimX;
    for (var y = CatMergeGame.dropY + 0.8; y < 0; y += 0.5) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 0.25), _guide);
    }
    final spec = game.current;
    final opacity = game.canDrop ? 1.0 : 0.4;
    canvas.save();
    canvas.translate(x, CatMergeGame.dropY);
    final item = spec.item;
    if (item != null) {
      paintItem(canvas, item, item.radius, opacity: opacity);
    } else {
      paintCat(canvas, spec.tier, spec.coat, spec.radius, opacity: opacity);
    }
    canvas.restore();
  }
}
