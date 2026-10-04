part of 'cat_sling_game.dart';

// 배경 풍경. 모두 장식이라 물리에 끼지 않는다.
// 저사양 기기를 생각해 도형 몇 개와 선으로만 그린다.

/// 하늘 그라데이션과 밤하늘의 별.
class _Sky extends Component with HasGameReference<CatSlingGame> {
  _Sky() : super(priority: -6);

  final _p = Paint();
  final _dot = Paint();
  SlingTime? _shaderFor;

  /// (위치, 크기, 반짝임 위상)
  static final _stars = () {
    final r = Random(7);
    return [
      for (var i = 0; i < 110; i++)
        (
          Offset(-14 + r.nextDouble() * 50, -20 + r.nextDouble() * 17),
          0.03 + r.nextDouble() * 0.06,
          r.nextDouble() * 2 * pi,
        ),
    ];
  }();

  @override
  void render(Canvas canvas) {
    final pal = game.palette;
    if (_shaderFor != game.timeOfDay) {
      _shaderFor = game.timeOfDay;
      _p.shader = Gradient.linear(const Offset(0, -13), const Offset(0, 0), [
        pal.skyTop,
        pal.skyBottom,
      ]);
    }
    canvas.drawRect(const Rect.fromLTRB(-40, -60, 40, 1), _p);
    if (game.timeOfDay != SlingTime.night) return;
    for (final (o, r, phase) in _stars) {
      final tw = 0.5 + 0.5 * sin(game.clock * 2.2 + phase);
      _dot.color = Colors.white.withValues(alpha: 0.35 + 0.65 * tw);
      canvas.drawCircle(o, r * (0.8 + 0.5 * tw), _dot);
    }
  }
}

/// 천천히 흘러가는 구름.
class _Clouds extends Component with HasGameReference<CatSlingGame> {
  _Clouds() : super(priority: -5);

  static const _left = -14.0, _span = 52.0;

  /// (x, y, 크기, 속도)
  static const _clouds = [
    (-4.0, -9.4, 1.0, 0.35),
    (6.0, -10.8, 1.3, 0.22),
    (13.0, -8.2, 0.8, 0.45),
    (21.0, -10.1, 1.1, 0.3),
    (29.0, -9.0, 0.9, 0.4),
    (34.0, -11.2, 1.2, 0.25),
  ];

  final _p = Paint();

  @override
  void render(Canvas canvas) {
    final night = game.timeOfDay == SlingTime.night;
    _p.color = game.palette.cloud.withValues(alpha: night ? 0.55 : 0.92);
    for (final (x0, y, s, v) in _clouds) {
      final x = (x0 + game.clock * v - _left) % _span + _left;
      canvas.drawCircle(Offset(x - 0.7 * s, y + 0.1 * s), 0.55 * s, _p);
      canvas.drawCircle(Offset(x, y - 0.25 * s), 0.8 * s, _p);
      canvas.drawCircle(Offset(x + 0.8 * s, y + 0.05 * s), 0.6 * s, _p);
      canvas.drawRRect(
        RRect.fromLTRBR(
          x - 1.25 * s,
          y,
          x + 1.4 * s,
          y + 0.55 * s,
          Radius.circular(0.28 * s),
        ),
        _p,
      );
    }
  }
}

/// 언덕, 풍차, 나무, 강.
class _Scenery extends Component with HasGameReference<CatSlingGame> {
  _Scenery() : super(priority: -3);

  static const riverTop = -0.95;

  final _p = Paint();
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void render(Canvas canvas) {
    final pal = game.palette;
    // 먼 언덕
    _p.color = pal.hillFar;
    canvas.drawCircle(const Offset(-4, 9), 11.5, _p);
    canvas.drawCircle(const Offset(10.5, 10.5), 13, _p);
    canvas.drawCircle(const Offset(23, 9), 11.2, _p);
    canvas.drawCircle(const Offset(33, 10), 12, _p);
    _windmill(canvas, pal, const Offset(14.6, -2.2));
    _windmill(canvas, pal, const Offset(29.5, -1.6));
    // 가까운 언덕
    _p.color = pal.hillNear;
    canvas.drawCircle(const Offset(-9, 6), 7.5, _p);
    canvas.drawCircle(const Offset(6.5, 7.4), 8.7, _p);
    canvas.drawCircle(const Offset(19.5, 6.8), 8, _p);
    canvas.drawCircle(const Offset(31, 7.2), 8.4, _p);
    // 나무 (강 건너편)
    _tree(canvas, pal, const Offset(-8.6, riverTop), 1.25);
    _tree(canvas, pal, const Offset(-2.4, riverTop), 0.8);
    _tree(canvas, pal, const Offset(9.3, riverTop - 0.4), 0.7);
    _tree(canvas, pal, const Offset(18.6, riverTop), 1.1);
    _tree(canvas, pal, const Offset(24.2, riverTop), 0.85);
    _tree(canvas, pal, const Offset(32.5, riverTop), 1.3);
    _river(canvas, pal);
  }

  void _river(Canvas canvas, SlingScenePalette pal) {
    _p.color = pal.river;
    canvas.drawRect(const Rect.fromLTRB(-40, riverTop, 40, 0.1), _p);
    // 물결: 오른쪽으로 흘러가는 짧은 빛줄기
    _line
      ..color = pal.riverLight.withValues(alpha: 0.8)
      ..strokeWidth = 0.07;
    for (var i = 0; i < 26; i++) {
      final speed = 1.0 + (i % 3) * 0.35;
      final x = (i * 2.1 + game.clock * speed) % 50 - 13;
      final y = riverTop + 0.2 + (i % 3) * 0.24;
      final len = 0.5 + (i % 4) * 0.2;
      canvas.drawLine(Offset(x, y), Offset(x + len, y), _line);
    }
  }

  void _tree(Canvas canvas, SlingScenePalette pal, Offset base, double s) {
    _p.color = pal.trunk;
    canvas.drawRRect(
      RRect.fromLTRBR(
        base.dx - 0.14 * s,
        base.dy - 1.5 * s,
        base.dx + 0.14 * s,
        base.dy,
        Radius.circular(0.06 * s),
      ),
      _p,
    );
    // 바람에 살짝 흔들린다
    final sway = sin(game.clock * 1.3 + base.dx) * 0.06 * s;
    _p.color = pal.leafDark;
    canvas.drawCircle(base + Offset(-0.5 * s + sway, -1.5 * s), 0.62 * s, _p);
    canvas.drawCircle(base + Offset(0.55 * s + sway, -1.55 * s), 0.6 * s, _p);
    _p.color = pal.leaf;
    canvas.drawCircle(base + Offset(sway, -2.1 * s), 0.78 * s, _p);
    canvas.drawCircle(base + Offset(-0.25 * s + sway, -1.7 * s), 0.5 * s, _p);
  }

  void _windmill(Canvas canvas, SlingScenePalette pal, Offset base) {
    _p.color = Color.lerp(pal.hillFar, pal.trunk, 0.35)!;
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - 0.55, base.dy)
        ..lineTo(base.dx - 0.3, base.dy - 2.6)
        ..lineTo(base.dx + 0.3, base.dy - 2.6)
        ..lineTo(base.dx + 0.55, base.dy)
        ..close(),
      _p,
    );
    final hub = base + const Offset(0, -2.6);
    _line
      ..color = Color.lerp(pal.hillFar, pal.cloud, 0.6)!
      ..strokeWidth = 0.22;
    final a0 = game.clock * 0.9;
    for (var i = 0; i < 4; i++) {
      final a = a0 + i * pi / 2;
      canvas.drawLine(hub, hub + Offset(cos(a), sin(a)) * 1.35, _line);
    }
    _p.color = pal.trunk;
    canvas.drawCircle(hub, 0.14, _p);
  }
}
