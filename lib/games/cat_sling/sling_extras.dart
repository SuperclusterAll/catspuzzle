part of 'cat_sling_game.dart';

// 하늘의 방해꾼과 선물들. 모두 센서라 블록을 밀지 않고, 고양이에게만 반응한다.

/// 하늘을 가로지르는 새. 고양이가 부딪히면 위로 튀어 오르고 냥펀치가 다시 충전된다.
class SlingBird extends BodyComponent<CatSlingGame> with ContactCallbacks {
  SlingBird({
    required Vector2 start,
    required this.speed,
    required double phase,
  }) : _start = start.clone(),
       _phase = phase,
       super(renderBody: false, priority: 1);

  static const radius = 0.45;

  final Vector2 _start;

  /// 가로 속도. 음수면 왼쪽으로 난다.
  final double speed;
  final double _phase;
  bool _hit = false;
  double _t = 0;

  final _p = Paint();
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(
        type: BodyType.kinematic,
        position: _start,
        linearVelocity: Vector2(speed, 0),
        userData: this,
      ),
    );
    body.createFixture(
      FixtureDef(CircleShape()..radius = radius, isSensor: true),
    );
    return body;
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (_hit || other is! SlingCat) return;
    _hit = true;
    game.birdHit(this, other);
    // 빙글빙글 떨어진다
    body.linearVelocity = Vector2(-speed * 0.3, 7);
    body.angularVelocity = 9 * speed.sign;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (!_hit) {
      body.linearVelocity = Vector2(speed, cos(_t * 2.4 + _phase) * 0.9);
    }
    final p = body.position;
    if (p.x < _SlingCamera.mapLeft - 3 ||
        p.x > _SlingCamera.mapRight + 3 ||
        p.y > 3) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    const r = radius;
    canvas.save();
    if (speed < 0) canvas.scale(-1, 1);
    final flap = _hit ? 0.0 : sin(_t * 16);
    // 뒷날개
    _p.color = Color.lerp(AppColors.bird, AppColors.ink, 0.25)!;
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.1, -r * 0.2)
        ..quadraticBezierTo(
          -r * 0.6,
          -r * (0.9 + flap),
          -r * 1.2,
          -r * (0.6 + flap * 0.9),
        )
        ..quadraticBezierTo(-r * 0.6, -r * 0.2, -r * 0.1, r * 0.1)
        ..close(),
      _p,
    );
    // 몸통과 꼬리
    _p.color = AppColors.bird;
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.8, 0)
        ..lineTo(-r * 1.5, -r * 0.35)
        ..lineTo(-r * 1.4, r * 0.3)
        ..close(),
      _p,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 1.6),
      _p,
    );
    _p.color = AppColors.birdBelly;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(r * 0.1, r * 0.3),
        width: r * 1.3,
        height: r * 0.8,
      ),
      _p,
    );
    // 부리
    _p.color = AppColors.beak;
    canvas.drawPath(
      Path()
        ..moveTo(r * 0.85, -r * 0.2)
        ..lineTo(r * 1.4, 0)
        ..lineTo(r * 0.85, r * 0.15)
        ..close(),
      _p,
    );
    // 눈
    _line
      ..color = AppColors.ink
      ..strokeWidth = r * 0.12;
    final eye = Offset(r * 0.45, -r * 0.25);
    if (_hit) {
      final d = r * 0.14;
      canvas.drawLine(eye - Offset(d, d), eye + Offset(d, d), _line);
      canvas.drawLine(eye - Offset(d, -d), eye + Offset(d, -d), _line);
    } else {
      _p.color = AppColors.ink;
      canvas.drawCircle(eye, r * 0.13, _p);
    }
    // 앞날개
    _p.color = Color.lerp(AppColors.bird, Colors.white, 0.2)!;
    canvas.drawPath(
      Path()
        ..moveTo(r * 0.1, -r * 0.1)
        ..quadraticBezierTo(
          -r * 0.3,
          -r * (1.0 + flap),
          -r * 0.9,
          -r * (0.7 + flap),
        )
        ..quadraticBezierTo(-r * 0.3, -r * 0.1, r * 0.1, r * 0.2)
        ..close(),
      _p,
    );
    canvas.restore();
  }
}

/// 해(낮·노을)나 달(밤). 하늘을 오가다 가끔 낮게 내려와 날아가는 고양이를 튕겨낸다.
class SlingSkyBody extends BodyComponent<CatSlingGame> with ContactCallbacks {
  SlingSkyBody(this.time) : super(renderBody: false, priority: -4);

  final SlingTime time;
  static const radius = 1.15;

  bool get isMoon => time == SlingTime.night;

  double _t = 0;
  double _ouch = 0;
  double _cool = 0;

  final _p = Paint();
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  /// 좌우로 천천히 오가다 주기적으로 쑥 내려온다.
  static Vector2 positionAt(double t) {
    final dip = pow(max(0.0, sin(t * 0.45 - 1.2)), 6).toDouble();
    const mid = (_SlingCamera.mapLeft + _SlingCamera.mapRight) / 2;
    const half = (_SlingCamera.mapRight - _SlingCamera.mapLeft) / 2 - 3;
    return Vector2(mid + half * sin(t * 0.16), -9.9 + 3.8 * dip);
  }

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(
        type: BodyType.kinematic,
        position: positionAt(0),
        userData: this,
      ),
    );
    body.createFixture(
      FixtureDef(CircleShape()..radius = radius, isSensor: true),
    );
    return body;
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is! SlingCat || _cool > 0) return;
    _cool = 0.3;
    _ouch = 0.9;
    game.skyBump(this, other);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_ouch > 0) _ouch -= dt;
    if (_cool > 0) _cool -= dt;
    body.setTransform(positionAt(_t), 0);
  }

  @override
  void render(Canvas canvas) {
    const r = radius;
    final base = switch (time) {
      SlingTime.day => AppColors.sun,
      SlingTime.sunset => AppColors.sunset,
      SlingTime.night => AppColors.moon,
    };
    // 은은한 빛무리
    for (final (k, a) in [(2.1, 0.12), (1.55, 0.2)]) {
      _p.color = base.withValues(alpha: a);
      canvas.drawCircle(Offset.zero, r * k, _p);
    }
    if (!isMoon) {
      // 빙글빙글 도는 햇살
      _p.color = base;
      final spin = _t * 0.6;
      for (var i = 0; i < 10; i++) {
        final a = spin + i * pi / 5;
        final d = Offset(cos(a), sin(a));
        final n = Offset(-d.dy, d.dx) * (r * 0.18);
        canvas.drawPath(
          Path()
            ..moveTo(d.dx * r * 1.1 + n.dx, d.dy * r * 1.1 + n.dy)
            ..lineTo(d.dx * r * 1.55, d.dy * r * 1.55)
            ..lineTo(d.dx * r * 1.1 - n.dx, d.dy * r * 1.1 - n.dy)
            ..close(),
          _p,
        );
      }
    }
    _p.color = base;
    canvas.drawCircle(Offset.zero, r, _p);
    if (isMoon) {
      _p.color = AppColors.moonShade;
      canvas.drawCircle(Offset(-r * 0.45, -r * 0.35), r * 0.18, _p);
      canvas.drawCircle(Offset(r * 0.5, r * 0.45), r * 0.13, _p);
      canvas.drawCircle(Offset(-r * 0.2, r * 0.6), r * 0.1, _p);
    }
    // 얼굴
    _line
      ..color = AppColors.ink
      ..strokeWidth = r * 0.08;
    for (final s in [-1.0, 1.0]) {
      final eye = Offset(s * r * 0.35, -r * 0.08);
      if (_ouch > 0) {
        // 질끈 ><
        canvas.drawLine(eye + Offset(-s * r * 0.14, -r * 0.1), eye, _line);
        canvas.drawLine(eye + Offset(-s * r * 0.14, r * 0.1), eye, _line);
      } else if (isMoon) {
        // 졸린 달
        canvas.drawArc(
          Rect.fromCircle(center: eye, radius: r * 0.12),
          0,
          pi,
          false,
          _line,
        );
      } else {
        _p.color = AppColors.ink;
        canvas.drawCircle(eye, r * 0.09, _p);
      }
    }
    _p.color = const Color(0xFFFF8FA3).withValues(alpha: 0.55);
    for (final s in [-1.0, 1.0]) {
      canvas.drawCircle(Offset(s * r * 0.58, r * 0.2), r * 0.13, _p);
    }
    if (_ouch > 0) {
      canvas.drawCircle(Offset(0, r * 0.35), r * 0.12, _line);
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(0, r * 0.18), radius: r * 0.2),
        0.2,
        pi - 0.4,
        false,
        _line,
      );
    }
  }
}

enum PickupKind {
  /// 먹으면 잠깐 무적: 닿는 블록과 쥐를 모두 쓸어버린다.
  star,

  /// 붕어빵: 고양이 한 마리 추가.
  bungeoppang,

  /// 분신: 먹은 자리에서 고양이가 +2~+5 마리로 흩어진다.
  split,

  /// 폭탄: 다음에 부딪히는 곳에서 펑!
  bomb,

  /// 버섯: 고양이가 거대해져 묵직하게 밀어붙인다.
  giant,

  /// 알파벳 A~F. 다 모으면 보너스.
  letter,
}

/// 공중에 뿅 나타나는 선물. 새총과 구조물 사이를 떠다니고,
/// 날아가는 고양이가 지나가며 먹는다.
class SlingPickup extends BodyComponent<CatSlingGame> with ContactCallbacks {
  SlingPickup(
    this.kind,
    Vector2 center, {
    double phase = 0,
    this.xSwing = 0,
    this.count = 0,
    this.letter = '',
  }) : _at = center.clone(),
       _phase = phase,
       super(renderBody: false, priority: 2);

  final PickupKind kind;
  final Vector2 _at;
  final double _phase;

  /// 좌우로 오가는 폭(m).
  final double xSwing;

  /// 분신 수 (split).
  final int count;

  /// 알파벳 (letter).
  final String letter;

  static const radius = 0.6;

  /// 위아래로 오르내리는 폭(m)과 빠르기. 쏠 때 타이밍을 맞춰 노려야 한다.
  static const swing = 2.2;
  static const _swingSpeed = 1.9;
  static const _driftSpeed = 0.55;

  bool _taken = false;
  double _t = 0;

  final _p = Paint();
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  static final _starPath = () {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? 1.0 : 0.48;
      final a = -pi / 2 + i * pi / 5;
      final o = Offset(cos(a) * r, sin(a) * r);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }();

  late final TextPainter? _label = switch (kind) {
    PickupKind.split => _text('+$count', Colors.white),
    PickupKind.letter => _text(letter, Colors.white),
    _ => null,
  };

  static TextPainter _text(String s, Color c) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontSize: 1,
        fontWeight: FontWeight.w900,
        color: c,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(type: BodyType.kinematic, position: _at, userData: this),
    );
    body.createFixture(
      FixtureDef(CircleShape()..radius = radius, isSensor: true),
    );
    return body;
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (_taken || other is! SlingCat) return;
    _taken = true;
    game.collect(this, other);
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    body.setTransform(
      _at +
          Vector2(
            sin(_t * _driftSpeed + _phase * 1.7) * xSwing,
            sin(_t * _swingSpeed + _phase) * swing,
          ),
      0,
    );
  }

  @override
  void render(Canvas canvas) {
    // 뿅 하고 커지며 등장
    final k = min(_t / 0.35, 1.0);
    final pop = 1 + 0.35 * sin(k * pi) * (1 - k * 0.5);
    final s = radius * pop * k;
    if (s <= 0) return;
    canvas.save();
    switch (kind) {
      case PickupKind.star:
        _p.color = AppColors.star.withValues(alpha: 0.25 + 0.15 * sin(_t * 8));
        canvas.drawCircle(Offset.zero, s * 1.6, _p);
        canvas.rotate(sin(_t * 4) * 0.2);
        canvas.scale(s * 1.15);
        _p.color = AppColors.star;
        canvas.drawPath(_starPath, _p);
        _line
          ..color = const Color(0xFFC77A0A)
          ..strokeWidth = 0.1;
        canvas.drawPath(_starPath, _line);
        _p.color = AppColors.ink;
        for (final x in [-0.17, 0.17]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(x, -0.05),
              width: 0.12,
              height: 0.26,
            ),
            _p,
          );
        }
      case PickupKind.bungeoppang:
        _p.color = AppColors.bungeoppangLight.withValues(alpha: 0.3);
        canvas.drawCircle(Offset.zero, s * 1.5, _p);
        canvas.rotate(sin(_t * 4) * 0.15);
        canvas.scale(s);
        _paintBungeoppang(canvas);
      case PickupKind.split:
        // 주황 방울 + 작은 고양이 발자국들 + 숫자
        _bubble(canvas, s, AppColors.tabby);
        _drawLabel(canvas, s * 1.1);
      case PickupKind.letter:
        final c = AppColors.letters[(letter.codeUnitAt(0) - 65) % 6];
        _bubble(canvas, s, c);
        _drawLabel(canvas, s * 1.25);
      case PickupKind.bomb:
        canvas.rotate(sin(_t * 5) * 0.15);
        _p.color = AppColors.ink;
        canvas.drawCircle(Offset(0, s * 0.12), s * 0.85, _p);
        _p.color = Colors.white.withValues(alpha: 0.35);
        canvas.drawCircle(Offset(-s * 0.3, -s * 0.15), s * 0.2, _p);
        _line
          ..color = AppColors.woodDark
          ..strokeWidth = s * 0.14;
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.35, -s * 0.55)
            ..quadraticBezierTo(s * 0.6, -s * 1.0, s * 0.95, -s * 0.9),
          _line,
        );
        // 반짝이는 불꽃
        final spark = 0.6 + 0.4 * sin(_t * 22);
        _p.color = AppColors.star;
        canvas.drawCircle(Offset(s * 0.97, -s * 0.92), s * 0.2 * spark, _p);
        _p.color = AppColors.danger;
        canvas.drawCircle(Offset(s * 0.97, -s * 0.92), s * 0.1 * spark, _p);
      case PickupKind.giant:
        // 빨간 버섯
        canvas.rotate(sin(_t * 3) * 0.12);
        _p.color = const Color(0xFFF6EBD9);
        canvas.drawRRect(
          RRect.fromLTRBR(
            -s * 0.35,
            -s * 0.1,
            s * 0.35,
            s * 0.85,
            Radius.circular(s * 0.2),
          ),
          _p,
        );
        _p.color = AppColors.danger;
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(0, s * 0.05),
            width: s * 2,
            height: s * 1.8,
          ),
          pi,
          pi,
          true,
          _p,
        );
        _p.color = Colors.white;
        for (final (x, y, r) in [
          (-0.5, -0.35, 0.2),
          (0.35, -0.45, 0.24),
          (0.0, -0.7, 0.15),
          (0.7, -0.12, 0.13),
          (-0.8, -0.05, 0.11),
        ]) {
          canvas.drawCircle(Offset(x * s, y * s), r * s, _p);
        }
        _p.color = AppColors.ink;
        for (final x in [-0.13, 0.13]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(x * s, s * 0.35),
              width: s * 0.1,
              height: s * 0.2,
            ),
            _p,
          );
        }
    }
    canvas.restore();
  }

  /// 테두리 있는 동그란 방울.
  void _bubble(Canvas canvas, double s, Color c) {
    _p.color = c.withValues(alpha: 0.25 + 0.1 * sin(_t * 6));
    canvas.drawCircle(Offset.zero, s * 1.45, _p);
    _p.color = c;
    canvas.drawCircle(Offset.zero, s, _p);
    _line
      ..color = Colors.white
      ..strokeWidth = s * 0.12;
    canvas.drawCircle(Offset.zero, s, _line);
    _p.color = Colors.white.withValues(alpha: 0.4);
    canvas.drawCircle(Offset(-s * 0.4, -s * 0.4), s * 0.18, _p);
  }

  void _drawLabel(Canvas canvas, double size) {
    final tp = _label;
    if (tp == null) return;
    canvas.save();
    canvas.scale(size);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  /// 반지름 1 기준 붕어빵 (오른쪽을 본다).
  void _paintBungeoppang(Canvas canvas) {
    final body = Path()
      ..moveTo(1.15, 0)
      ..quadraticBezierTo(0.9, -0.72, -0.1, -0.68)
      ..quadraticBezierTo(-0.7, -0.62, -0.9, -0.2)
      ..lineTo(-1.3, -0.62)
      ..quadraticBezierTo(-1.25, 0, -1.3, 0.62)
      ..lineTo(-0.9, 0.2)
      ..quadraticBezierTo(-0.7, 0.62, -0.1, 0.68)
      ..quadraticBezierTo(0.9, 0.72, 1.15, 0)
      ..close();
    _p.color = AppColors.bungeoppang;
    canvas.drawPath(body, _p);
    // 비늘 무늬
    _line
      ..color = AppColors.bungeoppangDark.withValues(alpha: 0.7)
      ..strokeWidth = 0.07;
    for (final x in [-0.45, -0.05, 0.35]) {
      for (final y in [-0.25, 0.2]) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset(x, y), radius: 0.16),
          -pi / 2,
          pi,
          false,
          _line,
        );
      }
    }
    // 노릇한 윗면 하이라이트
    _line
      ..color = AppColors.bungeoppangLight
      ..strokeWidth = 0.1;
    canvas.drawArc(
      const Rect.fromLTRB(-0.5, -0.6, 0.8, 0.2),
      -2.6,
      1.2,
      false,
      _line,
    );
    _line
      ..color = AppColors.bungeoppangDark
      ..strokeWidth = 0.09;
    canvas.drawPath(body, _line);
    _p.color = AppColors.ink;
    canvas.drawCircle(const Offset(0.72, -0.14), 0.09, _p);
  }
}
