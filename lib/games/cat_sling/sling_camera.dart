part of 'cat_sling_game.dart';

/// 앵그리버드식 카메라.
///
/// 모든 움직임은 "목표"만 바꾸고, 실제 위치·폭은 스프링(smooth damp)으로 따라간다.
/// 그래서 연출이 바뀌는 순간에도 속도가 끊기지 않고 부드럽게 이어진다.
///
/// - 시작: 구조물을 크게 비춘 뒤 맵 전체로 줄였다가, 새총을 크게 비춘다.
/// - 조준: 새총을 당기기 시작하면 맵 전체가 보이게 줄어든다.
/// - 발사 후: 고양이를 따라가고, 무너지는 곳을 지켜본 뒤 새총으로 돌아온다.
/// - 손가락: 한 손가락 끌기 = 이동, 두 손가락 = 확대/축소.
///
/// 땅은 항상 화면 아래에 붙어 있고, 폭([_w])을 바꾸는 게 곧 확대/축소다.
class _SlingCamera {
  _SlingCamera(this.game);
  final CatSlingGame game;

  /// 맵 양 끝(m).
  static const mapLeft = CatSlingGame.slingX - 3.0;
  static const mapRight = SlingLevels.maxX + 3.0;

  /// 화면 아래로 보이는 땅 두께.
  static const _bottom = 1.3;

  /// 새총을 크게 비출 때의 폭.
  static const slingW = 20.0;

  /// 시작할 때 구조물을 크게 비추는 폭.
  static const _closeW = 13.0;

  /// 날아가는 고양이를 따라갈 때 화면 높이(m).
  static const _flightH = 13.2;

  /// 가장 크게 확대했을 때의 폭.
  static const minW = 9.0;

  // 실제 값과 스프링 속도
  double _x = 0, _w = slingW, _vx = 0, _vw = 0;

  // 목표
  double _tx = 0, _tw = slingW;

  /// 목표까지 걸리는 대략의 시간(초). 클수록 느긋하다.
  double _smooth = 0.45;

  /// 사용자가 손가락으로 고른 새총 화면 폭 (null = 기본).
  double? _userW;

  // 시작 연출: (도착 후 머무는 시간, 다음 장면)
  final _steps = <(double hold, _Shot shot)>[];
  double _hold = 0;

  double get _aspect =>
      game.canvasSize.y <= 0 ? 2 : game.canvasSize.x / game.canvasSize.y;

  /// 맵 전체 폭 (가장 멀리 본 상태).
  double get farW => mapRight - mapLeft;

  /// 비행을 따라갈 때 폭.
  double get flightW => (_flightH * _aspect).clamp(minW, farW);

  double get _slingViewW => _userW ?? slingW;

  bool get busy => _steps.isNotEmpty || _hold > 0;

  /// 연출 중이거나 아직 목표로 가는 중.
  bool get moving => busy || !_near;

  double get width => _w;

  /// 스테이지 시작 연출.
  void intro(SlingLevel level) {
    final towers = level.blocks.isEmpty
        ? (SlingLevels.minX + SlingLevels.maxX) / 2
        : level.blocks.map((b) => b.x).reduce((a, b) => a + b) /
              level.blocks.length;
    _w = _tw = _closeW;
    _x = _tx = towers;
    _vx = _vw = 0;
    _steps
      ..clear()
      ..addAll([(0.7, _Shot.far), (1.2, _Shot.sling)]);
    _hold = 0;
    _clampAll();
  }

  /// 연출을 건너뛰고 새총으로.
  void skip() {
    _steps.clear();
    _hold = 0;
    _focusSling(smooth: 0.35);
  }

  /// 새총을 크게 비춘다 (조준 전).
  void focusSling() => _focusSling(smooth: 0.6);

  void _focusSling({required double smooth}) {
    _tw = _slingViewW;
    // 새총이 화면 왼쪽 1/4쯤에 오게
    _tx = CatSlingGame.slingX + _tw * 0.22;
    _smooth = smooth;
  }

  /// 당기기 시작: 맵 전체가 보이게.
  void showWholeMap() {
    _steps.clear();
    _hold = 0;
    _tw = farW;
    _tx = (mapLeft + mapRight) / 2;
    _smooth = 0.45;
  }

  /// 매 프레임 따라갈 곳을 알려준다. [smooth]가 클수록 느긋하게 따라간다.
  void track(double x, {double? w, double smooth = 0.5}) {
    if (busy) return;
    _tx = x;
    if (w != null) _tw = w;
    _smooth = smooth;
  }

  /// 한 손가락 끌기. [dxPixels]만큼 화면이 따라 움직인다.
  void pan(double dxPixels) {
    _grab();
    _x -= dxPixels * _w / max(game.canvasSize.x, 1);
    _tx = _x;
    _clampAll();
  }

  /// 두 손가락 확대/축소. [factor] > 1 이면 멀리 본다.
  /// 손가락 사이([focusPx]) 아래의 땅은 제자리에 머문다.
  void zoomBy(double factor, double focusPx) {
    _grab();
    final rel = focusPx / max(game.canvasSize.x, 1) - 0.5;
    final focus = _x + rel * _w;
    _w = _tw = (_w * factor).clamp(minW, farW);
    _userW = _w;
    _x = _tx = focus - rel * _w;
    _clampAll();
  }

  /// 손가락이 카메라를 잡았다: 진행 중인 움직임을 멈춘다.
  void _grab() {
    _steps.clear();
    _hold = 0;
    _vx = _vw = 0;
    _tx = _x;
    _tw = _w;
  }

  void update(double dt) {
    if (_hold > 0) {
      _hold -= dt;
      if (_hold <= 0 && _steps.isNotEmpty) {
        final (_, shot) = _steps.removeAt(0);
        switch (shot) {
          case _Shot.far:
            _tw = farW;
            _tx = (mapLeft + mapRight) / 2;
            _smooth = 0.55;
          case _Shot.sling:
            _focusSling(smooth: 0.55);
        }
      }
    } else if (_steps.isNotEmpty && _near) {
      _hold = _steps.first.$1;
    }
    final w = _damp(_w, _tw, _vw, _smooth, dt);
    final x = _damp(_x, _tx, _vx, _smooth, dt);
    _w = w.$1;
    _vw = w.$2;
    _x = x.$1;
    _vx = x.$2;
    _clampAll();
  }

  bool get _near => (_x - _tx).abs() < 0.3 && (_w - _tw).abs() < 0.3;

  /// Unity SmoothDamp: 임계 감쇠 스프링. 출발과 도착이 모두 부드럽다.
  static (double, double) _damp(
    double cur,
    double target,
    double vel,
    double smooth,
    double dt,
  ) {
    final omega = 2 / max(smooth, 0.01);
    final k = omega * dt;
    final e = 1 / (1 + k + 0.48 * k * k + 0.235 * k * k * k);
    final change = cur - target;
    final temp = (vel + omega * change) * dt;
    return (target + (change + temp) * e, (vel - omega * temp) * e);
  }

  void _clampAll() {
    _tw = _tw.clamp(minW, farW);
    _w = _w.clamp(minW, farW);
    _tx = _clampX(_tx, _tw);
    final x = _clampX(_x, _w);
    if (x != _x) _vx = 0;
    _x = x;
  }

  static double _clampX(double x, double w) {
    final lo = mapLeft + w / 2, hi = mapRight - w / 2;
    return lo > hi ? (mapLeft + mapRight) / 2 : x.clamp(lo, hi);
  }

  /// 흔들림을 더해 카메라에 반영한다.
  void apply(Vector2 shake) {
    if (game.canvasSize.x <= 0) return;
    final h = _w / _aspect;
    game.camera.viewfinder
      ..visibleGameSize = Vector2(_w, h)
      ..position = Vector2(_x, _bottom - h / 2) + shake;
  }
}

enum _Shot { far, sling }
