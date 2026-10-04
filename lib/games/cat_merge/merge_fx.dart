import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart' show Colors, FontWeight, TextStyle;

/// 터지는 조각 모양.
enum FxIcon { star, heart, paw, fish, sparkle, bang }

final _iconPath = Path();

/// 원점 중심, 크기 [s]의 아이콘.
void paintFxIcon(Canvas c, FxIcon icon, double s, Paint p) {
  switch (icon) {
    case FxIcon.star:
      _iconPath.reset();
      for (var i = 0; i < 10; i++) {
        final r = i.isEven ? s * 0.5 : s * 0.22;
        final a = -pi / 2 + i * pi / 5;
        i == 0
            ? _iconPath.moveTo(cos(a) * r, sin(a) * r)
            : _iconPath.lineTo(cos(a) * r, sin(a) * r);
      }
      _iconPath.close();
      c.drawPath(_iconPath, p);
    case FxIcon.heart:
      final k = s * 0.5;
      _iconPath
        ..reset()
        ..moveTo(0, k * 0.9)
        ..cubicTo(-k * 1.4, k * 0.1, -k * 0.7, -k, 0, -k * 0.35)
        ..cubicTo(k * 0.7, -k, k * 1.4, k * 0.1, 0, k * 0.9)
        ..close();
      c.drawPath(_iconPath, p);
    case FxIcon.paw:
      c.drawOval(Rect.fromCenter(center: Offset(0, s * 0.14), width: s * 0.5, height: s * 0.4), p);
      for (final (x, y) in [(-0.3, -0.12), (-0.11, -0.3), (0.11, -0.3), (0.3, -0.12)]) {
        c.drawCircle(Offset(x * s, y * s), s * 0.12, p);
      }
    case FxIcon.fish:
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: s * 0.7, height: s * 0.36), p);
      _iconPath
        ..reset()
        ..moveTo(s * 0.28, 0)
        ..lineTo(s * 0.5, -s * 0.2)
        ..lineTo(s * 0.5, s * 0.2)
        ..close();
      c.drawPath(_iconPath, p);
    case FxIcon.sparkle:
      final k = s * 0.5;
      _iconPath
        ..reset()
        ..moveTo(0, -k)
        ..quadraticBezierTo(k * 0.15, -k * 0.15, k, 0)
        ..quadraticBezierTo(k * 0.15, k * 0.15, 0, k)
        ..quadraticBezierTo(-k * 0.15, k * 0.15, -k, 0)
        ..quadraticBezierTo(-k * 0.15, -k * 0.15, 0, -k)
        ..close();
      c.drawPath(_iconPath, p);
    case FxIcon.bang:
      // 느낌표
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(0, -s * 0.12), width: s * 0.2, height: s * 0.56),
              Radius.circular(s * 0.1)),
          p);
      c.drawCircle(Offset(0, s * 0.34), s * 0.11, p);
  }
}

class _Piece {
  _Piece(this.dir, this.speed, this.spin, this.icon, this.color, this.size);
  final Offset dir;
  final double speed, spin, size;
  final FxIcon icon;
  final Color color;
}

/// 한 점에서 링이 퍼지고 아이콘 조각이 사방으로 튀는 효과 (월드 좌표).
/// 파티클 시스템 대신 조각 10~20개만 직접 그린다 (저사양 고려).
class FxBurst extends PositionComponent {
  FxBurst({
    required Vector2 at,
    required this.radius,
    required List<Color> colors,
    required List<FxIcon> icons,
    int count = 10,
    this.life = 0.7,
    this.ringColor,
    Random? random,
  }) : super(position: at) {
    final rng = random ?? Random();
    for (var i = 0; i < count; i++) {
      final a = i / count * 2 * pi + rng.nextDouble() * 0.5;
      _pieces.add(_Piece(
        Offset(cos(a), sin(a)),
        radius * (1.2 + rng.nextDouble() * 1.4),
        (rng.nextDouble() - 0.5) * 8,
        icons[rng.nextInt(icons.length)],
        colors[rng.nextInt(colors.length)],
        radius * (0.28 + rng.nextDouble() * 0.22),
      ));
    }
  }

  final double radius;
  final double life;
  final Color? ringColor;
  final _pieces = <_Piece>[];
  final _paint = Paint();
  final _ring = Paint()..style = PaintingStyle.stroke;
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final k = (_t / life).clamp(0.0, 1.0);
    final ease = 1 - pow(1 - k, 3).toDouble();
    final fade = 1 - k * k;

    final ring = ringColor;
    if (ring != null) {
      _ring
        ..color = ring.withValues(alpha: 0.7 * (1 - k))
        ..strokeWidth = radius * 0.18 * (1 - k) + 0.02;
      canvas.drawCircle(Offset.zero, radius * (0.8 + 1.6 * ease), _ring);
    }
    for (final p in _pieces) {
      final d = radius * 0.6 + p.speed * ease;
      canvas.save();
      canvas.translate(p.dir.dx * d, p.dir.dy * d + k * k * radius * 0.6);
      canvas.rotate(p.spin * k);
      _paint.color = p.color.withValues(alpha: fade);
      paintFxIcon(canvas, p.icon, p.size * (1 - k * 0.4), _paint);
      canvas.restore();
    }
  }
}

/// 크게 튀어나왔다가 떠오르며 사라지는 외침 글자 (화면 좌표).
class FxText extends PositionComponent {
  FxText(
    this.text,
    Vector2 at, {
    double size = 30,
    Color color = const Color(0xFFFF8A3D),
    Color stroke = Colors.white,
    this.life = 1.0,
    this.rise = 60,
    this.wobble = false,
    this.delay = 0,
  }) : super(position: at, anchor: Anchor.center) {
    _outline = TextPaint(
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * 0.2
          ..strokeJoin = StrokeJoin.round
          ..color = stroke,
      ),
    );
    _fill = TextPaint(
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: color,
        shadows: [Shadow(color: stroke.withValues(alpha: 0.6), offset: Offset(0, size * 0.08))],
      ),
    );
  }

  final String text;
  final double life;
  final double rise;
  final bool wobble;
  final double delay;
  late final TextPaint _outline;
  late final TextPaint _fill;
  final _layer = Paint();
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= life + delay) removeFromParent();
  }

  /// 살짝 넘쳤다 돌아오는 튕김.
  static double _backOut(double x) {
    const c = 2.2;
    final y = x - 1;
    return 1 + (c + 1) * y * y * y + c * y * y;
  }

  @override
  void render(Canvas canvas) {
    final t = _t - delay;
    if (t < 0) return;
    final k = (t / life).clamp(0.0, 1.0);
    final scale = k < 0.18 ? _backOut(k / 0.18) : 1.0;
    final alpha = k > 0.7 ? 1 - (k - 0.7) / 0.3 : 1.0;
    canvas.save();
    canvas.translate(0, -rise * k);
    if (wobble) canvas.rotate(sin(t * 20) * 0.1 * (1 - k));
    canvas.scale(scale);
    if (alpha < 1) {
      _layer.color = Color.fromRGBO(0, 0, 0, alpha);
      canvas.saveLayer(null, _layer);
    }
    _outline.render(canvas, text, Vector2.zero(), anchor: Anchor.center);
    _fill.render(canvas, text, Vector2.zero(), anchor: Anchor.center);
    if (alpha < 1) canvas.restore();
    canvas.restore();
  }
}

/// 화면 전체가 잠깐 번쩍인다 (큰 연쇄, 사자).
class FxFlash extends PositionComponent {
  FxFlash(Vector2 size, {this.color = Colors.white, this.life = 0.28, this.strength = 0.45})
      : super(size: size);

  final Color color;
  final double life;
  final double strength;
  final _paint = Paint();
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    _paint.color = color.withValues(alpha: strength * (1 - _t / life).clamp(0.0, 1.0));
    canvas.drawRect(size.toRect(), _paint);
  }
}
